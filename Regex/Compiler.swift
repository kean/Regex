// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

/// Compiles a pattern into a finite state machine.
final class Compiler {
    private let parser: Parser
    private let options: Regex.Options

    /// A stack of machines, each machine represents a single expression.
    private var stack = [StackEntry]()

    init(_ pattern: String, _ options: Regex.Options) {
        self.parser = Parser(Array(pattern))
        self.options = options
    }

    private let keywords: Set<Character> = Set(["(", ")", "|", "*", "+", "?", "{", "}", ".", "[", "]", "\\", "/"])

    func compile() throws -> Machine {
        Machine.nextId = 0 // Id are used for logging

        let shouldMatchStart = parser.read("^")
        let shouldMatchEnd = parser.readFromEnd("$")

        if shouldMatchStart {
            stack.append(.machine(.startOfString))
        }

        while let c = parser.readCharacter() {
            switch c {
            // Grouping
            case "(":
                stack.append(.group(index: i))
            case ")":
                try collapseLastGroup()

            // Alternation
            case "|":
                stack.append(.alternate)

            // Quantifiers
            case "*": // Zero or more
                try addQuantifierForLastMachine(Machine.zeroOrMore)
            case "+": // One or more
                try addQuantifierForLastMachine(Machine.oneOrMore)
            case "?": // Zero or one
                try addQuantifierForLastMachine(Machine.noneOrOne)
            case "{": // Match N times
                try addQuantifierForLastMachine {
                    Machine.range(try parser.readRangeQuantifier(), $0)
                }

            // Character Classes
            case ".": // Any character
                stack.append(.machine(.anyCharacter(includingNewline: options.contains(.dotMatchesLineSeparators))))
            case "[": // Start a character group
                let set = try parser.readCharacterSet()
                stack.append(.machine(.characterSet(set)))

            // Character Escapes
            case "\\":
                let machine = try compilerCharacterAfterEscape()
                stack.append(.machine(machine))

            default: // Not a keyword, treat as a plain character
                stack.append(.machine(.character(c)))
            }
        }

        if shouldMatchEnd {
            stack.append(.machine(.endOfString))
        }

        let regex = try collapse() // Collapse on regexes in an implicit top group

        guard stack.isEmpty else {
            if case let .group(index)? = stack.last {
                throw Regex.Error("Unmatched opening parentheses", index)
            } else {
                fatalError("Unsupported error")
            }
        }

        return regex
    }

    func compilerCharacterAfterEscape() throws -> Machine {
        guard let c = parser.readCharacter() else {
            throw Regex.Error("Pattern may not end with a trailing backslash", i)
        }
        switch c {
        case "b": return .wordBoundary
        case "B": return .nonWordBoundary
        case "z": return .endOfString
        default:
            guard let machine = compileSpecialCharacter(c) else {
                throw Regex.Error("Invalid special character '\(c)'", i)
            }
            return machine
        }
    }

    func compileSpecialCharacter(_ c: Character) -> Machine? {
        if keywords.contains(c) {
            return .character(c)
        }
        if let set = parser.parseSpecialCharacter(c) {
            return .characterSet(set)
        }
        return nil
    }

    /// Returns the index of the character which is currently being processed.
    var i: Int {
        return parser.i - 1
    }

    // MARK: Managing Machines

    func popMachine() throws -> Machine {
        guard case let .machine(machine)? = stack.popLast() else {
            throw Regex.Error("Failed to find a matching group", i)
        }
        return machine
    }

    /// Map the last machine in the last group.
    func addQuantifierForLastMachine(_ closure: (Machine) throws -> Machine) throws {
        let last: Machine
        do {
            last = try popMachine()
        } catch {
            throw Regex.Error("The preceeding token is not quantifiable", i)
        }
        stack.append(.machine(try closure(last)))
    }

    // MARK: Managing Machines (Grouping)

    func collapseLastGroup() throws {
        let group = try collapse()
        guard case .group? = stack.popLast() else {
            throw Regex.Error("Unmatched closing parentheses", i)
        }
        stack.append(.machine(group))
    }

    /// Collapses the items in the top group. Also collapses alternations in the
    /// top group. Returns a single regex (machine).
    func collapse() throws -> Machine {
        var alternatives = [Machine]()

        var stop = false
        while !stop {
            stop = true
            var machines = [Machine]()
            while case let .machine(machine)? = stack.last {
                stack.removeLast()
                machines.append(machine)
            }
            alternatives.append(.concatenate(machines.reversed()))

            if case .alternate? = stack.last {
                stack.removeLast()
                stop = false
            }
        }

        guard alternatives.count > 1 else {
            return alternatives[0] // Must have at least one
        }

        return Machine.alternate(alternatives)
    }
}

// MARK: - Stack

private enum StackEntry {
    case machine(Machine)
    case group(index: Int) // (
    case alternate // |
}
