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
    private let options: Regex.Options
    private let log: OSLog = Regex.isDebugModeEnabled ? OSLog(subsystem: "com.github.kean.parser", category: "default") : .disabled

    init(_ pattern: String, _ options: Regex.Options) {
        self.pattern = pattern
        self.scanner = Scanner(pattern)
        self.options = options
    }

    /// Parses the pattern with which the parser was initialized with and
    /// constrats an AST (abstract syntax tree).
    func parse() throws -> AST {
        var units = [Unit]()
        if let startOfString = parseStartOfStringAnchor() {
            units.append(startOfString)
        }
        units.append(try parseExpression())

        let ast = AST(expression: try expression(units), pattern: pattern)

        guard scanner.peak() == nil else {
            throw Regex.Error("Unmatched closing parentheses", 0)
        }

        os_log(.default, log: self.log, "AST: \n%{PUBLIC}@", ast.description)

        return ast
    }
}

private extension Parser {

    // MARK: Expressions

    /// The entry point for parsing an expression, can be called recursively.
    func parseExpression() throws -> Unit {
        var children: [[Unit]] = [[]] // Each sub-array represents an alternation

        func add(_ unit: Unit) {
            children[children.endIndex-1].append(unit)
        }

        // Appplies quantifier to the last expression.
        func apply(_ quantifier: AST.Quantifier) throws {
            guard let last = children[children.endIndex-1].popLast() else {
                throw Regex.Error("The preceeding token is not quantifiable", 0)
            }
            let source = last.source.lowerBound..<scanner.i
            add(AST.QuantifiedExpression(type: quantifier, expression: last, source: source))
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
            return AST.Alternation(children: expressions, source: source)
        }
    }

    /// Parses a terminal part of the expression, e.g. a simple character match,
    /// or an anchor, anything that doesn't contain subexpressions.
    func parseTerminal() throws -> Terminal {
        let c = try scanner.peak(orThrow: "Pattern must not be empty")
        switch c {
        case ".":
            let newline = options.contains(.dotMatchesLineSeparators)
            return AST.Match(type: .anyCharacter(includingNewline: newline), source: scanner.read())
        case "\\":
            return try parseEscapedCharacter()
        case "[":
            let (set, range) = try scanner.readCharacterSet()
            return AST.Match(type: .characterSet(set), source: range)
        case "$":
            return AST.Anchor(type: .endOfString, source: scanner.read())
        default:
            return AST.Match(type: .character(c), source: scanner.read())
        }
    }

    // MARK: Groups

    /// Parses a group, can be called recursively.
    func parseGroup() throws -> AST.Group {
        let groupIndex = nextGroupIndex
        let start = try scanner.read("(", orThrow: "Unmatched closing parantheses")
        let isCapturing = scanner.read("?:") == nil
        let expression = try parseExpression()
        let end = try scanner.read(")", orThrow: "Unmatched opening parentheses")
        return AST.Group(index: groupIndex, isCapturing: isCapturing, children: [expression], source: .merge(start, end))
    }

    // MARK: Quantifiers

    func parseQuantifier(_ c: Character) throws -> AST.Quantifier {
        scanner.read()
        switch c {
        case "*": return .zeroOrMore
        case "+": return .oneOrMore
        case "?": return .zeroOrOne
        case "{": return try parseRangeQuantifier()
        default: fatalError("Invalid token")
        }
    }

    func parseRangeQuantifier() throws -> AST.Quantifier {
        let range = try scanner.readRangeQuantifier()
        return AST.Quantifier.range(range)
    }

    // MARK: Character Escapes

    func parseEscapedCharacter() throws -> Terminal {
        let start = scanner.read() // Consume escape

        guard let c = scanner.peak() else {
            throw Regex.Error("Pattern may not end with a trailing backslash", 0)
        }

        if let (index, range) = scanner.readInt() {
            return AST.Backreference(index: index, source: .merge(start, range))
        }

        if let anchor = anchor(for: c) {
            return AST.Anchor(type: anchor, source: .merge(start, scanner.read()))
        }

        // TODO: tidy up
        scanner.read()
        if let set = try scanner.readCharacterClassSpecialCharacter(c) {
            return AST.Match(type: .characterSet(set), source: .merge(start, scanner.i..<scanner.i))
        }
        scanner.undoRead()

        return AST.Match(type: .character(c), source: .merge(start, scanner.read()))
    }

    func anchor(for c: Character) -> AST.AnchorType? {
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

    func parseStartOfStringAnchor() -> AST.Anchor? {
        guard let source = scanner.read("^") else { return nil }
        return AST.Anchor(type: .startOfString, source: source)
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
            return AST.Expression(children: children, source: source)
        }
    }
}
