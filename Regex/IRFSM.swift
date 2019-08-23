// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

// MARK: - IRFSM

/// A convenience API for creating finite state machines (FSM) which represent
/// regular expressions. This is an intermediate representation which is more
/// convenient for creating and combining the state machines, but not
/// executing them. In order to execute the machine, we create an optimized
/// representation (`FSM`).
struct IRFSM {
    let start: IRState
    let end: IRState

    init(start: IRState = IRState(), end: IRState = IRState()) {
        self.start = start
        self.end = end
    }

    init(condition: Condition) {
        self = IRFSM()
        start.transitions = [.init(end, condition)]
    }

    /// Creates an empty state machine.
    static var empty: IRFSM {
        let fsm = IRFSM()
        fsm.start.transitions = [.epsilon(fsm.end)]
        return fsm
    }
}

// MARK: - RIState

/// An intermediate representation of a state of a state machine. This representation
/// is more convenient for creating and combining the state machines, but not
/// executing them.
final class IRState: Hashable {
    var transitions = [RITransition]()

    var isEnd: Bool {
        return transitions.isEmpty
    }

    // MARK: Hashable

    func hash(into hasher: inout Hasher) {
        ObjectIdentifier(self).hash(into: &hasher)
    }

    static func == (lhs: IRState, rhs: IRState) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

// MARK: - RITransition

/// A transition between two states of the state machine.
struct RITransition {
    /// A state into which the transition is performed.
    let end: IRState

    /// Determines whether the transition is possible in the given context.
    /// Returns `nil` if not possible, otherwise returns number of elements to consume.
    let condition: Condition

    var isUnconditionalEpsilon: Bool {
        guard let epsilon = condition as? Epsilon else {
            return false
        }
        return epsilon.predicate == nil
    }

    init(_ end: IRState, _ condition: Condition) {
        self.end = end
        self.condition = condition
    }

    /// Creates a transition which doesn't consume characters.
    static func epsilon(_ end: IRState, _ condition: @escaping (Cursor) -> Bool) -> RITransition {
        return RITransition(end, Epsilon(condition))
    }

    /// Creates a unconditional transition which doesn't consume characters.
    static func epsilon(_ end: IRState) -> RITransition {
        return RITransition(end, Epsilon())
    }
}

// MARK: - IRFSM (Character Classes)

extension IRFSM {

    // MARK: .character

    /// Matches the given character.
    static func character(_ c: Character, isCaseInsensitive: Bool) -> IRFSM {
        IRFSM(condition: MatchCharacter(character: c, isCaseInsensitive: isCaseInsensitive))
    }

    private struct MatchCharacter: Condition {
        let character: Character
        let isCaseInsensitive: Bool

        func canTransition(_ cursor: Cursor) -> ConditionResult {
            guard let input = cursor.character else { return .rejected }
            let isEqual: Bool
            if isCaseInsensitive {
                isEqual = String(character).caseInsensitiveCompare(String(input)) == ComparisonResult.orderedSame
            } else {
                isEqual = input == character
            }
            return isEqual ? .accepted() : .rejected
        }
    }

    // MARK: .string

    /// Matches the given string. In general is going to be much faster than
    /// checking the individual characters (fast substring search).
    static func string(_ s: String, isCaseInsensitive: Bool) -> IRFSM {
        assert(!s.isEmpty)
        return IRFSM(condition: MatchString(string: s, count: s.count, isCaseInsensitive: isCaseInsensitive))
    }

    private struct MatchString: Condition {
        let string: String
        let count: Int
        let isCaseInsensitive: Bool

        func canTransition(_ cursor: Cursor) -> ConditionResult {
            guard let ub = cursor.string.index(cursor.index, offsetBy: count, limitedBy: cursor.string.endIndex) else {
                return .rejected
            }
            let input = cursor.string[cursor.index..<ub]

            if isCaseInsensitive {
                // TODO: test this
                guard String(input).caseInsensitiveCompare(string) == ComparisonResult.orderedSame else {
                    return .rejected
                }
            } else {
                guard input == string else {
                    return .rejected
                }
            }
            return .accepted(count: count)
        }
    }

    // MARK: .characterSet

    /// Matches the given character set.
    static func characterSet(_ set: CharacterSet, _ isCaseInsensitive: Bool, _ isNegative: Bool) -> IRFSM {
        if set == .decimalDigits {
            return IRFSM(condition: MatchAnyNumber())
        }
        return IRFSM(condition: MatchCharacterSet(set: set, isCaseInsensitive: isCaseInsensitive, isNegative: isNegative))
    }

    private struct MatchCharacterSet: Condition {
        let set: CharacterSet
        let isCaseInsensitive: Bool
        let isNegative: Bool

