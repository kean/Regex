// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

// MARK: - Automation

/// State represents a regex pattern compiled into a non-deterministic finite
/// automation.
final class State: Hashable, CustomStringConvertible {
    var isEnd: Bool {
        return transitions.isEmpty
    }
    var transitions = [Transition]()

    init(_ description: String) {
        self.description = description
    }

    // MARK: Hashable

    func hash(into hasher: inout Hasher) {
        ObjectIdentifier(self).hash(into: &hasher)
    }

    static func == (lhs: State, rhs: State) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }

    // MARK: CustomStringConvertible

    let description: String
}

/// A finite state machine is represented by a start and an end state and by
/// possible transitions between them which might also include other intermediate
/// states.
///
/// In the scope of Regex, `Machine` is used to represent a regular expression.
struct Machine: CustomStringConvertible {
    let id: Int
    let start: State
    let end: State

    init(_ description: String) {
        self.id = Machine.makeNextId()
        self.start = State("{ #\(id) Start – \(description) }")
        self.end = State("{ #\(id) End }")
    }

    init(start: State, end: State) {
        self.id = Machine.makeNextId()
        self.start = start
        self.end = end
    }

    /// Automatically sets up a single consuming transition from start to end
    /// with the given condition.
    init(_ description: String, condition: @escaping (Character) -> Bool) {
        self = Machine(description)
        start.transitions = [.consuming(end, condition)]
    }

    var description: String {
        var states = [String]()

        // Go throught the graph of states and print them all.
        var encountered = Set<State>()
        var queue = [State]()
        queue.append(start)
        encountered.insert(start)

        while !queue.isEmpty {
            let state = queue.removeFirst() // This isn't fast
            let transitions = state.transitions
                .map { "  – \($0)" }
                .joined(separator: "\n")
            states.append("\(state) \n\(transitions)\n")

            for neighboor in state.transitions.map({ $0.toState })
                where !encountered.contains(neighboor) {
                    queue.append(neighboor)
                    encountered.insert(neighboor)
            }
        }

        return states.joined(separator: "\n")
    }

    static var nextId: Int = 0

    static func makeNextId() -> Int {
        defer { nextId += 1 }
        return nextId
    }
}

/// Execution context which is passed from state to state when transitions are
/// performed. The context is copied throughout the execution making the execution
/// functional/stateless.
/// - warning: Avoid using reference types in context!
typealias Context = [AnyHashable: AnyHashable]

/// A transition between two states.
struct Transition: CustomStringConvertible {
    let toState: State
    /// If true, transition doesn't consume a character when performed.
    let isEpsilon: Bool
    let condition: (Cursor, Context) -> Bool
    let perform: (Context) -> (Context)

    // MARK: Factory

    static func consuming(_ toState: State, _ match: @escaping (Character) -> Bool) -> Transition {
        return Transition(
            toState: toState,
            isEpsilon: false,
            condition: { cursor, _ in
                guard let character = cursor.character else {
                    return false
                }
                return match(character)
            }, perform: { $0 }
        )
    }

    /// - parameter perform: A closure to be performed every time a
    /// transition is performed. Allows you to map state (context). By default
    /// returns context without modification.
    static func epsilon(_ toState: State,
                        perform: @escaping (Context) -> Context = { $0 },
                        _ condition: @escaping (Cursor, Context) -> Bool = { _, _ in true }) -> Transition {
        return Transition(toState: toState, isEpsilon: true, condition: condition, perform: perform)
    }

    var description: String {
        return "\(isEpsilon ? "Epsilon" : "Transition") to \(toState)"
    }
}

// MARK: - Machine (Character Classes)

extension Machine {
    /// Matches the given character.
    static func character(_ c: Character) -> Machine {
        return Machine("Match character '\(c)'") { $0 == c }
    }

    /// Matches the given character set.
    static func characterSet(_ set: CharacterSet) -> Machine {
        return Machine("Match set \(set)") { set.contains($0) }
    }

    /// Matches any character.
    static func anyCharacter(includingNewline: Bool) -> Machine {
        return Machine("Match any character") { includingNewline ? true : $0 != "\n" }
    }
}

// MARK: - Machine (Quantifiers)

extension Machine {
    /// Matches the given regex zero or more times.
    static func zeroOrMore(_ machine: Machine) -> Machine {
        let quantifier = Machine("Zero or more")
        quantifier.start.transitions = [
            .epsilon(machine.start), // Loop (greedy by default)
            .epsilon(quantifier.end) // Skip
        ]
        machine.end.transitions = [
            .epsilon(quantifier.start) // Loop
        ]
        return quantifier
    }

