// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

// MARK: - State

/// A state of a state machine.
final class State: Hashable {
    typealias Index = Int

    var index: Index = 0
    var transitions = [Transition]()
    var isEnd: Bool { transitions.isEmpty }

    // MARK: Hashable

    func hash(into hasher: inout Hasher) {
        ObjectIdentifier(self).hash(into: &hasher)
    }

    static func == (lhs: State, rhs: State) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

extension State: CustomStringConvertible {
    var description: String {
        return "State(\(index)"
    }
}

// MARK: - Transition

/// A transition between two states of the state machine.
struct Transition {
    /// A state into which the transition is performed.
    let end: State

    /// Determines whether the transition is possible in the given context.
    /// Returns `nil` if not possible, otherwise returns number of elements to consume.
    let condition: Condition

    var isUnconditionalEpsilon: Bool {
        guard let epsilon = condition as? Epsilon else {
            return false
        }
        return epsilon.predicate == nil
    }

    init(_ end: State, _ condition: Condition) {
        self.end = end
        self.condition = condition
    }

    /// Creates a transition which doesn't consume characters.
    static func epsilon(_ end: State, _ condition: @escaping (Cursor) -> Bool) -> Transition {
        return Transition(end, Epsilon(condition))
    }

    /// Creates a unconditional transition which doesn't consume characters.
    static func epsilon(_ end: State) -> Transition {
        return Transition(end, Epsilon())
    }
}

// MARK: - Condition

protocol Condition {
    func canPerformTransition(_ cursor: Cursor) -> ConditionResult
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

    func canPerformTransition(_ cursor: Cursor) -> ConditionResult {
        if let predicate = predicate {
            return predicate(cursor) ? .epsilon : .rejected
        }
        return .epsilon
    }
}
