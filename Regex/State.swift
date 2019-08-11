// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

// MARK: - State

/// Represents a state of the finite state machine.
final class State: Hashable, CustomStringConvertible {
    /// Additional information about the expression (or part of the expression)
    /// represented by the current state.
    var info: ExpressionInfo?

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

// MARK: - Transition

/// A transition between two states of the state machine.
struct Transition: CustomStringConvertible {
    /// A state into which the transition is performed.
    let toState: State

    /// Determines whether the transition is possible in the given context.
    /// Returns `nil` if not possible, otherwise returns number of elements to consume.
    let condition: (Cursor, Context) -> Int?

    /// Adds a chance for transition to update update current state.
    let perform: (Cursor, Context) -> (Context)

    // MARK: Factory

    /// Creates a transition which consumes a character.
    static func consuming(_ toState: State, _ match: @escaping (Character) -> Bool) -> Transition {
        return Transition(
            toState: toState,
            condition: { cursor, _ in
                guard let character = cursor.character else {
                    return nil
                }
                guard match(character) else {
                    return nil
                }
                return 1 // Consume one character
            }, perform: { _, context in context }
        )
    }

    /// Creates a transition which doesn't consume characters.
    /// - parameter perform: A closure to be performed every time a
    /// transition is performed. Allows you to map state (context). By default
    /// returns context without modification.
    static func epsilon(_ toState: State,
                        perform: @escaping (Cursor, Context) -> Context = { _, context in context },
                        _ condition: @escaping (Cursor, Context) -> Bool = { _, _ in true }) -> Transition {
        return Transition(toState: toState, condition: { cursor, context in
            return condition(cursor, context) ? 0 : nil
        }, perform: perform)
    }

    // MARK: CustomStringConvertible

    var description: String {
        return "Transition to \(toState)"
    }
}

/// Execution context which is passed from state to state when transitions are
/// performed. The context is copied throughout the execution making the execution
/// functional/stateless.
/// - warning: Avoid using reference types in context!
typealias Context = [AnyHashable: AnyHashable]
