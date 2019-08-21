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
    private let states: [State]

    #if DEBUG
    private var symbols: Symbols { regex.symbols }
    private let log: OSLog = Regex.isDebugModeEnabled ? OSLog(subsystem: "com.github.kean.matcher", category: "default") : .disabled
    #endif

    // Capture groups are quite expensive, we can ignore. If we use `isMatch`,
    // we can skip capturing them.
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

        guard let match = nextMatch(cursor) else {
            isFinished = true // We failed to find a match, there can't any more matches
            return nil
        }

        guard match.endIndex <= cursor.string.endIndex && !isStartingFromStartIndex else {
            isFinished = true
            return match
        }

        if match.fullMatch.isEmpty {
            if match.endIndex < cursor.string.endIndex {
                cursor.startAt(cursor.string.index(after: match.endIndex))
            } else {
                isFinished = true
            }
        } else {
            cursor.startAt(match.endIndex)
        }
        cursor.previousMatchIndex = match.fullMatch.endIndex

        return match
    }
    
    /// Evaluates the state machine against if finds the first possible match.
    /// The type of the match we find is going to depend on the type of pattern,
    /// e.g. whether greedy or lazy quantifiers were used.
    ///
    /// - warning: The matcher hasn't been optimized in any way yet
    func nextMatch(_ cursor: Cursor) -> Regex.Match? {
        var cursor = cursor
        var retryIndex: String.Index?
        var reachableStates = MicroSet<StateId>(0)
        var newReachableStates = MicroSet<StateId>()
        var reachableUntil = [StateId: String.Index]() // some transitions jump multiple indices
        var encountered = [Bool](repeating: false, count: regex.states.count)
        var potentialMatch: Cursor?
        var groupsStartIndexes = [StateId: String.Index]()
        var stack = [StateId]()

        while !reachableStates.isEmpty {
            newReachableStates = MicroSet()

            #if DEBUG
            if log.isEnabled { os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor)]: >> Reachable \(reachableStates.map { symbols.description(for: states[$0]) })") }
            #endif

            // The array works great where there are not a lot of states which
            // isn't the case with patterns like a{24,42}
            for index in encountered.indices { encountered[index] = false }

            // For each state check if there are any reachable states – states which
            // accept the next character from the input string.
            for stateId in reachableStates {
                // [Optimization] Support for Match.string
                if let index = reachableUntil[stateId] {
                    if index > cursor.index {
                        newReachableStates.insert(stateId)
                        encountered[stateId] = true

                        #if DEBUG
                        if log.isEnabled { os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor)]: Still reachable for this index, re-add \(symbols.description(for: states[stateId]))") }
                        #endif

                         // Important! Don't update capture groups, haven't reached the index yet!
                        continue
                    } else {
                        reachableUntil[stateId] = nil
                    }
                }

                // Go throught the graph of states using depth-first search.
                stack.append(stateId)

                while let stateId = stack.popLast() {
                    guard !encountered[stateId] else { continue }
                    encountered[stateId] = true

                    #if DEBUG
                    if log.isEnabled { os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor)]: Check reachability from \(symbols.description(for: states[stateId])))") }
                    #endif

                    // Capture a group if needed or update group start indexes
                    if isCapturingGroups {
                        if let captureGroup = regex.captureGroups.first(where: { $0.end == stateId }),
                            // Capture a group
                            let startIndex = groupsStartIndexes[captureGroup.start] {
                            let groupIndex = captureGroup.index
                            cursor.groups[groupIndex] = startIndex..<cursor.index
                        } else {
                            // Remember where the group started
                            if regex.captureGroups.contains(where: { $0.start == stateId }) {
                                if groupsStartIndexes[stateId] == nil {
                                    groupsStartIndexes[stateId] = cursor.index
                                }
                            }
                        }
                    }

                    guard !states[stateId].isEnd else {
                        if potentialMatch == nil || cursor.index > potentialMatch!.index {
                            potentialMatch = cursor // Found a match!

                            #if DEBUG
                            if log.isEnabled { os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor)]: Found a potential match \(symbols.description(for: states[stateId]))") }
                            #endif
                        }
                        continue
                    }

                    for transition in states[stateId].transitions {
                        guard let consumed = transition.condition(cursor) else {
                            #if DEBUG
                            if log.isEnabled { os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor)]: End state NOT reachable \(symbols.description(for: transition.end))") }
                            #endif
                            continue
                        }

                        #if DEBUG
                        if log.isEnabled { os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor)]: End state reachable \(symbols.description(for: transition.end))") }
                        #endif

                        if consumed > 0 {
                            newReachableStates.insert(transition.end.id)
                            // The state is going to be reachable until we reach index T+consumed
                            if consumed > 1 {
                                reachableUntil[transition.end.id] = cursor.string.index(cursor.index, offsetBy: consumed, limitedBy: cursor.string.endIndex)
                            }
                        } else {
                            stack.append(transition.end.id)
                        }
                    }
                }
            }

            // Check if nothing left to match
            guard !cursor.isEmpty else {
                break
            }

            // Support for String.match
            if reachableUntil.count > 0 && reachableUntil.count == newReachableStates.count {
                // We can jump multiple indices at a time because there are going to be
                // not changes to reachable states until the suggested index.
                cursor.advance(to: reachableUntil.values.min()!)
            } else {
                cursor.advance(by: 1)
            }

            // The iteration produced the exact same set of reachable states as
            // one of the previous ones. If we fail to match a string, we can
            // skip the entire section of the string up to the current cursor.
            if reachableStates == newReachableStates {
                retryIndex = cursor.index // We can restart earlier
            }

            reachableStates = newReachableStates

            #if DEBUG
            if log.isEnabled { os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor)]: << Reachable \(reachableStates.map { symbols.description(for: states[$0]) })") }
            #endif
            
            // We failed to find any matches within a given string
            if reachableStates.isEmpty && potentialMatch == nil && !isStartingFromStartIndex {
                
                #if DEBUG
                if log.isEnabled { os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor)]: Failed to find matches \(reachableStates.map { symbols.description(for: states[$0]) })") }
                #endif

                if let index = retryIndex {
                    cursor.startAt(index)
                    retryIndex = nil
                } else {
                    cursor.startAt(cursor.string.index(after: cursor.startIndex))
                }
                if isCapturingGroups {
                    groupsStartIndexes = [:]
                }
                reachableStates = MicroSet(0)
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
}

