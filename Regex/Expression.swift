// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

// MARK: - Expression

/// A convenience API for manipulating states.
struct Expression {
    private let id: Int
    let start: State
    let end: State

    init(_ description: String) {
        self.id = Expression.makeNextId()
        self.start = State("{ #\(id) Start – \(description) }")
        self.end = State("{ #\(id) End }")
    }

    init(start: State, end: State) {
        self.id = Expression.makeNextId()
        self.start = start
        self.end = end
    }

    /// Automatically sets up a single consuming transition from start to end
    /// with the given condition.
    init(_ description: String, condition: @escaping (Character) -> Bool) {
        self = Expression(description)
        start.transitions = [.consuming(end, condition)]
    }

    static var nextId: Int = 0

    static func makeNextId() -> Int {
        defer { nextId += 1 }
        return nextId
    }
}

extension Expression: CustomStringConvertible {
    var description: String {
        var states = [String]()

        for state in allStates() {
            let transitions = state.transitions
                .map { "  – \($0)" }
                .joined(separator: "\n")
            states.append("\(state) \n\(transitions)\n")
        }

        return states.joined(separator: "\n")
    }

    /// Enumerates all the state in the expression using breadth-first search.
    func allStates() -> [State] {
        var states = [State]()

        // Go throught the graph of states using breadh-first search.
        var encountered = Set<State>()
        var queue = [State]()
        queue.append(start)
        encountered.insert(start)

        while !queue.isEmpty {
            let state = queue.removeFirst() // This isn't fast
            states.append(state)

            for neighboor in state.transitions.map({ $0.toState })
                where !encountered.contains(neighboor) {
                    queue.append(neighboor)
                    encountered.insert(neighboor)
            }
        }

        return states
    }
}

// MARK: - Expression (Character Classes)

extension Expression {
    /// Matches the given character.
    static func character(_ c: Character) -> Expression {
        return Expression("Match character '\(c)'") { $0 == c }
    }

    /// Matches the given character set.
    static func characterSet(_ set: CharacterSet) -> Expression {
        return Expression("Match set \(set)") { set.contains($0) }
    }

    /// Matches any character.
    static func anyCharacter(includingNewline: Bool) -> Expression {
        return Expression("Match any character") { includingNewline ? true : $0 != "\n" }
    }
}

// MARK: - Expression (Quantifiers)

extension Expression {
    /// Matches the given expression zero or more times.
    static func zeroOrMore(_ expression: Expression) -> Expression {
        let quantifier = Expression("Zero or more")
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
        let quantifier = Expression("One or more")
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
    static func noneOrOne(_ expression: Expression) -> Expression {
        let quantifier = Expression("None or one")
        quantifier.start.transitions = [
            .epsilon(expression.start), // Loop (greedy by default)
            .epsilon(quantifier.end) // Skip
        ]
        expression.end.transitions = [
            .epsilon(quantifier.end), // Complete
        ]
        return quantifier
    }

    /// Matches the given expression the given number of times. E.g. if you pass
    /// the range {2,3} it will match the regex either 2 or 3 times.
    static func range(_ range: ClosedRange<Int>, _ expression: Expression) -> Expression {
        let quantifier = Expression("Range \(range)")

        // The quantifier requires a bit of additional state which we implement
        // using context.
        let uuid = UUID()

        quantifier.start.transitions = [
            .epsilon(expression.start, perform: { _, context in
                // Increment the number of times we passed throught this transition
                // during the current execution of the state machine
                var context = context
                let count = (context[uuid] as? Int) ?? 0
                context[uuid] = count + 1
                return context
            })
        ]

        expression.end.transitions = [
            .epsilon(quantifier.end) { _, context in
                let count = context[uuid] as! Int
                return range.contains(count)
            },
            .epsilon(quantifier.start) { _, context in
                let count = context[uuid] as! Int
                return count + 1 <= range.upperBound
            }
        ]

        return quantifier
    }
}

// MARK: - Expression (Anchors)

extension Expression {
    /// Matches the beginning of the string (or beginning of the line when
    /// `.multiline` option is enabled).
    static var startOfString: Expression {
        return anchor("Start of string (^)") { cursor, _ in cursor.index == 0 }
    }

    /// Matches the beginning of the string (ignores `.multiline` option).
    static var startOfStringOnly: Expression {
        return anchor("Start of string only (\\A)") { cursor, _ in
            cursor.index == 0 && cursor.substring.startIndex == cursor.string.startIndex
        }
    }

    /// Matches the end of the string or `\n` at the end of the string
    /// (end of the line in `.multiline` mode).
    static var endOfString: Expression {
        return anchor("End of string ($)") { cursor, _ in
            return cursor.isEmpty || (cursor.isLastIndex && cursor.character == "\n")
        }
    }

    /// Matches the end of the string or `\n` at the end of the string (ignores `.multiline` option).
    static var endOfStringOnly: Expression {
        return anchor("End of string only (\\Z)") { cursor, _ in
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
        return anchor("End of string only (\\z)") { cursor, _ in
            return cursor.substring.endIndex == cursor.string.endIndex && cursor.isEmpty
        }
    }

    /// Match must occur at the point where the previous match ended. Ensures
    /// that all matches are contiguous.
    static var previousMatchEnd: Expression {
        return anchor("Previous match end (\\G)") { cursor, _ in
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
        return anchor("Word boundary (\\b)") { cursor, _ in cursor.isAtWordBoundary }
    }

    /// The match must occur on a non-word boundary.
    static var nonWordBoundary: Expression {
        return anchor("Non word boundary (\\B)") { cursor, _ in !cursor.isAtWordBoundary }
    }

    private static func anchor(_ description: String, _ condition: @escaping (Cursor, Context) -> Bool) -> Expression {
        let expression = Expression(description)
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
    static func group(_ expression: Expression, isCapturing: Bool) -> Expression {
        let group = Expression(isCapturing ? "Capturing group" : "Non-capturing group")
        if isCapturing {
            group.start.info = .groupStart
            group.end.info = .groupEnd(.init(capturingStartState: group.start))
        }
        group.start.transitions = [.epsilon(expression.start)]
        expression.end.transitions = [.epsilon(group.end)]
        return group
    }
}

// MARK: - Expression (Operations)

extension Expression {

    static func concatenate<S>(_ expressions: S) -> Expression
        where S: Collection, S.Element == Expression {
            return expressions.dropFirst().reduce(expressions.first!, Expression.concatenate)
    }

    static func concatenate(_ lhs: Expression, _ rhs: Expression) -> Expression {
        precondition(lhs.end.transitions.isEmpty, "Invalid state of \(lhs)")
        precondition(rhs.end.transitions.isEmpty, "Invalid state of \(rhs)")

        lhs.end.transitions = [.epsilon(rhs.start)]
        return Expression(start: lhs.start, end: rhs.end)
    }

    static func alternate<S>(_ expressions: S) -> Expression
        where S: Sequence, S.Element == Expression {
            let alternation = Expression("Alternate")

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

// MARK: - ExpressionInfo

enum ExpressionInfo {
    /// A capture group start.
    case groupStart

    /// A capture group end.
    case groupEnd(Group)

    struct Group {
        unowned var capturingStartState: State?
    }
}
