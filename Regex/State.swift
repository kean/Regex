// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

// MARK: - State

/// Represents a state of the finite state machine.
final class State: Hashable, CustomStringConvertible {
    var transitions = [Transition]()

    var isEnd: Bool {
        return transitions.isEmpty
    }

    init() {}

    // MARK: Hashable

    func hash(into hasher: inout Hasher) {
        ObjectIdentifier(self).hash(into: &hasher)
    }

    static func == (lhs: State, rhs: State) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }

    // MARK: CustomStringConvertible

    var description: String {
        return "State(\(Unmanaged.passUnretained(self).toOpaque()))"
            .replacingOccurrences(of: "0000", with: "")
    }
}

// MARK: - Transition

/// A transition between two states of the state machine.
struct Transition {
    /// A state into which the transition is performed.
    let toState: State

    /// Determines whether the transition is possible in the given context.
    /// Returns `nil` if not possible, otherwise returns number of elements to consume.
    let condition: (Cursor) -> Int?

    init(_ toState: State, _ condition: @escaping (Cursor) -> Int?) {
        self.toState = toState
        self.condition = condition
    }

    /// Creates a transition which doesn't consume characters.
    static func epsilon(_ toState: State, _ condition: @escaping (Cursor) -> Bool = { _ in true }) -> Transition {
        return Transition(toState) { condition($0) ? 0 : nil }
    }
}
