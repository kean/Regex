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

    /// Automatically sets up a single consuming transition from start to end
    /// with the given condition.
    init(condition: @escaping (Cursor) -> Int?) {
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
        FSM(condition: match(c, isCaseInsensitive))
    }

    private static func match(_ c: Character, _ isCaseInsensitive: Bool) -> (_ cursor: Cursor) -> Int? {
        return { cursor in
            guard let input = cursor.character else { return nil }
            let isEqual: Bool
            if isCaseInsensitive {
                isEqual = String(c).caseInsensitiveCompare(String(input)) == ComparisonResult.orderedSame
            } else {
                isEqual = input == c
            }
            return isEqual ? 1 : nil
        }
    }

    // MARK: .string

    /// Matches the given string. In general is going to be much faster than
    /// checking the individual characters (fast substring search).
    static func string(_ s: String, isCaseInsensitive: Bool) -> FSM {
        FSM(condition: match(s, s.count, isCaseInsensitive))
    }

    private static func match(_ s: String, _ sCount: Int, _ isCaseInsensitive: Bool) -> (_ cursor: Cursor) -> Int? {
        return { cursor in
            guard let ub = cursor.string.index(cursor.index, offsetBy: sCount, limitedBy: cursor.string.endIndex) else {
                return nil
            }
            let input = cursor.string[cursor.index..<ub]

            if isCaseInsensitive {
                // TODO: test this
                guard String(input).caseInsensitiveCompare(s) == ComparisonResult.orderedSame else {
                    return nil
                }
            } else {
                guard input == s else {
                    return nil
                }
            }
            return s.count
        }
    }

    // MARK: .characterSet

    /// Matches the given character set.
    static func characterSet(_ set: CharacterSet, _ isCaseInsensitive: Bool, _ isNegative: Bool) -> FSM {
        if set == .decimalDigits {
            return FSM(condition: matchAnyNumber)
        }
        return FSM(condition: match(set, isCaseInsensitive, isNegative))
    }

    private static func match(_ set: CharacterSet, _ isCaseInsensitive: Bool, _ isNegative: Bool) -> (_ cursor: Cursor) -> Int? {
        return { cursor in
            guard let input = cursor.character else { return nil }
            let isMatch: Bool
            if isCaseInsensitive, input.isCased {
                isMatch = set.contains(Character(input.lowercased())) || set.contains(Character(input.uppercased()))
            } else {
                isMatch = set.contains(input)
            }
            return (isMatch != isNegative) ? 1 : nil
        }
    }

    private static func matchAnyNumber(_ cursor: Cursor) -> Int? {
        guard let input = cursor.character else { return nil }
        return input.isNumber ? 1 : nil
    }

    // MARK: .range

    static func range(_ range: ClosedRange<Unicode.Scalar>, _ isCaseInsensitive: Bool, _ isNegative: Bool) -> FSM {
        return FSM { cursor in
            guard let input = cursor.character else { return nil }
            let isMatch: Bool
            if isCaseInsensitive, input.isCased {
                // TODO: this definitely isn't efficient
                isMatch = range.contains(input.lowercased().unicodeScalars.first!) ||
                    range.contains(input.uppercased().unicodeScalars.first!)
             } else {
                isMatch = input.unicodeScalars.allSatisfy(range.contains)
             }
             return (isMatch != isNegative) ? 1 : nil
        }
    }

    // MARK: .anyCharacter

    /// Matches any character.
    static func anyCharacter(includingNewline: Bool) -> FSM {
        FSM { cursor in
            guard !cursor.isEmpty else { return nil }
            return (includingNewline || cursor.string[cursor.index] != "\n") ? 1 : nil
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
            .init(backreference.end) { cursor -> Int? in
                guard let groupRange = cursor.groups[groupIndex] else {
                    return nil
                }
                let group = cursor.string[groupRange]
                guard cursor.string[cursor.index...].hasPrefix(group) else {
                    return nil
                }
                return group.count
            }
        ]
        return backreference
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

    static func alternate(_ lhs: FSM, _ rhs: FSM) -> FSM {
        return alternate([lhs, rhs])
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
    func description(_ symbols: Symbols) -> String {
        var states = [String]()

        visit { state, _ in
            let transitions = state.transitions
                .map { "  – Transition to \($0.end)" }
                .joined(separator: "\n")

            let info = symbols.description(for: state)
            let desc =  "\(info)\n\(transitions)"
            states.append(desc)
        }
        return states.joined(separator: "\n")
    }

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
