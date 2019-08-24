// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation
import os.log

// MARK: - Matching

protocol Matching {
    /// Returns the next match in the input.
    func nextMatch() -> Regex.Match?
}

// MARK: - RegularMatcher

/// Executes the regex using an efficient algorithm where each state of NFA
/// is evaluated at the same time at given cursor.
///
/// Handles large inputs with easy and the amount of memory that it uses is limited
/// by the number of states in the state machine, it doesn't on the size of input string.
final class RegularMatcher: Matching {
    private let string: String
    private let regex: CompiledRegex
    private let options: Regex.Options
    private let states: ContiguousArray<State>

    #if DEBUG
    private var symbols: Symbols { regex.symbols }
    private let log: OSLog = Regex.isDebugModeEnabled ? OSLog(subsystem: "com.github.kean.matcher", category: "default") : .disabled
    #endif

    // If `false`, some expensive pathes that calculate capture groups can be ignored
    private let isCapturingGroups: Bool
    private let isStartingFromStartIndex: Bool

    private var cursor: Cursor
    private var isFinished = false

    // Reuse allocated buffers across different invocations to avoid deallocating
    // and allocating them again every time.
    private var reachableStates = MicroSet<State.Index>(0)
    private var reachableUntil = [State.Index: String.Index]() // some transitions jump multiple indices
    private var potentialMatch: Cursor?
    private var groupsStartIndexes = [State.Index: String.Index]()
    private var stack = ContiguousArray<State.Index>()
    private var encountered: ContiguousArray<Bool>

    init(string: String, regex: CompiledRegex, options: Regex.Options, ignoreCaptureGroups: Bool) {
        self.string = string
        self.regex = regex
        self.states = regex.states
        self.options = options
        self.isCapturingGroups = !ignoreCaptureGroups && !regex.captureGroups.isEmpty
        self.isStartingFromStartIndex = regex.isFromStartOfString && !options.contains(.multiline)
        self.cursor = Cursor(string: string)
        self.encountered = ContiguousArray<Bool>(repeating: false, count: regex.states.count)
    }

    func nextMatch() -> Regex.Match? {
        guard !isFinished else {
            return nil
        }

        guard let match = _nextMatch() else {
            isFinished = true // Failed to find a match and there can be no more matches
            return nil
        }

        guard match.endIndex <= cursor.endIndex && !isStartingFromStartIndex else {
            isFinished = true
            return match
        }

        if match.fullMatch.isEmpty {
            if match.endIndex < cursor.endIndex {
                cursor.startAt(cursor.index(after: match.endIndex))
            } else {
                isFinished = true
            }
        } else {
            cursor.startAt(match.endIndex)
        }
        cursor.previousMatchIndex = match.fullMatch.endIndex

        return match
    }

