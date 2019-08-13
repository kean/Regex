// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

// MARK: - Expression

/// A convenience API for creating expressions.
struct Expression {
    let start: State
    let end: State

    init(start: State = State(), end: State = State()) {
        self.start = start
        self.end = end
    }

    /// Automatically sets up a single consuming transition from start to end
    /// with the given condition.
    init(condition: @escaping (Character) -> Bool) {
        self = Expression()
        start.transitions = [.init(end, { cursor in
            guard let character = cursor.character else {
                return nil
            }
            return condition(character) ? 1 : nil
        })]
    }

    /// Creates an empty expression.
    static var empty: Expression {
        let expression = Expression()
        expression.start.transitions = [.epsilon(expression.end)]
        return expression
    }
}

// MARK: - Expression (Character Classes)

extension Expression {
    /// Matches the given character.
    static func character(_ c: Character, isCaseInsensitive: Bool) -> Expression {
        return Expression {
            if isCaseInsensitive {
                return String(c).caseInsensitiveCompare(String($0)) == ComparisonResult.orderedSame
            } else {
                return $0 == c
            }
        }
    }

    /// Matches the given character set.
    static func characterSet(_ set: CharacterSet, isCaseInsensitive: Bool) -> Expression {
        return Expression {
            if isCaseInsensitive, $0.isCased {
                return set.contains(Character($0.lowercased())) || set.contains(Character($0.uppercased()))
            } else {
                return set.contains($0)
            }
        }
    }

    /// Matches any character.
    static func anyCharacter(includingNewline: Bool) -> Expression {
        return Expression { includingNewline ? true : $0 != "\n" }
    }
}

// MARK: - Expression (Quantifiers)

extension Expression {
    /// Matches the given expression zero or more times.
    static func zeroOrMore(_ expression: Expression) -> Expression {
        let quantifier = Expression()
        quantifier.start.transitions = [
            .epsilon(expression.start), // Loop (greedy by default)
            .epsilon(quantifier.end) // Skip
        ]
        expression.end.transitions = [
            .epsilon(quantifier.start) // Loop
        ]
        return quantifier
    }

    /// Matches the given expression one or more times.
    static func oneOrMore(_ expression: Expression) -> Expression {
        let quantifier = Expression()
        quantifier.start.transitions = [
            .epsilon(expression.start) // Execute at least once
        ]
        expression.end.transitions = [
            .epsilon(quantifier.start), // Loop
            .epsilon(quantifier.end) // Complete
        ]
        return quantifier
    }

    /// Matches the given expression either none or one time.
    static func zeroOrOne(_ expression: Expression) -> Expression {
        let quantifier = Expression()
        quantifier.start.transitions = [
            .epsilon(expression.start), // Loop (greedy by default)
            .epsilon(quantifier.end) // Skip
        ]
        expression.end.transitions = [
            .epsilon(quantifier.end), // Complete
        ]
        return quantifier
    }
}

// MARK: - Expression (Anchors)

extension Expression {
    /// Matches the beginning of the string (or beginning of the line when
    /// `.multiline` option is enabled).
    static var startOfString: Expression {
        return anchor { cursor in cursor.index == 0 }
    }

    /// Matches the beginning of the string (ignores `.multiline` option).
    static var startOfStringOnly: Expression {
        return anchor { cursor in
            cursor.index == 0 && cursor.substring.startIndex == cursor.string.startIndex
        }
    }

    /// Matches the end of the string or `\n` at the end of the string
    /// (end of the line in `.multiline` mode).
    static var endOfString: Expression {
        return anchor { cursor in
            return cursor.isEmpty || (cursor.isLastIndex && cursor.character == "\n")
        }
    }

    /// Matches the end of the string or `\n` at the end of the string (ignores `.multiline` option).
    static var endOfStringOnly: Expression {
        return anchor { cursor in
            guard cursor.substring.endIndex == cursor.string.endIndex ||
                // In multiline mode `\n` are removed from the lines during preprocessing.
                (cursor.substring.endIndex == cursor.string.index(before: cursor.string.endIndex) && cursor.string.last == "\n") else {
                    return false
            }
            return cursor.isEmpty || (cursor.isLastIndex && cursor.character == "\n")
        }
    }

    /// Matches the end of the string or `\n` at the end of the string (ignores `.multiline` option).
    static var endOfStringOnlyNotNewline: Expression {
        return anchor { cursor in
            return cursor.substring.endIndex == cursor.string.endIndex && cursor.isEmpty
        }
    }

