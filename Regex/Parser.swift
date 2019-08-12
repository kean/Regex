// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

// MARK: - Parser

final class Parser {
    private let pattern: String
    private let scanner: Scanner
    private var groupIndex = 1
    private let options: Regex.Options
    private var node: ASTNode

    init(_ pattern: String, _ options: Regex.Options) {
        self.pattern = pattern
        self.scanner = Scanner(pattern)
        self.options = options
        self.node = ASTNode(ASTUnit.Root(), pattern[...])
    }

    /// Scans and analyzes the pattern and creats an abstract syntax tree.
    func parse() throws -> ASTNode {
        if let substring = scanner.read("^") {
            add(ASTUnit.Anchor.startOfString, substring)
        }

        while let c = scanner.peak() {
            switch c {
            // Grouping
            case "(":
               openGroup()
            case ")":
                try closeGroup()

            // Alternation
            case "|":
                try addAlternation()

            // Quantifiers
            case "*": // Zero or more
                try addQuantifier(.zeroOrMore, scanner.read())
            case "+": // One or more
                try addQuantifier(.oneOrMore, scanner.read())
            case "?": // Zero or one
                try addQuantifier(.zeroOrOne, scanner.read())
            case "{": // Match N times
                try addRangeQuantifier()

            // Character classes
            case ".": // Any character
                let unit = ASTUnit.Match.anyCharacter(includingNewline: options.contains(.dotMatchesLineSeparators))
                add(unit, scanner.read())
            case "[": // Start a character group
                let (set, substring) = try scanner.readCharacterSet()
                add(ASTUnit.Match.characterSet(set), substring)

            // Character Escapes
            case "\\":
                try parseEscapedCharacter()

            // Anchors
            case "$":
                add(ASTUnit.Anchor.endOfString, scanner.read())

            // A regular character
            default:
                add(ASTUnit.Match.character(c), scanner.read())
            }
        }

        if let node = node.children.first, node.isAlternation {
            try closeAlternation()
        }

        guard node.unit is ASTUnit.Root else {
            throw Regex.Error("Unmatched opening parentheses", i)
        }

        return node
    }

    // MARK: Character Escapes

    private func parseEscapedCharacter() throws {
        let backslash = scanner.read() // Consume escape

        guard let c = scanner.peak() else {
            throw Regex.Error("Pattern may not end with a trailing backslash", i)
        }

        if let (substring, index) = scanner.readInteger() {
            add(ASTUnit.Backreference(index: index), source(from: backslash, to: substring))
            return
        }

        if parseSpecialCharacter(c) {
            return
        }

        // TODO: pass proper substring and remove these workarounds
        scanner.read()
        if let set = try scanner.readCharacterClassSpecialCharacter(c) {
            add(ASTUnit.Match.characterSet(set), backslash)
            return
        }
        scanner.undoRead()

        add(ASTUnit.Match.character(c), source(from: backslash, to: scanner.read()))
    }

    private func parseSpecialCharacter(_ c: Character) -> Bool {
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
            return false
        }

        // TODO: pass proper substring
        add(anchor, scanner.read())
        return true
    }

    // MARK: Groups

    private func openGroup() {
        let bracket = scanner.read()
        let isCapturing = scanner.read("?:") == nil
        let unit = ASTUnit.Group(index: groupIndex, isCapturing: isCapturing)
        groupIndex += 1
        let node = add(unit, bracket)
        node.parent = self.node
        self.node = node
    }

    private func closeGroup() throws {
        guard node.value.unit is ASTUnit.Group else {
            throw Regex.Error("Unmatched closing parentheses", i)
        }
        if let node = node.children.first, node.isAlternation {
            try closeAlternation()
        }
        let substring = scanner.read()
        node.value.source = pattern[node.value.source.startIndex..<substring.endIndex]
        assert(node.parent != nil, "Group node is missing parent")
        self.node = node.parent!
    }

    // MARK: Alternations

    private func addAlternation() throws {
        scanner.read() // Consume `|`

        if let node = node.children.first, node.isAlternation {
            // Alternation already started, close the existing group
            try closeAlternation()
        } else {
            try openAlternation()
        }
    }

    private func openAlternation() throws {
        let group = makeGroup(node.children, node)
        node.children.removeAll()

        let alternation = ASTNode(ASTUnit.Alternation(), group.value.source.dropFirst())
        alternation.children = [group]
        self.node.add(alternation)
    }

    private func closeAlternation() throws {
        guard let alternation = node.children.first, alternation.isAlternation else {
            throw Regex.Error("Unexpected error", i)
        }

        let group = makeGroup(Array(node.children.dropFirst()), node)
        node.children.removeLast(node.children.count-1) // Removes everything except the existing alternation

        alternation.children.append(group)
        alternation.value.source = source(from: alternation, to: group)
    }

    /// Wraps nodes into an anonymous group.
    private func makeGroup(_ nodes: [ASTNode], _ parent: ASTNode) -> ASTNode {
        guard !nodes.isEmpty else {
            return ASTNode(ASTUnit.Expression(), parent.value.source.dropFirst())
        }

        let source = self.source(from: nodes.first!, to: nodes.last!)
        let node = ASTNode(ASTUnit.Expression(), source)
        node.children = nodes
        return node
    }

    // MARK: Quantifiers

    private func addQuantifier(_ quantifier: ASTUnit.Quantifier, _ substring: Substring) throws {
        // TODO: do we need to perform some validations?
        // TODO: do we need to pass the entire entity that we apply quantifier to?
        guard let last = node.children.popLast() else {
            throw Regex.Error("The preceeding token is not quantifiable", i+1)
        }
        let quantifier = ASTNode(quantifier, substring)
        quantifier.children = [last] // Apply quantifier to the last expression
        self.node.children.append(quantifier)
    }

    private func addRangeQuantifier() throws {
        let range = try scanner.readRangeQuantifier()
        // TODO: cleanup
        scanner.undoRead()
        let substring = scanner.read()
        try addQuantifier(.range(range), substring)
    }

    // MARK: Helpers (Nodes)

    /// Adds a unit to the current node.
    @discardableResult
    private func add(_ unit: ASTUnitProtocol, _ substring: Substring) -> ASTNode {
        return self.node.add(ASTValue(unit, substring))
    }

    // MARK: Helpers (Pattern)

    private func source(from: ASTNode, to: ASTNode) -> Substring {
        return source(from: from.value.source, to: to.value.source)
    }

    /// Combine everything between two substring.s
    private func source(from: Substring, to: Substring) -> Substring {
        return pattern[from.startIndex..<to.endIndex]
    }

    /// Returns the index of the character which is currently being processed.
    private var i: Int {
        return scanner.i - 1
    }
}
