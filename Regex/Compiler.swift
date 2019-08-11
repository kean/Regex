// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

/// Compiles a pattern into a finite state machine.
final class Compiler {
    private let parser: Parser
    private let options: Regex.Options

    private var stack = [StackEntry]()

    init(_ pattern: String, _ options: Regex.Options) {
        self.parser = Parser(Array(pattern))
        self.options = options
    }

    func compile() throws -> Expression {
        Expression.nextId = 0 // Id are used for logging

        let shouldMatchStart = parser.read("^")

        if shouldMatchStart {
            stack.append(.expression(.startOfString))
        }

        while let c = parser.readCharacter() {
            switch c {
            // Grouping
            case "(":
                let isCapturing = !parser.read("?:")
                stack.append(.group(Group(openingBracketIndex: i, isCapturing: isCapturing)))
            case ")":
                try collapseLastGroup()

            // Alternation
            case "|":
                stack.append(.alternate)

            // Quantifiers
            case "*": // Zero or more
                try addQuantifier(Expression.zeroOrMore)
            case "+": // One or more
                try addQuantifier(Expression.oneOrMore)
            case "?": // Zero or one
                try addQuantifier(Expression.noneOrOne)
            case "{": // Match N times
                try addQuantifier {
                    Expression.range(try parser.readRangeQuantifier(), $0)
                }

            // Character Classes
            case ".": // Any character
                stack.append(.expression(.anyCharacter(includingNewline: options.contains(.dotMatchesLineSeparators))))
            case "[": // Start a character group
                let set = try parser.readCharacterSet()
                stack.append(.expression(.characterSet(set)))

            // Anchors
            case "$":
                stack.append(.expression(.endOfString))

            // Character Escapes
            case "\\":
                let expression = try compilerCharacterAfterEscape()
                stack.append(.expression(expression))

            default: // Not a keyword, treat as a plain character
                stack.append(.expression(.character(c)))
            }
        }

        let regex = try collapse() // Collapse on regexes in an implicit top group

        guard stack.isEmpty else {
            if case let .group(group)? = stack.last {
                throw Regex.Error("Unmatched opening parentheses", group.openingBracketIndex)
            } else {
                fatalError("Unsupported error")
            }
        }

        return regex
    }
}

private extension Compiler {

    func compilerCharacterAfterEscape() throws -> Expression {
        guard let c = parser.readCharacter() else {
            throw Regex.Error("Pattern may not end with a trailing backslash", i)
        }
        switch c {
        case "b": return .wordBoundary
        case "B": return .nonWordBoundary
        case "A": return .startOfStringOnly
        case "Z": return .endOfStringOnly
        case "z": return .endOfStringOnlyNotNewline
        case "G": return .previousMatchEnd
        default:
            if let set = try parser.readCharacterClassSpecialCharacter(c) {
                return .characterSet(set)
            } else {
                return .character(c)
            }
        }
    }

    /// Returns the index of the character which is currently being processed.
    var i: Int {
        return parser.i - 1
    }

    // MARK: Stack

    func popExpression() throws -> Expression {
        guard case let .expression(expression)? = stack.popLast() else {
            throw Regex.Error("Failed to find a matching group", i)
        }
        return expression
    }

    /// Add quantifier to the top expression in the stack.
    func addQuantifier(_ closure: (Expression) throws -> Expression) throws {
        let last: Expression
        do {
            last = try popExpression()
        } catch {
            throw Regex.Error("The preceeding token is not quantifiable", i)
        }
        stack.append(.expression(try closure(last)))
    }

    func collapseLastGroup() throws {
        // Collapses the expression in the group.
        let expression = try collapse()

        guard case let .group(info)? = stack.popLast() else {
            throw Regex.Error("Unmatched closing parentheses", i)
        }

        let group = Expression.group(expression, isCapturing: info.isCapturing)

        stack.append(.expression(group))
    }

    /// Collapses the items in the top group. Also collapses alternations in the
    /// top group. Returns a single expression.
    private func collapse() throws -> Expression {
        var alternatives = [Expression]()

        var stop = false
        while !stop {
            stop = true
            var expressions = [Expression]()
            while case let .expression(expression)? = stack.last {
                stack.removeLast()
                expressions.append(expression)
            }
            alternatives.append(.concatenate(expressions.reversed()))

            if case .alternate? = stack.last {
                stack.removeLast()
                stop = false
            }
        }

        guard alternatives.count > 1 else {
            return alternatives[0] // Must have at least one
        }

        return Expression.alternate(alternatives)
    }
}

// MARK: - Intermeidate Representations

private enum StackEntry {
    case expression(Expression)
    case group(Group) // (
    case alternate // |
}

private struct Group {
    let openingBracketIndex: Int
    let isCapturing: Bool
}
