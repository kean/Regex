// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

// MARK: - AST (Protocols)

/// An AST unit, marker protocol.
protocol Unit: Traceable {}

/// A terminal unit, can't contain other units (subexpressions).
protocol Terminal: Unit {}

/// An AST unit consisting of multiple units.
protocol Composite: Unit {
    var children: [Unit] { get }
}

// TODO: remove Traceable and simplify the AST structure.
/// Can be traced backed to the source in the pattern.
protocol Traceable {
    var source: Range<Int> { get }
}

// MARK: - AST (Components)

#warning("rename?")
struct AST {
    let root: Unit
    let isFromStartOfString: Bool
    let pattern: String
}

struct Expression: Composite {
    let children: [Unit]
    let source: Range<Int>
}

// "(ab)"
struct Group: Composite {
    let index: Int?
    let isCapturing: Bool
    let children: [Unit]
    let source: Range<Int>
}

// "a|bc"
struct Alternation: Composite {
    let children: [Unit]
    let source: Range<Int>
}

// "(a)\1"
struct Backreference: Terminal {
    let index: Int
    let source: Range<Int>
}

// "\b", "\G" etc
enum Anchor: Terminal {
    case startOfString
    case endOfString
    case wordBoundary
    case nonWordBoundary
    case startOfStringOnly
    case endOfStringOnly
    case endOfStringOnlyNotNewline
    case previousMatchEnd

    var source: Range<Int> { 0..<0 }
}

struct Match: Terminal {
    let type: MatchType
    let source: Range<Int>
}

enum MatchType {
    case character(Character)
    case string(String)
    case anyCharacter
    case set(CharacterSet)
    case group(CharacterGroup)
}

struct CharacterGroup: Terminal {
    let isInverted: Bool
    let items: [Item]

    var source: Range<Int> { 0..<0 }

    enum Item: Equatable {
        case character(Character)
        case range(ClosedRange<Unicode.Scalar>)
        case set(CharacterSet)
    }
}

struct QuantifiedExpression: Composite {
    let quantifier: Quantifier
    let expression: Unit
    let source: Range<Int>

    var children: [Unit] { return [expression] }
}

struct Quantifier: Equatable {
    let type: QuantifierType
    let isLazy: Bool
}

// "a*", "a?", etc
enum QuantifierType: Equatable {
    case zeroOrMore
    case oneOrMore
    case zeroOrOne
    case range(RangeQuantifier)
}

struct RangeQuantifier: Equatable {
    let lowerBound: Int
    let upperBound: Int?
}

// MARK: - AST (Description)

extension Expression: CustomStringConvertible {
    var description: String {
        return "Expression"
    }
}

extension Match: CustomStringConvertible {
    var description: String {
        switch type {
        case let .character(character): return "Character(\"\(character)\")"
        case let .string(string): return "String(\"\(string)\")"
        case .anyCharacter: return  "AnyCharacter"
        case let .set(set): return "CharacterSet(\(set))"
        case let .group(group): return "\(group)"
        }
    }
}

extension CharacterGroup {
    var description: String {
        return "CharacterGroup(isInverted: \(isInverted), items: \(items))"
    }
}

extension Group: CustomStringConvertible {
    var description: String {
        // TODO: improve description
        return "Group(index: \(String(describing: index)), isCapturing: \(isCapturing)"
    }
}

extension Alternation: CustomStringConvertible {
    var description: String {
        return "Alternation"
    }
}

extension Anchor: CustomStringConvertible {
    var description: String {
        return "Anchor.\(self)"
    }
}

extension Backreference: CustomStringConvertible {
    var description: String {
        return "Backreference(index: \(index))"
    }
}

extension QuantifiedExpression: CustomStringConvertible {
    var description: String {
        return "Quantifier.\(quantifier.type)" + (quantifier.isLazy ? "(isLazy: true)" : "")
    }
}

extension AST: CustomStringConvertible {
    /// Returns a nicely formatted description of the unit.
    var description: String {
        var output = ""
        visit(root, 0) { unit, level in
            let s = String(repeating: " ", count: level * 2) + "– " + description(for: unit)
            output.append(s)
            output.append("\n")
        }
        return output
    }

    func description(for unit: Unit) -> String {
        return "\(unit)" + " [\"\(pattern.substring(unit.source))\", \(unit.source)]"
    }

    func printRecursiveDescription() {
        print(description)
    }
}

// MARK: - AST (Visitor)

extension AST {
    /// Recursively visits all nodes.
    func visit(_ closure: (Unit) -> Void) {
        visit(root, 0) { unit, _ in closure(unit) }
    }

    /// Recursively visits all nodes.
    private func visit(_ unit: Unit, _ level: Int, _ closure: (Unit, Int) -> Void) {
        closure(unit, level)
        if let children = (unit as? Composite)?.children {
            for child in children {
                visit(child, level + 1, closure)
            }
        }
    }
}