    /// Match must occur at the point where the previous match ended. Ensures
    /// that all matches are contiguous.
    static var previousMatchEnd: Expression {
        return anchor { cursor in
            if cursor.substring.startIndex == cursor.string.startIndex {
                return true // There couldn't be any matches before the start index
            }
            guard let previousMatchIndex = cursor.previousMatchIndex else {
                return false
            }
            return cursor.substring.startIndex == cursor.string.index(after: previousMatchIndex)
        }
    }

    /// The match must occur on a word boundary.
    static var wordBoundary: Expression {
        return anchor { cursor in cursor.isAtWordBoundary }
    }

    /// The match must occur on a non-word boundary.
    static var nonWordBoundary: Expression {
        return anchor { cursor in !cursor.isAtWordBoundary }
    }

    private static func anchor(_ condition: @escaping (Cursor) -> Bool) -> Expression {
        let expression = Expression()
        expression.start.transitions = [
            .epsilon(expression.end, condition)
        ]
        return expression
    }
}

private extension Cursor {
    var isAtWordBoundary: Bool {
        guard let char = character else {
            return true // Already reached the end of the string
        }
        let lhs = character(offsetBy: -1) ?? " "
        let rhs = character(offsetBy: 1) ?? " "

        if char.isWord {
            return !lhs.isWord
        } else {
            return lhs.isWord || rhs.isWord
        }
    }
}

// MARK: - Expression (Group)

extension Expression {
    static func group(_ expression: Expression) -> Expression {
        let group = Expression()
        group.start.transitions = [.epsilon(expression.start)]
        expression.end.transitions = [.epsilon(group.end)]
        return group
    }
}

// MARK: - Expression (Backreferences)

extension Expression {
    static func backreference(_ groupIndex: Int) -> Expression {
        let expression = Expression()
        expression.start.transitions = [
            .init(expression.end) { cursor -> Int? in
                guard let groupRange = cursor.groups[groupIndex] else {
                    return nil
                }
                let group = cursor.substring(groupRange)
                guard cursor.remainingSubstring.hasPrefix(group) else {
                    return nil
                }
                return groupRange.count
            }
        ]
        return expression
    }
}

// MARK: - Expression (Operations)

extension Expression {

    static func concatenate<S>(_ expressions: S) -> Expression
        where S: Collection, S.Element == Expression {
            guard let first = expressions.first else {
                return .empty
            }
            return expressions.dropFirst().reduce(first, Expression.concatenate)
    }

    static func concatenate(_ lhs: Expression, _ rhs: Expression) -> Expression {
        precondition(lhs.end.transitions.isEmpty, "Invalid state of \(lhs)")
        precondition(rhs.end.transitions.isEmpty, "Invalid state of \(rhs)")

        lhs.end.transitions = [.epsilon(rhs.start)]
        return Expression(start: lhs.start, end: rhs.end)
    }

    static func alternate<S>(_ expressions: S) -> Expression
        where S: Sequence, S.Element == Expression {
            let alternation = Expression()

            for expression in expressions {
                precondition(expression.end.transitions.isEmpty, "Invalid state of \(expression)")

                alternation.start.transitions.append(.epsilon(expression.start))
                expression.end.transitions = [.epsilon(alternation.end)]
            }

            return alternation
    }

    static func alternate(_ lhs: Expression, _ rhs: Expression) -> Expression {
        return alternate([lhs, rhs])
    }
}

// MARK: - Expression (Symbols)

extension Expression {
    func description(_ symbols: Symbols) -> String {
        var states = [String]()

        visit { state, _ in
            let details = symbols.map[state]
            let transitions = state.transitions
                .map { "  – Transition to \($0.toState)" }
                .joined(separator: "\n")

            let info = details.map { "\($0.isEnd ? "End" : "Start"), \($0.node.value)" }
            let desc = "\(state), \(info ?? "<symbol missing>") \n\(transitions)"
            states.append(desc)
        }
        return states.joined(separator: "\n")
    }

    /// Enumerates all the state in the expression using breadth-first search.
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

            for neighboor in state.transitions.map({ $0.toState })
                where !encountered.contains(neighboor) {
                    queue.append((neighboor, level+1))
                    encountered.insert(neighboor)
            }
        }
    }
}
