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
    init(condition: @escaping (Character) -> Bool) {
        self = FSM()
        start.transitions = [.init(end, { cursor in
            guard let character = cursor.character else {
                return nil
            }
            return condition(character) ? 1 : nil
        })]
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
    /// Matches the given character.
    static func character(_ c: Character, isCaseInsensitive: Bool) -> FSM {
        return FSM {
            if isCaseInsensitive {
                return String(c).caseInsensitiveCompare(String($0)) == ComparisonResult.orderedSame
            } else {
                return $0 == c
            }
        }
    }

    /// Matches the given string. In general is going to be much faster than
    /// checking the individual characters (fast substring search).
    static func string(_ s: String, isCaseInsensitive: Bool) -> FSM {
        let fsm = FSM()
        fsm.start.transitions = [
            .init(fsm.end) { cursor -> Int? in
                match(cursor, s, isCaseInsensitive: isCaseInsensitive)
            }
        ]
        return fsm
    }

    private static func match(_ cursor: Cursor, _ s: String, isCaseInsensitive: Bool) -> Int? {
        guard let ub = cursor.string.index(cursor.index, offsetBy: s.count, limitedBy: cursor.string.endIndex) else {
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

    /// Matches the given character set.
    static func characterSet(_ set: CharacterSet, isCaseInsensitive: Bool) -> FSM {
        return FSM {
            if isCaseInsensitive, $0.isCased {
                return set.contains(Character($0.lowercased())) || set.contains(Character($0.uppercased()))
            } else {
                return set.contains($0)
            }
        }
    }

    /// Matches any character.
    static func anyCharacter(includingNewline: Bool) -> FSM {
        return FSM { includingNewline ? true : $0 != "\n" }
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
    /// Matches the beginning of the string (or beginning of the line when
    /// `.multiline` option is enabled).
    static var startOfString: FSM {
        return anchor { cursor in cursor.index == cursor.string.startIndex }
    }

    /// Matches the beginning of the string (ignores `.multiline` option).
    static var startOfStringOnly: FSM {
        return anchor { cursor in
            cursor.startIndex == cursor.completeInputString.startIndex
        }
    }

    /// Matches the end of the string or `\n` at the end of the string
    /// (end of the line in `.multiline` mode).
    static var endOfString: FSM {
        return anchor { cursor in
            return cursor.isEmpty || (cursor.isAtLastIndex && cursor.character == "\n")
        }
    }

    /// Matches the end of the string or `\n` at the end of the string (ignores `.multiline` option).
    static var endOfStringOnly: FSM {
        return anchor { cursor in
            guard cursor.string.endIndex == cursor.completeInputString.endIndex ||
                // In multiline mode `\n` are removed from the lines during preprocessing.
                (cursor.string.endIndex == cursor.completeInputString.index(before: cursor.completeInputString.endIndex) && cursor.completeInputString.last == "\n") else {
                    return false
            }
            return cursor.isEmpty || (cursor.isAtLastIndex && cursor.character == "\n")
        }
    }

    /// Matches the end of the string or `\n` at the end of the string (ignores `.multiline` option).
    static var endOfStringOnlyNotNewline: FSM {
        return anchor { cursor in
            return cursor.string.endIndex == cursor.completeInputString.endIndex && cursor.isEmpty
        }
    }

    /// Match must occur at the point where the previous match ended. Ensures
    /// that all matches are contiguous.
    static var previousMatchEnd: FSM {
        return anchor { cursor in
            if cursor.string.startIndex == cursor.completeInputString.startIndex {
                return true // There couldn't be any matches before the start index
            }
            guard let previousMatchIndex = cursor.previousMatchIndex else {
                return false
            }
            return cursor.string.startIndex == cursor.completeInputString.index(after: previousMatchIndex)
        }
    }

    /// The match must occur on a word boundary.
    static var wordBoundary: FSM {
        return anchor { cursor in cursor.isAtWordBoundary }
    }

    /// The match must occur on a non-word boundary.
    static var nonWordBoundary: FSM {
        return anchor { cursor in !cursor.isAtWordBoundary }
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

    /// Enumerates all the state in the state machine using breadth-first search.
    func allStates() -> [State] {
        var states = [State]()
        visit { state, _ in
            states.append(state)
        }
        return states
    }

    func visit(_ closure: (State, Int) -> Void) {
        // Go throught the graph of states using breadh-first search.
        var encountered = Set<State>()
        var queue = [(State, Int)]()
        queue.append((start, 0))
        encountered.insert(start)

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
