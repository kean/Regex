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
            forMatch(cursor) { match in
                isRunning = closure(match)
                return isRunning // We don't need to run against other lines in the input
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

    /// - parameter closure: Return `false` to stop.
    func forMatch(_ cursor: Cursor, _ closure: (Regex.Match) -> Bool) {
        // Include end index in the search to make sure matches runs for empty
        // strings, and also that it find all possible matches.
        var cursor = cursor
        while true {
            // TODO: tidy up
            let match = firstMatch(cursor, regex.fsm.start)
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
    func firstMatch(_ cursor: Cursor, _ state: State) -> Regex.Match? {
        iterations += 1
        var cursor = cursor

        // Capture a group if needed
        if let captureGroup = regex.captureGroups.first(where: { $0.end == state }),
            let startIndex = cursor.groupsStartIndexes[captureGroup.start] {
            let groupIndex = captureGroup.index
            cursor.groups[groupIndex] = startIndex..<cursor.index
        } else {
            cursor.groupsStartIndexes[state] = cursor.index
        }

        os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor.index), \(cursor.character ?? "∅")] \(symbols.description(for: state))")

        if state.isEnd { // Found a match
            let match = Regex.Match(cursor)
            os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor.index), \(cursor.character ?? "∅")] \(match) ✅")
            return match
        }

        var counter = 0
        for transition in state.transitions {
            counter += 1

            if state.transitions.count > 1 {
                os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor.index), \(cursor.character ?? "∅")] transition \(counter) / \(state.transitions.count)")
            }

            guard let consumed = transition.condition(cursor) else {
                os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor.index), \(cursor.character ?? "∅")] \("❌")")
                continue
            }

            var cursor = cursor
            cursor.advance(by: consumed) // Consume as many characters as need (zero for epsilon transitions)

            if let match = firstMatch(cursor, transition.end) {
                return match
            }
        }

        return nil // No possible matches
    }
}