        func canTransition(_ cursor: Cursor) -> ConditionResult {
            guard let input = cursor.character else { return .rejected }
            let isMatch: Bool
            if isCaseInsensitive, input.isCased {
                isMatch = set.contains(Character(input.lowercased())) || set.contains(Character(input.uppercased()))
            } else {
                isMatch = set.contains(input)
            }
            return (isMatch != isNegative) ? .accepted() : .rejected
        }
    }

    private struct MatchAnyNumber: Condition {
        func canTransition(_ cursor: Cursor) -> ConditionResult {
            guard let input = cursor.character else { return .rejected }
            return input.isNumber ? .accepted() : .rejected
        }
    }

    // MARK: .range

    static func range(_ range: ClosedRange<Unicode.Scalar>, _ isCaseInsensitive: Bool, _ isNegative: Bool) -> IRFSM {
        return IRFSM(condition: MatchUnicodeScalarRange(range: range, isCaseInsensitive: isCaseInsensitive, isNegative: isNegative))
    }

    private struct MatchUnicodeScalarRange: Condition {
        let range: ClosedRange<Unicode.Scalar>
        let isCaseInsensitive: Bool
        let isNegative: Bool

        func canTransition(_ cursor: Cursor) -> ConditionResult {
            guard let input = cursor.character else { return .rejected }
            let isMatch: Bool
            if isCaseInsensitive, input.isCased {
                // TODO: this definitely isn't efficient
                isMatch = range.contains(input.lowercased().unicodeScalars.first!) ||
                    range.contains(input.uppercased().unicodeScalars.first!)
            } else {
                isMatch = input.unicodeScalars.allSatisfy(range.contains)
            }
            return (isMatch != isNegative) ? .accepted() : .rejected
        }
    }

    // MARK: .anyCharacter

    /// Matches any character.
    static func anyCharacter(includingNewline: Bool) -> IRFSM {
        IRFSM(condition: MatchAnyCharacter(includingNewline: includingNewline))
    }

    private struct MatchAnyCharacter: Condition {
        let includingNewline: Bool

        func canTransition(_ cursor: Cursor) -> ConditionResult {
            guard !cursor.isEmpty else { return .rejected }
            return (includingNewline || cursor.string[cursor.index] != "\n") ? .accepted() : .rejected
        }
    }
}

// MARK: - IRFSM (Quantifiers)

extension IRFSM {
    /// Matches the given FSM zero or more times.
    static func zeroOrMore(_ child: IRFSM, _ isLazy: Bool) -> IRFSM {
        let quantifier = IRFSM()

        quantifier.start.transitions = [
            .epsilon(child.start), // Optimizer will take care of it
        ]
        child.start.transitions.append(
            .epsilon(quantifier.end)
        )
        if isLazy {
            child.start.transitions.reverse()
        }
        child.end.transitions = [
            .epsilon(child.start) // Loop
        ]
        return quantifier
    }

    /// Matches the given FSM one or more times.
    static func oneOrMore(_ child: IRFSM, _ isLazy: Bool) -> IRFSM {
        let quantifier = IRFSM()
        quantifier.start.transitions = [
            .epsilon(child.start) // Execute at least once
        ]
        child.end.transitions = [
            .epsilon(child.start), // Loop (greedy)
            .epsilon(quantifier.end) // Complete
        ]
        if isLazy {
            child.end.transitions.reverse()
        }
        return quantifier
    }

    /// Matches the given FSM either none or one time.
    static func zeroOrOne(_ child: IRFSM, _ isLazy: Bool) -> IRFSM {
        let quantifier = IRFSM()
        quantifier.start.transitions = [
            .epsilon(child.start), // Loop (greedy)
            .epsilon(quantifier.end) // Skip
        ]
        if isLazy {
            quantifier.start.transitions.reverse()
        }
        child.end.transitions = [
            .epsilon(quantifier.end), // Complete
        ]
        return quantifier
    }
}

// MARK: - IRFSM (Anchors)

extension IRFSM {
    /// Matches the beginning of the line.
    static var startOfString: IRFSM {
        anchor { cursor in
            cursor.startIndex == cursor.string.startIndex || cursor.isEmpty || cursor.character == "\n"
        }
    }

    /// Matches the beginning of the string (ignores `.multiline` option).
    static var startOfStringOnly: IRFSM {
        anchor { cursor in
            cursor.startIndex == cursor.string.startIndex
        }
    }

    /// Matches the end of the string or `\n` at the end of the string
    /// (end of the line in `.multiline` mode).
    static var endOfString: IRFSM {
        anchor { cursor in
            cursor.isEmpty || cursor.character == "\n"
        }
    }

    /// Matches the end of the string or `\n` at the end of the string.
    static var endOfStringOnly: IRFSM {
        anchor { cursor in
            cursor.isEmpty || (cursor.isAtLastIndex && cursor.character == "\n")
        }
    }

