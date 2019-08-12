// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

// MARK: - State

/// Represents a state of the finite state machine.
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

// MARK: - Transition

/// A transition between two states of the state machine.
struct Transition: CustomStringConvertible {
    /// A state into which the transition is performed.
    let toState: State

    /// Determines whether the transition is possible in the given context.
    /// Returns `nil` if not possible, otherwise returns number of elements to consume.
    let condition: (Cursor) -> Int?

    // MARK: Factory

    /// Creates a transition which consumes a character.
    static func consuming(_ toState: State, _ match: @escaping (Character) -> Bool) -> Transition {
        return Transition(
            toState: toState,
            condition: { cursor in
                guard let character = cursor.character else {
                    return nil
                }
                guard match(character) else {
                    return nil
                }
                return 1 // Consume one character
            }
        )
    }

    /// Creates a transition which doesn't consume characters.
    static func epsilon(_ toState: State, _ condition: @escaping (Cursor) -> Bool = { _ in true }) -> Transition {
        return Transition(toState: toState, condition: { condition($0) ? 0 : nil })
    }

    // MARK: CustomStringConvertible

    var description: String {
        return "Transition to \(toState)"
    }
}
