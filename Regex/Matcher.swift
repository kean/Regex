// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation
import os.log

// MARK: - Matcher

final class Matcher {
    private let log: OSLog = Regex.isDebugModeEnabled ? OSLog(subsystem: "com.github.kean.matcher", category: "default") : .disabled
    
    private let options: Regex.Options
    private let regex: CompiledRegex
    private let symbols: Symbols
    private var iterations = 0
    
    init(regex: CompiledRegex, options: Regex.Options, symbols: Symbols) {
        self.regex = regex
        self.options = options
        self.symbols = symbols
    }
    
    /// - parameter closure: Return `false` to stop.
    func forMatch(in string: String, _ closure: (Regex.Match) -> Bool) {
        // Print number of iterations performed, this is for debug purporses only but
        // it is effectively the only thing making Regex non-thread-safe which we ignore.
        os_log(.default, log: log, "%{PUBLIC}@", "Started, input: \(string)")
        iterations = 0
        defer {
            os_log(.default, log: log, "%{PUBLIC}@", "Finished, iterations: \(iterations)")
        }
        
        var isRunning = true
        for line in preprocess(string) where isRunning {
            let cursor = Cursor(string: line, completeInputString: string)
            if regex.isRegular {
                // Use optimized NFA simulation
                forMatch(cursor) { match in
                    isRunning = closure(match)
                    return isRunning // We don't need to run against other lines in the input
                }
            } else {
                // Fallback to backtracing
                forMatchBacktracking(cursor) { match in
                    isRunning = closure(match)
                    return isRunning // We don't need to run against other lines in the input
                }
            }
        }
    }
}

private extension Matcher {
    
    func preprocess(_ string: String) -> [Substring] {
        if options.contains(.multiline) {
            return string.split(separator: "\n")
        } else {
            return [string[...]]
        }
    }
}

// MARK: - Matcher (Option 1: Parallel NFA)

// An efficient NFA execution (TODO: what guarantees does it give?)
private extension Matcher {
    
    /// - parameter closure: Return `false` to stop.
    func forMatch(_ cursor: Cursor, _ closure: (Regex.Match) -> Bool) {
        // Include end index in the search to make sure matches runs for empty
        // strings, and also that it find all possible matches.
        var cursor = cursor
        while let match = firstMatch(cursor, regex.fsm.start), closure(match) {
            guard cursor.index < cursor.string.endIndex else {
                return
            }
            if match.fullMatch.isEmpty {
                cursor.startAt(cursor.string.index(after: match.endIndex))
            } else {
                cursor.startAt(match.endIndex)
            }
            cursor.previousMatchIndex = match.fullMatch.endIndex
        }
    }
    
    /// Evaluates the state machine against if finds the first possible match.
    /// The type of the match we find is going to depend on the type of pattern,
    /// e.g. whether greedy or lazy quantifiers were used.
    ///
    /// - warning: The matcher hasn't been optimized in any way yet
    func firstMatch(_ cursor: Cursor, _ start: State) -> Regex.Match? {
        var cursor = cursor
        var retryCursor = cursor
        var reachableStates = [start]
        var newReachableStates = [State]()
        var encountered = Set<State>()
        var potentialMatch: Cursor?
        var stack = [State]()

        while !reachableStates.isEmpty {
            newReachableStates.removeAll()

            // For each state check if there are any reachable states – states which
            // accept the next character from the input string.
            for state in reachableStates {
                iterations += 1

                // Go throught the graph of states using depth-first search.
                stack.append(state)
                encountered.removeAll()
                
                while let state = stack.popLast(), !encountered.contains(state) {
                    // Capture a group if needed or update group start indexes
                    updateCaptureGroup(&cursor, state)

                    guard !state.isEnd else {
                        if potentialMatch == nil || cursor.index > potentialMatch!.index {
                            potentialMatch = cursor // Found a match!
                        }
                        continue
                    }

                    encountered.insert(state)

                    for transition in state.transitions {
                        guard let consumed = transition.condition(cursor) else {
                            continue
                        }
                        if consumed > 0 {
                            if !newReachableStates.contains(transition.end) {
                                newReachableStates.append(transition.end)
                            }
                        } else {
                            stack.append(transition.end)
                        }
                    }
                }
            }

            // Check if nothing left to match
            guard !cursor.isEmpty else {
                break
            }
            cursor.advance(by: 1)

            // The iteration produced the exact same result as the previous one,
            // if we need to fallback, we don't have to fallback all the way
            // TODO: enable the same optimization for longer NFAs
            if Set(reachableStates) == Set(newReachableStates) && !newReachableStates.isEmpty {
                retryCursor = cursor
            }
            reachableStates = newReachableStates
            
            // We failed to find any matches within a given string
            if reachableStates.isEmpty && potentialMatch == nil && retryCursor.index < cursor.string.endIndex {
                // TODO: tidy up
                if retryCursor.index < cursor.index {
                    // We haven't saved any "optimial" retry cursor so we simply restart
                    retryCursor.startAt(cursor.string.index(after: retryCursor.index))
                }
                
                // Remove groups which can't be captures after retry
                removeOutdatedCaptureGroups(&retryCursor)
                
                cursor = retryCursor
                reachableStates = [start]
            }
        }
        
        return potentialMatch.map { Regex.Match($0) }
    }

