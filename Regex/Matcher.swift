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
    func forMatch(in string: String, _ closure: (Match) -> Bool) {
        // Print number of iterations performed, this is for debug purporses only but
        // it is effectively the only thing making Regex non-thread-safe which we ignore.
        os_log(.default, log: log, "%{PUBLIC}@", "Started, input: \(string)")
        iterations = 0
        defer {
            os_log(.default, log: log, "%{PUBLIC}@", "Finished, iterations: \(iterations)")
        }

        var isRunning = true
        for substring in preprocess(string) where isRunning {
            let cursor = Cursor(string: string, substring: substring)
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
    func forMatch(_ cursor: Cursor, _ closure: (Match) -> Bool) {
        // Include end index in the search to make sure matches runs for empty
        // strings, and also that it find all possible matches.
        var cursor = cursor
        while cursor.index <= cursor.range.upperBound {
            if let match = firstMatch(cursor, regex.fsm.start, 0), closure(match) {
                // Found a match, check the remainder of the string
                cursor = cursor.startingAt(match.fullMatch.isEmpty ? match.endIndex + 1 : match.endIndex)
                cursor.previousMatchIndex = match.fullMatch.endIndex
            } else {
                // Didn't find any matches, let's start from the next position
                cursor = cursor.startingAt(cursor.index + 1)
            }
        }
    }

    /// Evaluates the state machine against if finds the first possible match.
    /// The type of the match we find is going to depend on the type of pattern,
    /// e.g. whether greedy or lazy quantifiers were used.
    func firstMatch(_ cursor: Cursor, _ state: State, _ level: Int = 0) -> Match? {
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

        os_log(.default, log: log, "%{PUBLIC}@", "\(String(repeating: " ", count: level))[\(cursor.index), \(cursor.character ?? "∅")] \(state)")

        if state.isEnd { // Found a match
            return Match(cursor)
        }

        let isBranching = state.transitions.count > 1

        for transition in state.transitions {
            guard let consumed = transition.condition(cursor) else {
                os_log(.default, log: log, "%{PUBLIC}@", "\(String(repeating: " ", count: level))[\(cursor.index), \(cursor.character ?? "∅")] \("❌")")
                continue
            }

            if isBranching {
                os_log(.default, log: log, "%{PUBLIC}@", "\(String(repeating: " ", count: level))[\(cursor.index), \(cursor.character ?? "∅")] ᛦ")
            }

            var cursor = cursor
            cursor.index += consumed // Consume as many characters as need (zero for epsilon transitions)

            let match = firstMatch(cursor, transition.toState, isBranching ? level + 1 : level)

            if isBranching {
                os_log(.default, log: log, "%{PUBLIC}@", "\(String(repeating: " ", count: level))[\(cursor.index), \(cursor.character ?? "∅")] \(match == nil ? "✅" : "❌")")
            }

            if let match = match {
                return match
            }
        }

        return nil // No possible matches
    }
}
