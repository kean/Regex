// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

// MARK: - State

/// An intermediate representation of a state of a state machine. This representation
/// is more convenient for creating and combining the state machines, but not
/// executing them.
struct State: CustomStringConvertible {
    typealias Index = Int

    let index: Index
    let transitions: [Transition]
    var isEnd: Bool { transitions.isEmpty }

    // MARK: CustomStringConvertible

    var description: String {
        return "State(\(index)"
    }
}

// MARK: - Transition

/// A transition between two states of the state machine.
struct Transition {
    /// A state into which the transition is performed.
    let end: State.Index

    /// Determines whether the transition is possible in the given context.
    /// Returns `nil` if not possible, otherwise returns number of elements to consume.
    let condition: Condition

    init(_ end: State.Index, _ condition: Condition) {
        self.end = end
        self.condition = condition
    }
}

// MARK: - Condition

// We use a protocol instead of closures because closures always incur ARC overhead:
//
//     strong_retain %641 : $@callee_guaranteed (@guaranteed Cursor) -> Optional<Int> // id: %650
//
// By using protocols we can use value types instead.
protocol Condition {
    func canTransition(_ cursor: Cursor) -> ConditionResult
}

enum ConditionResult {
    /// A transition can be performed and it consumes `count` characters.
    case accepted(count: Int = 1)

    /// A transition can be performed but it doesn't consume any characters.
    case epsilon

    /// Transitions can't be performed for the given input.
    case rejected
}

struct Epsilon: Condition {
    let predicate: ((Cursor) -> Bool)?

    init(_ predicate: ((Cursor) -> Bool)? = nil) {
        self.predicate = predicate
    }

    func canTransition(_ cursor: Cursor) -> ConditionResult {
        if let predicate = predicate {
            return predicate(cursor) ? .epsilon : .rejected
        }
        return .epsilon
    }
}
