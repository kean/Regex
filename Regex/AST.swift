// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

// MARK: ASTUnit

/// Marker protocol.
protocol ASTUnitProtocol {}

/// Represents all possible regular expression language constructs.
enum ASTUnit {
    /// The root of the expression.
    struct Root: ASTUnitProtocol {}

    /// Anonymous group.
    struct Expression: ASTUnitProtocol {}

    struct Group: ASTUnitProtocol {
        let index: Int
        let isCapturing: Bool
    }

    struct Backreference: ASTUnitProtocol {
        let index: Int
    }

    struct Alternation: ASTUnitProtocol {}

    enum Anchor: ASTUnitProtocol {
        case startOfString
        case endOfString
        case wordBoundary
        case nonWordBoundary
        case startOfStringOnly
        case endOfStringOnly
        case endOfStringOnlyNotNewline
        case previousMatchEnd
    }

    enum Match: ASTUnitProtocol {
        case character(Character)
        case anyCharacter(includingNewline: Bool)
        case characterSet(CharacterSet)
    }

    enum Quantifier: ASTUnitProtocol {
        case zeroOrMore
        case oneOrMore
        case zeroOrOne
        case range(ClosedRange<Int>)
    }
}

// MARK: - ASTValue

/// A value stored in AST nodes, wraps a unit.
struct ASTValue: CustomStringConvertible {
    let unit: ASTUnitProtocol

    /// The part of the pattern which represents the given unit.
    var source: Substring

    init(_ unit: ASTUnitProtocol, _ source: Substring) {
        self.unit = unit
        self.source = source
    }

    var description: String {
        return "\(unit), source: \"\(source)\" \(source.startIndex.encodedOffset):\(source.count)"
    }
}

// MARK: - Node (Tree)

/// A simple generic Tree implemenation.
final class Node<T> {
    var value: T
    var children: [Node<T>]

    init(_ value: T, _ children: [Node<T>] = []) {
        self.value = value
        self.children = children
    }

    func add(_ child: Node<T>) {
        children.append(child)
    }

    /// Adds a child node with the given value.
    @discardableResult
    func add(_ value: T) -> Node<T> {
        let node = Node(value)
        add(node)
        return node
    }
}

// MARK: - Node (Extensions)

extension Node {
    /// Recursively visits all nodes.
    func visit(_ closure: (Node) -> Void) {
        visit(0) { node, _ in closure(node) }
    }

    /// Recursively visits all nodes.
    private func visit(_ level: Int = 0, _ closure: (Node, Int) -> Void) {
        closure(self, level)
        for child in children {
            child.visit(level + 1, closure)
        }
    }

    static func recursiveDescription(_ node: Node) -> String {
        var description = ""
        node.visit { node, level in
            let s = String(repeating: " ", count: level * 2) + "– \(node.value)"
            description.append(s)
            description.append("\n")
        }
        return description
    }
}

// MARK: - ASTNode

typealias ASTNode = Node<ASTValue>

extension Node where T == ASTValue {

    var isAlternation: Bool {
        return unit is ASTUnit.Alternation
    }

    var unit: ASTUnitProtocol {
        return value.unit
    }

    convenience init(_ unit: ASTUnitProtocol, _ source: Substring, _ children: [ASTNode] = []) {
        self.init(ASTValue(unit, source), children)
    }
}