    /// Matches the end of the string or `\n` at the end of the string (ignores `.multiline` option).
    static var endOfStringOnlyNotNewline: IRFSM {
        anchor { cursor in cursor.isEmpty }
    }

    /// Match must occur at the point where the previous match ended. Ensures
    /// that all matches are contiguous.
    static var previousMatchEnd: IRFSM {
        anchor { cursor in
            if cursor.index == cursor.string.startIndex {
                return true // There couldn't be any matches before the start index
            }
            guard let previousMatchIndex = cursor.previousMatchIndex else {
                return false
            }
            return cursor.index == previousMatchIndex
        }
    }

    /// The match must occur on a word boundary.
    static var wordBoundary: IRFSM {
        anchor { cursor in cursor.isAtWordBoundary }
    }

    /// The match must occur on a non-word boundary.
    static var nonWordBoundary: IRFSM {
        anchor { cursor in !cursor.isAtWordBoundary }
    }

    private static func anchor(_ condition: @escaping (Cursor) -> Bool) -> IRFSM {
        let anchor = IRFSM()
        anchor.start.transitions = [
            .epsilon(anchor.end, condition)
        ]
        return anchor
    }
}

private extension Cursor {
    var isAtWordBoundary: Bool {
        guard let char = character else {
            return true // Already reached the end of the string
        }

        let lhs = (index > string.startIndex) ? character(offsetBy: -1) : " "
        let rhs = (index < string.index(before: string.endIndex)) ? character(offsetBy: 1) : " "

        if char.isWord {
            return !lhs.isWord
        } else {
            return lhs.isWord || rhs.isWord
        }
    }
}

// MARK: - IRFSM (Group)

extension IRFSM {
    static func group(_ child: IRFSM) -> IRFSM {
        let group = IRFSM()
        group.start.transitions = [.epsilon(child.start)]
        child.end.transitions = [.epsilon(group.end)]
        return group
    }
}

// MARK: - IRFSM (Backreferences)

extension IRFSM {
    static func backreference(_ groupIndex: Int) -> IRFSM {
        let backreference = IRFSM()
        backreference.start.transitions = [
            .init(backreference.end, Backreference(groupIndex: groupIndex))
        ]
        return backreference
    }

    private struct Backreference: Condition {
        let groupIndex: Int

        func canTransition(_ cursor: Cursor) -> ConditionResult {
            guard let groupRange = cursor.groups[groupIndex] else {
                return .rejected
            }
            let group = cursor.string[groupRange]
            guard cursor.string[cursor.index...].hasPrefix(group) else {
                return .rejected
            }
            return .accepted(count: group.count)
        }
    }
}

// MARK: - IRFSM (Operations)

extension IRFSM {

    /// Concatenates the given state machines so that they are executed one by
    /// one in a row.
    static func concatenate<S>(_ machines: S) -> IRFSM
        where S: Collection, S.Element == IRFSM {
            guard let first = machines.first else { return .empty }
            return machines.dropFirst().reduce(first, IRFSM.concatenate)
    }

    static func concatenate(_ lhs: IRFSM, _ rhs: IRFSM) -> IRFSM {
        precondition(lhs.end.transitions.isEmpty, "Invalid state of \(lhs)")
        precondition(rhs.end.transitions.isEmpty, "Invalid state of \(rhs)")

        lhs.end.transitions = [.epsilon(rhs.start)]
        return IRFSM(start: lhs.start, end: rhs.end)
    }

    static func alternate<S>(_ machines: S) -> IRFSM
        where S: Sequence, S.Element == IRFSM {
            let alternation = IRFSM()

            for fsm in machines {
                precondition(fsm.end.transitions.isEmpty, "Invalid state of \(fsm)")

                alternation.start.transitions.append(.epsilon(fsm.start))
                fsm.end.transitions = [.epsilon(alternation.end)]
            }

            return alternation
    }

    static func alternate(_ lhs: IRFSM, _ rhs: IRFSM) -> IRFSM {
        return alternate([lhs, rhs])
    }
}

// MARK: - IRFSM (Symbols)

extension IRFSM {
    /// Enumerates all the state in the state machine using breadth-first search.
    func allStates() -> [IRState] {
        var states = [IRState]()
        start.visit { state, _ in
            states.append(state)
        }
        return states
    }
}

extension IRState {
    func visit(_ closure: (IRState, Int) -> Void) {
        // Go throught the graph of states using breadh-first search.
        var encountered = Set<IRState>()
        var queue = [(IRState, Int)]()
        queue.append((self, 0))
        encountered.insert(self)

        while !queue.isEmpty {
            let (state, level) = queue.removeFirst() // This isn't fast
            closure(state, level)

            for neighboor in state.transitions.map({ $0.end })
                where !encountered.contains(neighboor) {
                    queue.append((neighboor, level+1))
                    encountered.insert(neighboor)
            }
        }
    }
}
