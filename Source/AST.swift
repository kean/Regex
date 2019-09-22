// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

// MARK: - AST (Protocols)

/// An AST unit, marker protocol.
protocol Unit {}

/// An AST unit consisting of multiple units.
protocol Composite {
    var children: [Unit] { get }
}

// MARK: - AST (Components)

struct AST {
    let isFromStartOfString: Bool
    let root: Unit
}

// "(ab)"
struct Group: Unit, Composite {
    let index: Int?
    let isCapturing: Bool
    let children: [Unit]
}

struct ImplicitGroup: Unit, Composite {
    let children: [Unit]
}

// "a|bc"
struct Alternation: Unit, Composite {
    let children: [Unit]
}

// "(a)\1"
struct Backreference: Unit {
    let index: Int
}

// "\b", "\G" etc
enum Anchor: String, Unit {
    case startOfString
    case endOfString
    case wordBoundary
    case nonWordBoundary
    case startOfStringOnly
    case endOfStringOnly
    case endOfStringOnlyNotNewline
    case previousMatchEnd
}

enum Match: Unit {
    case anyCharacter
    case character(Character)
    case string(String)
    case set(CharacterSet)
    case group(CharacterGroup)
}

struct CharacterGroup: Unit {
    let isInverted: Bool
    let items: [Item]

    enum Item: Equatable {
        case character(Character)
        case range(ClosedRange<Unicode.Scalar>)
        case set(CharacterSet)
    }
}

struct QuantifiedExpression: Unit, Composite {
    let expression: Unit
    let quantifier: Quantifier

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

extension ImplicitGroup: CustomStringConvertible {
    var description: String {
        return "Expression"
    }
}

extension Match: CustomStringConvertible {
    var description: String {
        switch self {
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
        return "Anchor.\(rawValue)"
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
        return "\(unit)" // TODO: print part of the original pattern
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