    /// Matches the given regex one or more times.
    static func oneOrMore(_ machine: Machine) -> Machine {
        let quantifier = Machine("One or more")
        quantifier.start.transitions = [
            .epsilon(machine.start) // Execute at least once
        ]
        machine.end.transitions = [
            .epsilon(quantifier.start), // Loop
            .epsilon(quantifier.end) // Complete
        ]
        return quantifier
    }

    /// Matches the given regex either none or one time.
    static func noneOrOne(_ machine: Machine) -> Machine {
        let quantifier = Machine("None or one")
        quantifier.start.transitions = [
            .epsilon(machine.start), // Loop (greedy by default)
            .epsilon(quantifier.end) // Skip
        ]
        machine.end.transitions = [
            .epsilon(quantifier.end), // Complete
        ]
        return quantifier
    }

    /// Matches the given regex the given number of times. E.g. if you pass
    /// the range {2,3} it will match the regex either 2 or 3 times.
    static func range(_ range: ClosedRange<Int>, _ machine: Machine) -> Machine {
        let quantifier = Machine("Range \(range)")

        // The machine requires a bit of additional state which we implement
        // using context.
        let uuid = UUID()

        quantifier.start.transitions = [
            .epsilon(machine.start, perform: {
                // Increment the number of times we passed throught this transition
                // during the current execution of the state machine
                var context = $0
                let count = (context[uuid] as? Int) ?? 0
                context[uuid] = count + 1
                return context
            })
        ]

        machine.end.transitions = [
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

// MARK: - Machine (Anchors)

extension Machine {
    /// Matches the start of the string.
    static var startOfString: Machine {
        return anchor("Start of string") { cursor, _ in cursor.index == 0 }
    }

    /// Matches the end of the string.
    static var endOfString: Machine {
        return anchor("End of string") { cursor, _ in cursor.isEmpty}
    }

    /// Matches not the end of the string.
    static var notEndOfString: Machine {
        return anchor("End of string") { cursor, _ in !cursor.isEmpty}
    }

    /// The match must occur on a word boundary.
    static var wordBoundary: Machine {
        return anchor("Word boundary") { cursor, _ in cursor.isAtWordBoundary }
    }

    /// The match must occur on a non-word boundary.
    static var nonWordBoundary: Machine {
        return anchor("Non word boundary") { cursor, _ in !cursor.isAtWordBoundary }
    }

    private static func anchor(_ description: String, _ condition: @escaping (Cursor, Context) -> Bool) -> Machine {
        let machine = Machine(description)
        machine.start.transitions += [
            .epsilon(machine.end, condition)
        ]
        return machine
    }
}

private extension Cursor {
    var isAtWordBoundary: Bool {
        guard let cur = character else {
            return true // Already reached the end of the string
        }
        let lhs = character(offsetBy: -1) ?? " "
        let rhs = character(offsetBy: 1) ?? " "

        if cur.isWord {
            return !lhs.isWord
        } else {
            return lhs.isWord || rhs.isWord
        }
    }
}

// MARK: - Machine (Operations)

extension Machine {

    static func concatenate<S>(_ machines: S) -> Machine
        where S: Collection, S.Element == Machine {
            return machines.dropFirst().reduce(machines.first!, Machine.concatenate)
    }

    static func concatenate(_ lhs: Machine, _ rhs: Machine) -> Machine {
        precondition(lhs.end.transitions.isEmpty, "Invalid state of \(lhs)")
        precondition(rhs.end.transitions.isEmpty, "Invalid state of \(rhs)")

        lhs.end.transitions = [.epsilon(rhs.start)]
        return Machine(start: lhs.start, end: rhs.end)
    }

    static func alternate<S>(_ machines: S) -> Machine
        where S: Sequence, S.Element == Machine {
            let alternation = Machine("Alternate")

            for machine in machines {
                precondition(machine.end.transitions.isEmpty, "Invalid state of \(machine)")

                alternation.start.transitions.append(.epsilon(machine.start))
                machine.end.transitions = [.epsilon(alternation.end)]
            }

            return alternation
    }

    static func alternate(_ lhs: Machine, _ rhs: Machine) -> Machine {
        return alternate([lhs, rhs])
    }
}