    private func _nextMatch() -> Regex.Match? {
        var retryIndex: String.Index?
        reachableStates = MicroSet(0)
        reachableUntil.removeAll()
        potentialMatch = nil
        if isCapturingGroups { groupsStartIndexes.removeAll() }

        while !reachableStates.isEmpty {

            let newReachableStates = findNextReachableStates()

            guard !cursor.isEmpty else {
                break // The input string is empty, can stop now
            }

            // [Optimization] The iteration produced the same set of reachable
            // states as the current on, it's possible to skip checking this index again
            if reachableStates == newReachableStates {
                retryIndex = cursor.index
            }

            reachableStates = newReachableStates

            #if DEBUG
            if log.isEnabled { os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor)]: << Reachable \(reachableStates.map { symbols.description(for: states[$0]) })") }
            #endif

            if reachableStates.isEmpty && potentialMatch == nil && !isStartingFromStartIndex {
                // Failed to find matches, restart from the initial state
                
                #if DEBUG
                if log.isEnabled { os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor)]: Failed to find matches \(reachableStates.map { symbols.description(for: states[$0]) })") }
                #endif

                if let index = retryIndex {
                    cursor.startAt(index)
                    retryIndex = nil
                } else {
                    cursor.startAt(cursor.index(after: cursor.startIndex))
                }

                if isCapturingGroups { groupsStartIndexes.removeAll() }
                reachableStates = MicroSet(0)
            } else {
                // Advance the cursor
                if reachableUntil.count > 0 && reachableUntil.count == newReachableStates.count {
                    // Jump multiple indices at a time without checking condition again
                    cursor.advance(to: reachableUntil.values.min()!)
                } else {
                    cursor.advance(by: 1)
                }
            }
        }

        if let cursor = potentialMatch {
            let match = Regex.Match(cursor, isCapturingGroups)
            #if DEBUG
            if log.isEnabled { os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor)]: Found match \(match)") }
            #endif
            return match
        }

        #if DEBUG
        if log.isEnabled { os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor)]: Failed to find matches") }
        #endif

        return nil
    }

    /// Uses breadth-first-search to find states reachable from the current
    /// reachable set of states after consuming the next character (or multiple
    /// characters at the same time in case of Match.string).
    ///
    /// As it enters states, it also captures groups, and collects potential matches.
    /// It doesn't stop on the first found match and tries to find the longest
    /// match instead (aka "greedy").
    private func findNextReachableStates() -> MicroSet<State.Index> {
        var newReachableStates = MicroSet<State.Index>()

        #if DEBUG
        if log.isEnabled { os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor)]: >> Reachable \(reachableStates.map { symbols.description(for: states[$0]) })") }
        #endif

        // The array works great where there are not a lot of states which
        // isn't the case with patterns like a{24,42}
        for index in encountered.indices { encountered[index] = false }

        // For each state check if there are any reachable states – states which
        // accept the next character from the input string.
        for state in reachableStates {
            // [Optimization] Support for Match.string
            if let index = reachableUntil[state] {
                if index > cursor.index {
                    newReachableStates.insert(state)
                    encountered[state] = true

                    #if DEBUG
                    if log.isEnabled { os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor)]: Still reachable for this index, re-add \(symbols.description(for: states[state]))") }
                    #endif

                    continue
                } else {
                    reachableUntil[state] = nil
                }
            }

            // Go throught the graph of states using depth-first search.
            stack.append(state)
            while let state = stack.popLast() {
                guard !encountered[state] else { continue }
                encountered[state] = true

                #if DEBUG
                if log.isEnabled { os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor)]: Check reachability from \(symbols.description(for: states[state])))") }
                #endif

                // Capture a group if needed or update group start indexes
                if isCapturingGroups {
                    updateCaptureGroups(enteredState: state)
                }

                /// Reached the end state, remember the potential match. There might be multiple
                /// ways to reach the end state that's why it is not stopping on the first match.
                guard !states[state].isEnd else {
                    updatePotentialMatch(state)
                    continue
                }

                for transition in states[state].transitions {
                    let result = transition.condition.canPerformTransition(cursor)
                    switch result {
                    case .rejected:
                        break // Do nothing
                    case .epsilon:
                        stack.append(transition.end.index) // Continue walking the graph
                    case let .accepted(count):
                        newReachableStates.insert(transition.end.index)
                        // The state is going to be reachable until index T+count is reached
                        if count > 1 {
                            reachableUntil[transition.end.index] = cursor.index(cursor.index, offsetBy: count, isLimited: true)
                        }
                    }

                    #if DEBUG
                    let message: String
                    switch result {
                    case .rejected: message = "State NOT reachable"
                    case .epsilon: message = "State reachable via epsilon"
                    case let .accepted(count): message = "State reachable consuming \(count)"
                    }
                    if log.isEnabled { os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor)]: \(message) \(symbols.description(for: transition.end))") }
                    #endif
                }
            }
        }

        return newReachableStates
    }

    /// Update capture groups when entering a state.
    private func updateCaptureGroups(enteredState state: State.Index) {
        if let captureGroup = regex.captureGroups.first(where: { $0.end == state }),
            // Capture a group
            let startIndex = groupsStartIndexes[captureGroup.start] {
            let groupIndex = captureGroup.index
            cursor.groups[groupIndex] = startIndex..<cursor.index
        } else {
            // Remember where the group started
            if regex.captureGroups.contains(where: { $0.start == state }) {
                if groupsStartIndexes[state] == nil {
                    groupsStartIndexes[state] = cursor.index
                }
            }
        }
    }

    private func updatePotentialMatch(_ state: State.Index) {
        guard potentialMatch == nil || cursor.index > potentialMatch!.index else {
            return
        }

        potentialMatch = cursor // Found a match!

        #if DEBUG
        if log.isEnabled { os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor)]: Found a potential match \(symbols.description(for: states[state]))") }
        #endif
    }
}

/// MARK: - BacktrackingMatcher
///
/// An backtracking implementation which is only used when specific constructs
/// like backreferences are used which are non-regular and cannot be implemented
/// only using NFA (and efficiently executed as NFA).
final class BacktrackingMatcher: Matching {
    private let string: String
    private let regex: CompiledRegex
    private let options: Regex.Options

    // Indexing `ContiguousArray` doesn't introduce strong_retain calls unlike
    // indexing `Array` which does. It might be a temporary limitation of ARC
    // optimizer https://github.com/apple/swift/blob/master/docs/ARCOptimization.rst
    //
    //   %1249 = index_addr %1248 : $*State, %753 : $Builtin.Word // user: %1250
    //   %1250 = load %1249 : $*State                  // users: %1251, %1252
    //   strong_retain %1250 : $State                  // id: %1251
    private let states: ContiguousArray<State>

    #if DEBUG
    private var symbols: Symbols { regex.symbols }
    private let log: OSLog = Regex.isDebugModeEnabled ? OSLog(subsystem: "com.github.kean.matcher", category: "default") : .disabled
    #endif

