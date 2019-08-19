// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

// MARK: - State

/// Represents a state of the finite state machine.
final class State: Hashable, CustomStringConvertible {
    var transitions = [Transition]()

    var id: StateId = 0

    var isEnd: Bool {
        return transitions.isEmpty
    }

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

typealias StateId = Int

// MARK: - Transition

/// A transition between two states of the state machine.
struct Transition {
    /// A state into which the transition is performed.
    let end: State

    /// Determines whether the transition is possible in the given context.
    /// Returns `nil` if not possible, otherwise returns number of elements to consume.
    let condition: (Cursor) -> Int?

    let isUnconditionalEpsilon: Bool

    init(isUnconditionalEpsilon: Bool = false, _ end: State, _ condition: @escaping (Cursor) -> Int?) {
        self.isUnconditionalEpsilon = isUnconditionalEpsilon
        self.end = end
        self.condition = condition
    }

    /// Creates a transition which doesn't consume characters.
    static func epsilon(_ end: State, _ condition: @escaping (Cursor) -> Bool) -> Transition {
        return Transition(end) { condition($0) ? 0 : nil }
    }

    /// Creates a unconditional transition which doesn't consume characters.
    static func epsilon(_ end: State) -> Transition {
        return Transition(isUnconditionalEpsilon: true, end) { _ in 0 }
    }
}