    private func updateCaptureGroup(_ cursor: inout Cursor, _ state: State) {
        guard !regex.captureGroups.isEmpty else {
            return
        }

        if let captureGroup = regex.captureGroups.first(where: { $0.end == state }),
            // Capture a group
            let startIndex = cursor.groupsStartIndexes[captureGroup.start] {
            let groupIndex = captureGroup.index
            cursor.groups[groupIndex] = startIndex..<cursor.index
        } else {
            // Remember where the group started
            if regex.captureGroups.contains(where: { $0.start == state }) {
                if cursor.groupsStartIndexes[state] == nil {
                    cursor.groupsStartIndexes[state] = cursor.index
                }
            }
        }
    }

    /// Remove the capture groups which fall behind the current cursor.
    private func removeOutdatedCaptureGroups(_ cursor: inout Cursor) {
        for (key, group) in cursor.groups {
            if group.lowerBound < cursor.startIndex {
                cursor.groups[key] = nil
            }
        }
        for (key, index) in cursor.groupsStartIndexes {
            if index < cursor.startIndex {
                cursor.groupsStartIndexes[key] = nil
            }
        }
    }
}

// MARK: - Matcher (Option 2: Backtracking)

// An backtracking implementation which is only used when specific constructs
// like backreferences are used which are non-regular and cannot be implemented
// only using NFA (and efficiently executed as NFA).
private extension Matcher {
    
    /// - parameter closure: Return `false` to stop.
    func forMatchBacktracking(_ cursor: Cursor, _ closure: (Regex.Match) -> Bool) {
        // Include end index in the search to make sure matches runs for empty
        // strings, and also that it find all possible matches.
        var cursor = cursor
        while true {
            // TODO: tidy up
            let match = firstMatchBacktracking(cursor, regex.fsm.start)
            
            guard match == nil || closure(match!) else {
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
    func firstMatchBacktracking(_ cursor: Cursor, _ state: State) -> Regex.Match? {
        iterations += 1
        var cursor = cursor
        
        // Capture a group if needed
        if !regex.captureGroups.isEmpty {
            if let captureGroup = regex.captureGroups.first(where: { $0.end == state }),
                let startIndex = cursor.groupsStartIndexes[captureGroup.start] {
                let groupIndex = captureGroup.index
                cursor.groups[groupIndex] = startIndex..<cursor.index
            } else {
                cursor.groupsStartIndexes[state] = cursor.index
            }
        }

        if Regex.isDebugModeEnabled {
            os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor.index), \(cursor.character ?? "∅")] \(symbols.description(for: state))")
        }
        
        if state.isEnd { // Found a match
            let match = Regex.Match(cursor)
            if Regex.isDebugModeEnabled {
                os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor.index), \(cursor.character ?? "∅")] \(match) ✅")
            }
            return match
        }
        
        var counter = 0
        for transition in state.transitions {
            counter += 1
            
            if state.transitions.count > 1 {
                if Regex.isDebugModeEnabled {
                    os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor.index), \(cursor.character ?? "∅")] transition \(counter) / \(state.transitions.count)")
                }
            }
            
            guard let consumed = transition.condition(cursor) else {
                if Regex.isDebugModeEnabled {
                    os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor.index), \(cursor.character ?? "∅")] \("❌")")
                }
                continue
            }
            
            var cursor = cursor
            cursor.advance(by: consumed) // Consume as many characters as need (zero for epsilon transitions)
            
            if let match = firstMatchBacktracking(cursor, transition.end) {
                return match
            }
        }
        
        return nil // No possible matches
    }
}
