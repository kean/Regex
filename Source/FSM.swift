// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

// MARK: - FSM

/// A convenience API for creating finite state machines (FSM) which represent
/// regular expressions.
struct FSM {
    let start: State
    let end: State

    init(start: State = State(), end: State = State()) {
        self.start = start
        self.end = end
    }

    init(condition: Condition) {
        self = FSM()
        start.transitions = [.init(end, condition)]
    }

    /// Creates an empty state machine.
    static var empty: FSM {
        let fsm = FSM()
        fsm.start.transitions = [.epsilon(fsm.end)]
        return fsm
    }
}

// MARK: - FSM (Character Classes)

extension FSM {

    // MARK: .character

    /// Matches the given character.
    static func character(_ c: Character, isCaseInsensitive: Bool) -> FSM {
        FSM(condition: MatchCharacter(character: c, isCaseInsensitive: isCaseInsensitive))
    }

    private struct MatchCharacter: Condition {
        let character: Character
        let isCaseInsensitive: Bool

        func canPerformTransition(_ cursor: Cursor) -> ConditionResult {
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
    static func string(_ s: String, isCaseInsensitive: Bool) -> FSM {
        assert(!s.isEmpty)
        return FSM(condition: MatchString(string: s, count: s.count, isCaseInsensitive: isCaseInsensitive))
    }

    private struct MatchString: Condition {
        let string: String
        let count: Int
        let isCaseInsensitive: Bool

        func canPerformTransition(_ cursor: Cursor) -> ConditionResult {
            guard let ub = cursor.index(cursor.index, offsetBy: count, isLimited: true) else {
                return .rejected
            }
            let input = cursor[cursor.index..<ub]

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
    static func characterSet(_ set: CharacterSet, _ isCaseInsensitive: Bool, _ isNegative: Bool) -> FSM {
        if set == .decimalDigits {
            return FSM(condition: MatchAnyNumber())
        }
        return FSM(condition: MatchCharacterSet(set: set, isCaseInsensitive: isCaseInsensitive, isNegative: isNegative))
    }

    private struct MatchCharacterSet: Condition {
        let set: CharacterSet
        let isCaseInsensitive: Bool
        let isNegative: Bool

        func canPerformTransition(_ cursor: Cursor) -> ConditionResult {
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
        func canPerformTransition(_ cursor: Cursor) -> ConditionResult {
            guard let input = cursor.character else { return .rejected }
            return input.isNumber ? .accepted() : .rejected
        }
    }

    // MARK: .range

    static func range(_ range: ClosedRange<Unicode.Scalar>, _ isCaseInsensitive: Bool, _ isNegative: Bool) -> FSM {
        return FSM(condition: MatchUnicodeScalarRange(range: range, isCaseInsensitive: isCaseInsensitive, isNegative: isNegative))
    }

    private struct MatchUnicodeScalarRange: Condition {
        let range: ClosedRange<Unicode.Scalar>
        let isCaseInsensitive: Bool
        let isNegative: Bool

        func canPerformTransition(_ cursor: Cursor) -> ConditionResult {
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
    static func anyCharacter(includingNewline: Bool) -> FSM {
        FSM(condition: MatchAnyCharacter(includingNewline: includingNewline))
    }

    private struct MatchAnyCharacter: Condition {
        let includingNewline: Bool

        func canPerformTransition(_ cursor: Cursor) -> ConditionResult {
            guard !cursor.isEmpty else { return .rejected }
            return (includingNewline || cursor[cursor.index] != "\n") ? .accepted() : .rejected
        }
    }
}

// MARK: - FSM (Quantifiers)

extension FSM {
    /// Matches the given FSM zero or more times.
    static func zeroOrMore(_ child: FSM, _ isLazy: Bool) -> FSM {
        let quantifier = FSM()

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
    static func oneOrMore(_ child: FSM, _ isLazy: Bool) -> FSM {
        let quantifier = FSM()
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
    static func zeroOrOne(_ child: FSM, _ isLazy: Bool) -> FSM {
        let quantifier = FSM()
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

// MARK: - FSM (Anchors)

extension FSM {
    /// Matches the beginning of the line.
    static var startOfString: FSM {
        anchor { cursor in
            cursor.startIndex == cursor.string.startIndex || cursor.isEmpty || cursor.character == "\n"
        }
    }

    /// Matches the beginning of the string (ignores `.multiline` option).
    static var startOfStringOnly: FSM {
        anchor { cursor in
            cursor.startIndex == cursor.string.startIndex
        }
    }

    /// Matches the end of the string or `\n` at the end of the string
    /// (end of the line in `.multiline` mode).
    static var endOfString: FSM {
        anchor { cursor in
            cursor.isEmpty || cursor.character == "\n"
        }
    }

    /// Matches the end of the string or `\n` at the end of the string.
    static var endOfStringOnly: FSM {
        anchor { cursor in
            cursor.isEmpty || (cursor.isAtLastIndex && cursor.character == "\n")
        }
    }

    /// Matches the end of the string or `\n` at the end of the string (ignores `.multiline` option).
    static var endOfStringOnlyNotNewline: FSM {
        anchor { cursor in cursor.isEmpty }
    }

    /// Match must occur at the point where the previous match ended. Ensures
    /// that all matches are contiguous.
    static var previousMatchEnd: FSM {
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
    static var wordBoundary: FSM {
        anchor { cursor in cursor.isAtWordBoundary }
    }

    /// The match must occur on a non-word boundary.
    static var nonWordBoundary: FSM {
        anchor { cursor in !cursor.isAtWordBoundary }
    }

    private static func anchor(_ condition: @escaping (Cursor) -> Bool) -> FSM {
        let anchor = FSM()
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

// MARK: - FSM (Group)

extension FSM {
    static func group(_ child: FSM) -> FSM {
        let group = FSM()
        group.start.transitions = [.epsilon(child.start)]
        child.end.transitions = [.epsilon(group.end)]
        return group
    }
}

// MARK: - FSM (Backreferences)

extension FSM {
    static func backreference(_ groupIndex: Int) -> FSM {
        let backreference = FSM()
        backreference.start.transitions = [
            .init(backreference.end, Backreference(groupIndex: groupIndex))
        ]
        return backreference
    }

    private struct Backreference: Condition {
        let groupIndex: Int

        func canPerformTransition(_ cursor: Cursor) -> ConditionResult {
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

// MARK: - FSM (Operations)

extension FSM {

    /// Concatenates the given state machines so that they are executed one by
    /// one in a row.
    static func concatenate<S>(_ machines: S) -> FSM
        where S: Collection, S.Element == FSM {
            guard let first = machines.first else { return .empty }
            return machines.dropFirst().reduce(first, FSM.concatenate)
    }

    static func concatenate(_ lhs: FSM, _ rhs: FSM) -> FSM {
        precondition(lhs.end.transitions.isEmpty, "Invalid state of \(lhs)")
        precondition(rhs.end.transitions.isEmpty, "Invalid state of \(rhs)")

        lhs.end.transitions = [.epsilon(rhs.start)]
        return FSM(start: lhs.start, end: rhs.end)
    }

    static func alternate<S>(_ machines: S) -> FSM
        where S: Sequence, S.Element == FSM {
            let alternation = FSM()

            for fsm in machines {
                precondition(fsm.end.transitions.isEmpty, "Invalid state of \(fsm)")

                alternation.start.transitions.append(.epsilon(fsm.start))
                fsm.end.transitions = [.epsilon(alternation.end)]
            }

            return alternation
    }
}

// MARK: - FSM (Symbols)

extension FSM {
    /// Enumerates all the state in the state machine using breadth-first search.
    func allStates() -> [State] {
        var states = [State]()
        start.visit { state, _ in
            states.append(state)
        }
        return states
    }
}

extension State {
    func visit(_ closure: (State, Int) -> Void) {
        // Go throught the graph of states using breadh-first search.
        var encountered = Set<State>()
        var queue = [(State, Int)]()
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
