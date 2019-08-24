// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation
import os.log

/// A bottom-up parser for regular expressions.
final class Parser {
    private let pattern: String
    private let scanner: Scanner
    private var groupIndex = 1
    private var nextGroupIndex: Int {
        defer { groupIndex += 1 }
        return groupIndex
    }

    #if DEBUG
    private let log: OSLog = Regex.isDebugModeEnabled ? OSLog(subsystem: "com.github.kean.parser", category: "default") : .disabled
    #endif

    init(_ pattern: String) {
        self.pattern = pattern
        self.scanner = Scanner(pattern)
    }

    /// Parses the pattern with which the parser was initialized with and
    /// constrats an AST (abstract syntax tree).
    func parse() throws -> AST {
        // Handled by Matcher
        let startOfString = parseStartOfStringAnchor() != nil

        let ast = AST(
            root: optimize(try parseExpression()),
            isFromStartOfString: startOfString,
            pattern: pattern
        )

        guard scanner.peak() == nil else {
            throw Regex.Error("Unmatched closing parentheses", 0)
        }

        #if DEBUG
        if log.isEnabled { os_log(.default, log: self.log, "AST: \n%{PUBLIC}@", ast.description) }
        #endif

        return ast
    }
}

// MARK: - Parser (Parse)

private extension Parser {

    // MARK: Expressions

    /// The entry point for parsing an expression, can be called recursively.
    func parseExpression() throws -> Unit {
        var children: [[Unit]] = [[]] // Each sub-array represents an alternation

        func add(_ unit: Unit) {
            children[children.endIndex-1].append(unit)
        }

        // Appplies quantifier to the last expression.
        func apply(_ quantifier: Quantifier) throws {
            guard let last = children[children.endIndex-1].popLast() else {
                throw Regex.Error("The preceeding token is not quantifiable", 0)
            }
            let isLazy = scanner.read("?") != nil
            let source = last.source.lowerBound..<scanner.i
            add(QuantifiedExpression(type: quantifier, isLazy: isLazy, expression: last, source: source))
        }

        while let c = scanner.peak(), c != ")" {
            switch c {
            case "(": add(try parseGroup())
            case "|": scanner.read(); children.append([]) // Start a new path in alternation
            case "*", "+", "?", "{": try apply(try parseQuantifier(c))
            default: add(try parseTerminal())
            }
        }

        let expressions = try children.map(expression) // Flatten the children
        switch expressions.count {
        case 0: throw Regex.Error("Pattern must not be empty", 0)
        case 1: return expressions[0] // No alternation
        default:
            let source = Range.merge(expressions.first!.source, expressions.last!.source)
            return Alternation(children: expressions, source: source)
        }
    }

    static let terminalKeywords = CharacterSet(charactersIn: ".\\[$")

    /// Parses a terminal part of the expression, e.g. a simple character match,
    /// or an anchor, anything that doesn't contain subexpressions.
    func parseTerminal() throws -> Terminal {
        let c = try scanner.peak(orThrow: "Pattern must not be empty")
        switch c {
        case ".":
            return Match(type: .anyCharacter, source: scanner.read())
        case "\\":
            return try parseEscapedCharacter()
        case "[":
            let (group, range) = try scanner.readCharacterGroup()
            let match: MatchType
            switch group.kind {
            case let .range(range): match = .range(range, isNegative: group.isNegative)
            case let .set(set): match = .characterSet(set, isNegative: group.isNegative)
            }
            return Match(type: match, source: range)
        case "$":
            return Anchor(type: .endOfString, source: scanner.read())
        default:
            return Match(type: .character(c), source: scanner.read())
        }
    }

    // MARK: Groups

    /// Parses a group, can be called recursively.
    func parseGroup() throws -> Group {
        let groupIndex = nextGroupIndex
        let start = try scanner.read("(", orThrow: "Unmatched closing parantheses")
        let isCapturing = scanner.read("?:") == nil
        let expression = try parseExpression()
        let end = try scanner.read(")", orThrow: "Unmatched opening parentheses")
        return Group(index: groupIndex, isCapturing: isCapturing, children: [expression], source: .merge(start, end))
    }

    // MARK: Quantifiers

