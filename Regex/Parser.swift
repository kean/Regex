// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation
import os.log

// MARK: - Parser

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

    /// Scans and analyzes the pattern and creats an abstract syntax tree.
    func parse() throws -> ASTNode {
        guard !pattern.isEmpty else {
            throw Regex.Error("Pattern must not be empty", 0)
        }

        let node = ASTNode(ASTUnit.Expression(), pattern[...])
        if let startOfString = try parseStartOfStringAnchor() {
            node.add(startOfString)
        }
        node.add(try parseExpression())

        guard scanner.peak() == nil else {
            throw Regex.Error("Unmatched closing parentheses", i)
        }

        os_log(.default, log: self.log, "AST: \n%{PUBLIC}@", Node.recursiveDescription(node))

        return node
    }
}

private extension Parser {

    // MARK: Options

    func parseStartOfStringAnchor() throws -> ASTNode? {
        guard let substring = scanner.read("^") else { return nil }
        return ASTNode(ASTUnit.Anchor.startOfString, substring)
    }

    // MARK: Expressions

    func parseExpression() throws -> ASTNode {
        let start = scanner.read()
        scanner.undoRead() // TODO: fix this

        var children: [[ASTNode]] = [[]] // Each array represents an alternation

        func add(_ node: ASTNode) {
            children[children.endIndex-1].append(node)
        }

        // Appplies quantifier to the last expression.
        func apply(_ quantifier: ASTNode) throws {
            guard let last = children[children.endIndex-1].popLast() else {
                throw Regex.Error("The preceeding token is not quantifiable", i)
            }
            quantifier.children = [last] // Apply quantifier to the last expression
            add(quantifier)
        }

        while let c = scanner.peak(), c != ")" {
            switch c {
            case "(": add(try parseGroup())
            case "|":
                scanner.read() // Consume '|'
                children.append([]) // Start a new expression
            case "*", "+", "?", "{":
                try apply(try parseQuantifier())
            case ".":
                let unit = ASTUnit.Match.anyCharacter(includingNewline: options.contains(.dotMatchesLineSeparators))
                add(ASTNode(unit, scanner.read()))
            case "\\": add(try parseEscapedCharacter())
            case "[": // Start a character group
                let (set, substring) = try scanner.readCharacterSet()
                add(ASTNode(ASTUnit.Match.characterSet(set), substring))
            case "$":
                add(ASTNode(ASTUnit.Anchor.endOfString, scanner.read()))

            default:
                let character = ASTUnit.Match.character(c)
                add(ASTNode(character, scanner.read()))
            }
        }

        // TODO: fix
        scanner.undoRead()
        let end = scanner.read()

        let expressions = try children.map(expression)
        if expressions.count > 1 {
            return ASTNode(ASTUnit.Alternation(), source(start, end), expressions)
        } else {
            // TODO: handle situation where there are no expression property
            return expressions[0]
        }
    }

    /// Creates an node which represents an expression. If there is only one
    /// child, returns a child itself to avoid additional overhead.
    func expression(_ children: [ASTNode]) throws -> ASTNode {
        switch children.count {
        case 0: throw Regex.Error("A side of an alternation is empty", i)
        case 1: return children[0]
        default: return ASTNode(ASTUnit.Expression(), source(children.first!, children.last!), children)
        }
    }

    // MARK: Groups

    func parseGroup() throws -> ASTNode {
        let start = try scanner.read("(", orThrow: "Unmatched closing parantheses")
        let isCapturing = scanner.read("?:") == nil
        let group = ASTUnit.Group(index: nextGroupIndex, isCapturing: isCapturing)
        let expression = try parseExpression()
        let end = try scanner.read(")", orThrow: "Unmatched opening parentheses")
        return ASTNode(group, source(start, end), [expression])
    }

    // MARK: Quantifiers

    func parseQuantifier() throws -> ASTNode {
        switch scanner.peak()! {
        case "*": return ASTNode(ASTUnit.Quantifier.zeroOrMore, scanner.read())
        case "+": return ASTNode(ASTUnit.Quantifier.oneOrMore, scanner.read())
        case "?": return ASTNode(ASTUnit.Quantifier.zeroOrOne, scanner.read())
        case "{": return try parseRangeQuantifier()
        default: fatalError("Invalid token")
        }
    }

    func parseRangeQuantifier() throws -> ASTNode {
        // TODO: cleanup
        let start = scanner.read()
        scanner.undoRead()

        let range = try scanner.readRangeQuantifier()
        scanner.undoRead()
        let end = scanner.read()

        return ASTNode(ASTUnit.Quantifier.range(range), source(start, end))
    }

    // MARK: Character Escapes

    func parseEscapedCharacter() throws -> ASTNode {
        let backslash = scanner.read() // Consume escape

        guard let c = scanner.peak() else {
            throw Regex.Error("Pattern may not end with a trailing backslash", i)
        }

        if let (substring, index) = scanner.readInteger() {
            return ASTNode(ASTUnit.Backreference(index: index), source(backslash, substring))
        }

        if let node = parseSpecialCharacter(c) {
            return node
        }

        // TODO: pass proper substring and remove these workarounds
        scanner.read()
        if let set = try scanner.readCharacterClassSpecialCharacter(c) {
            return ASTNode(ASTUnit.Match.characterSet(set), backslash)
        }
        scanner.undoRead()

        return ASTNode(ASTUnit.Match.character(c), source(backslash, scanner.read()))
    }

    func parseSpecialCharacter(_ c: Character) -> ASTNode? {
        func anchor(for c: Character) -> ASTUnit.Anchor? {
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

        guard let anchor = anchor(for: c) else {
            return nil
        }

        // TODO: pass proper substring
        return ASTNode(anchor, scanner.read())
    }

    // MARK: Helpers (Pattern)

    func source(_ from: ASTNode, _ to: ASTNode) -> Substring {
        return source(from.value.source, to.value.source)
    }

    /// Combine everything between two substring.s
    func source(_ from: Substring, _ to: Substring) -> Substring {
        return pattern[from.startIndex..<to.endIndex]
    }

    /// Returns the index of the character which is currently being processed.
    var i: Int {
        return scanner.i - 1
    }
}