/// MARK: - Matcher (Option 2: Backtracking)
///
/// An backtracking implementation which is only used when specific constructs
/// like backreferences are used which are non-regular and cannot be implemented
/// only using NFA (and efficiently executed as NFA).
final class BacktrackingMatcher: Matching {
    private let string: String
    private let regex: CompiledRegex
    private let options: Regex.Options
    private let states: [State]

    #if DEBUG
    private var symbols: Symbols { regex.symbols }
    private let log: OSLog = Regex.isDebugModeEnabled ? OSLog(subsystem: "com.github.kean.matcher", category: "default") : .disabled
    #endif

    // Capture groups are quite expensive, we can ignore. If we use `isMatch`,
    // we can skip capturing them.
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

        guard let match = firstMatchBacktracking(cursor, [:], regex.states[0]) else {
            // We couldn't find a match but `forMatchBacktracking` doesn't
            // automatically restart on errors unlike `RegularMatcher` so we
            // have to do that manually. This needs clean up.
            if cursor.startIndex < cursor.string.endIndex {
                cursor.startAt(cursor.string.index(after: cursor.startIndex))
                return nextMatch()
            } else {
                isFinished = true
                return nil
            }
        }

        if match.fullMatch.isEmpty {
            if match.endIndex < cursor.string.endIndex {
                cursor.startAt(cursor.string.index(after: match.endIndex))
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
            let match = firstMatchBacktracking(cursor, [:], regex.states[0])

            guard match == nil || closure(match!) else {
                return
            }
            guard !regex.isFromStartOfString else {
                return
            }
            guard cursor.index < cursor.string.endIndex else {
                return
            }
            let index = match.map {
                $0.fullMatch.isEmpty ? cursor.string.index(after: $0.endIndex) : $0.endIndex
                } ?? cursor.string.index(after: cursor.index)

            cursor.startAt(index)
            if let match = match {
                cursor.previousMatchIndex = match.fullMatch.endIndex
            }
        }
    }

    /// Evaluates the state machine against if finds the first possible match.
    /// The type of the match we find is going to depend on the type of pattern,
    /// e.g. whether greedy or lazy quantifiers were used.
    ///
    /// - warning: The matcher hasn't been optimized in any way yet
    func firstMatchBacktracking(_ cursor: Cursor, _ groupsStartIndexes: [StateId: String.Index], _ state: State) -> Regex.Match? {
        var cursor = cursor
        var groupsStartIndexes = groupsStartIndexes

        // Capture a group if needed
        if !regex.captureGroups.isEmpty {
            if let captureGroup = regex.captureGroups.first(where: { $0.end == state.id }),
                let startIndex = groupsStartIndexes[captureGroup.start] {
                let groupIndex = captureGroup.index
                cursor.groups[groupIndex] = startIndex..<cursor.index
            } else {
                groupsStartIndexes[state.id] = cursor.index
            }
        }

        #if DEBUG
        if log.isEnabled { os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor.index), \(cursor.character ?? "∅")] \(symbols.description(for: state))") }
        #endif

        if state.isEnd { // Found a match
            let match = Regex.Match(cursor, !regex.captureGroups.isEmpty)
            #if DEBUG
            if log.isEnabled { os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor.index), \(cursor.character ?? "∅")] \(match) ✅") }
            #endif
            return match
        }

        var counter = 0
        for transition in state.transitions {
            counter += 1

            if state.transitions.count > 1 {
                #if DEBUG
                if log.isEnabled { os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor.index), \(cursor.character ?? "∅")] transition \(counter) / \(state.transitions.count)") }
                #endif
            }

            guard let consumed = transition.condition(cursor) else {
                #if DEBUG
                if log.isEnabled { os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor.index), \(cursor.character ?? "∅")] \("❌")") }
                #endif
                continue
            }

            var cursor = cursor
            cursor.advance(by: consumed) // Consume as many characters as need (zero for epsilon transitions)

            if let match = firstMatchBacktracking(cursor, groupsStartIndexes, transition.end) {
                return match
            }
        }

        return nil // No possible matches
    }
}