    // If `false`, some expensive pathes that calculate capture groups can be ignored
    private let isCapturingGroups: Bool
    private let isStartingFromStartIndex: Bool

    private var cursor: Cursor
    private var isFinished = false

    init(string: String, regex: CompiledRegex, options: Regex.Options, ignoreCaptureGroups: Bool) {
        self.string = string
        self.regex = regex
        self.states = regex.states
        self.options = options
        self.isCapturingGroups = !ignoreCaptureGroups && !regex.captureGroups.isEmpty
        self.isStartingFromStartIndex = regex.isFromStartOfString && !options.contains(.multiline)
        self.cursor = Cursor(string: string)
    }

    func nextMatch() -> Regex.Match? {
        guard !isFinished else {
            return nil
        }

        if isStartingFromStartIndex {
            isFinished = true
        }

        guard let match = firstMatchBacktracking(cursor, [:], 0) else {
            // Couldn't find a match but `forMatchBacktracking` doesn't
            // automatically restart on errors unlike `RegularMatcher` so we
            // have to do that manually. This needs clean up.
            if cursor.startIndex < cursor.endIndex {
                cursor.startAt(cursor.index(after: cursor.startIndex))
                return nextMatch()
            } else {
                isFinished = true
                return nil
            }
        }

        if match.fullMatch.isEmpty {
            if match.endIndex < cursor.endIndex {
                cursor.startAt(cursor.index(after: match.endIndex))
            } else {
                isFinished = true
            }
        } else {
            cursor.startAt(match.endIndex)
        }
        cursor.previousMatchIndex = match.fullMatch.endIndex

        return match
    }

    /// - parameter closure: Return `false` to stop.
    func forMatchBacktracking(_ string: String, _ closure: (Regex.Match) -> Bool) {
        // Include end index in the search to make sure matches runs for empty
        // strings, and also that it find all possible matches.
        var cursor = Cursor(string: string)
        while true {
            // TODO: tidy up
            let match = firstMatchBacktracking(cursor, [:], 0)

            guard match == nil || closure(match!) else {
                return
            }
            guard !regex.isFromStartOfString else {
                return
            }
            guard cursor.index < cursor.endIndex else {
                return
            }
            let index = match.map {
                $0.fullMatch.isEmpty ? cursor.index(after: $0.endIndex) : $0.endIndex
            } ?? cursor.index(after: cursor.index)

            cursor.startAt(index)
            if let match = match {
                cursor.previousMatchIndex = match.fullMatch.endIndex
            }
        }
    }

    /// Evaluates the state machine against if finds the first possible match.
    /// The type of the match found is going to depend on the type of pattern,
    /// e.g. whether greedy or lazy quantifiers were used.
    ///
    /// - warning: The backtracking matcher hasn't been optimized in any way yet
    func firstMatchBacktracking(_ cursor: Cursor, _ groupsStartIndexes: [State.Index: String.Index], _ state: State.Index) -> Regex.Match? {
        var cursor = cursor
        var groupsStartIndexes = groupsStartIndexes

        // Capture a group if needed
        if !regex.captureGroups.isEmpty {
            if let captureGroup = regex.captureGroups.first(where: { $0.end == state }),
                let startIndex = groupsStartIndexes[captureGroup.start] {
                let groupIndex = captureGroup.index
                cursor.groups[groupIndex] = startIndex..<cursor.index
            } else {
                groupsStartIndexes[state] = cursor.index
            }
        }

        #if DEBUG
        if log.isEnabled { os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor.index), \(cursor.character ?? "∅")] \(symbols.description(for: state))") }
        #endif

        if states[state].isEnd { // Found a match
            let match = Regex.Match(cursor, !regex.captureGroups.isEmpty)
            #if DEBUG
            if log.isEnabled { os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor.index), \(cursor.character ?? "∅")] \(match) ✅") }
            #endif
            return match
        }

        var counter = 0
        for transition in states[state].transitions {
            counter += 1

            #if DEBUG
            if states[state].transitions.count > 1 {
                if log.isEnabled { os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor.index), \(cursor.character ?? "∅")] transition \(counter) / \(states[state].transitions.count)") }
            }
            #endif

            var cursor = cursor

            switch transition.condition.canPerformTransition(cursor) {
            case .rejected:
                #if DEBUG
                if log.isEnabled { os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor.index), \(cursor.character ?? "∅")] \("❌")") }
                #endif

                continue
            case .epsilon:
                break // Continue, don't advance cursor
            case let .accepted(count):
                cursor.advance(by: count) // Consume as many characters as need (zero for epsilon transitions)
            }

            if let match = firstMatchBacktracking(cursor, groupsStartIndexes, states[transition.end.index].index) {
                return match
            }
        }

        return nil // No possible matches
    }
}