    func parseQuantifier(_ c: Character) throws -> Quantifier {
        scanner.read()
        switch c {
        case "*": return .zeroOrMore
        case "+": return .oneOrMore
        case "?": return .zeroOrOne
        case "{": return try parseRangeQuantifier()
        default: fatalError("Invalid token")
        }
    }

    func parseRangeQuantifier() throws -> Quantifier {
        let range = try scanner.readRangeQuantifier()
        return Quantifier.range(range)
    }

    // MARK: Character Escapes

    func parseEscapedCharacter() throws -> Terminal {
        let start = scanner.read() // Consume escape

        guard let c = scanner.peak() else {
            throw Regex.Error("Pattern may not end with a trailing backslash", 0)
        }

        if let (index, range) = scanner.readInt() {
            return Backreference(index: index, source: .merge(start, range))
        }

        if let anchor = anchor(for: c) {
            return Anchor(type: anchor, source: .merge(start, scanner.read()))
        }

        // TODO: tidy up
        scanner.read()
        if let set = try scanner.readCharacterClassSpecialCharacter(c) {
            return Match(type: .characterSet(set), source: .merge(start, scanner.i..<scanner.i))
        }
        scanner.undoRead()

        return Match(type: .character(c), source: .merge(start, scanner.read()))
    }

    func anchor(for c: Character) -> AnchorType? {
        switch c {
        case "b": return .wordBoundary
        case "B": return .nonWordBoundary
        case "A": return .startOfStringOnly
        case "Z": return .endOfStringOnly
        case "z": return .endOfStringOnlyNotNewline
        case "G": return .previousMatchEnd
        default: return nil
        }
    }

    // MARK: Options

    func parseStartOfStringAnchor() -> Anchor? {
        guard let source = scanner.read("^") else { return nil }
        return Anchor(type: .startOfString, source: source)
    }

    // MARK: Helpers

    /// Creates an node which represents an expression. If there is only one
    /// child, returns a child itself to avoid additional overhead.
    func expression(_ children: [Unit]) throws -> Unit {
        switch children.count {
        case 0: throw Regex.Error("Pattern must not be empty", 0)
        case 1: return children[0]
        default:
            let source = Range.merge(children.first!.source, children.last!.source)
            return Expression(children: children, source: source)
        }
    }
}

// MARK: - Parser (Optimize)

private extension Parser {

    func optimize(_ unit: Unit) -> Unit {
        switch unit {
        case let expression as Expression:
            return optimize(expression)
        case let group as Group:
            return optimize(group)
        case let alternation as Alternation:
            return optimize(alternation)
        case let quantifier as QuantifiedExpression:
            return optimize(quantifier)
        default:
            return unit
        }
    }

    func optimize(_ expression: Expression) -> Unit {
        var input = Array(expression.children.reversed())
        var output = [Unit]()

        while let unit = input.popLast() {
            switch unit {
            // [Optimization] Collapse multiple string into a single string
            case let match as Match:
                guard case let .character(c) = match.type else {
                    output.append(match)
                    continue
                }

                var range = match.source
                var chars = [c]
                while let match = input.last as? Match, case let .character(c) = match.type {
                    input.removeLast()
                    chars.append(c)
                    range = range.lowerBound..<match.source.upperBound
                }
                if chars.count > 1 {
                    output.append(Match(type: .string(String(chars)), source: range))
                } else {
                    output.append(Match(type: .character(chars[0]), source: range))
                }
            default:
                output.append(optimize(unit))
            }
        }
        if output.count > 1 {
            return Expression(children: output, source: expression.source)
        } else {
            return output[0]
        }
    }

    func optimize(_ group: Group) -> Group {
        return Group(
            index: group.index,
            isCapturing: group.isCapturing,
            children: group.children.map(optimize),
            source: group.source
        )
    }

    func optimize(_ alternation: Alternation) -> Alternation {
        return Alternation(
            children: alternation.children.map(optimize),
            source: alternation.source
        )
    }

    func optimize(_ quantifier: QuantifiedExpression) -> QuantifiedExpression {
        return QuantifiedExpression(type: quantifier.type, isLazy: quantifier.isLazy, expression: optimize(quantifier.expression), source: quantifier.source)
    }
}
