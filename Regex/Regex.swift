// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation
import os.log

// MARK: - Regex

// Supported Features
// ==================
//
//   Quantifiers
//
// * - match zero or more times
// + - match one or more times
// ? - match zero or one time
// {n} - match exactly n times
// {n,} - match at least n times
// {n,m} - match from n to m times (closed range)
//
//   Alternation Constructs
//
// | - match either left side or right side
public final class Regex {
    private let options: Options
    private let expression: Expression
    private static let log: OSLog = .default
    private var iterations = 0

    /// Returns the number of capture groups in the regular expression.
    public let numberOfCaptureGroups: Int

    /// An array of capture groups in an order in which they appear in the pattern.
    private let captureGroups: [State]

    public struct Options: OptionSet {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// Match letters in the pattern independent of case.
        public static let caseInsensitive = Options(rawValue: 1 << 0) // 'i'

        /// Control the behavior of "^" and "$" in a pattern. By default these
        /// will only match at the start and end, respectively, of the input text.
        /// If this flag is set, "^" and "$" will also match at the start and end
        /// of each line within the input text.
        public static let multiline = Options(rawValue: 1 << 1) // 'm'

        /// Allow `.` to match any character, including line separators.
        public static let dotMatchesLineSeparators = Options(rawValue: 1 << 2) // 's'
    }

    public init(_ pattern: String, _ options: Options = []) throws {
        do {
            let compiler = Compiler(pattern, options)
            self.expression = try compiler.compile()
            self.captureGroups = expression.allStates()
                .filter { if case .groupStart? = $0.info { return true }; return false }
            self.numberOfCaptureGroups = captureGroups.count
            self.options = options
            os_log(.default, log: Regex.log, "Expression: \n\n%{PUBLIC}@", expression.description)
        } catch {
            var error = error as! Error
            error.pattern = pattern // Attach additional context
            throw error
        }
    }

    /// Determine whether the regular expression pattern occurs in the input text.
    public func isMatch(_ string: String) -> Bool {
        var isMatchFound = false
        forMatch(in: string) { match in
            isMatchFound = true
            return false // It's enough to find one match
        }
        return isMatchFound
    }

    /// Returns an array containing all the matches in the string.
    public func matches(in string: String) -> [Match] {
        var matches = [Match]()
        forMatch(in: string) { match in
            matches.append(match)
            return true // Continue finding matches
        }
        return matches
    }

    // MARK: Match (Private)

    /// - parameter closure: Return `false` to stop.
    private func forMatch(in string: String, _ closure: (Match) -> Bool) {
        // Print number of iterations performed, this is for debug purporses only but
        // it is effectively the only thing making Regex non-thread-safe which we ignore.
        os_log(.default, log: Regex.log, "%{PUBLIC}@", "Started, input: \(string)")
        iterations = 0
        defer {
            os_log(.default, log: Regex.log, "%{PUBLIC}@", "Finished, iterations: \(iterations)")
        }

        for substring in preprocess(string) {
            let cache = Cache()
            var cursor = Cursor(string: string, substring: substring)
            while let match = firstMatch(cursor, cache), closure(match) {
                cursor = cursor.startingAt(match.endIndex)
                cursor.previousMatchIndex = match.fullMatch.endIndex
            }
        }
    }

    private func preprocess(_ string: String) -> [Substring] {
        let string = (options.contains(.caseInsensitive) ? string.lowercased() : string)
        if options.contains(.multiline) {
            return string.split(separator: "\n")
        } else {
            return [string[...]]
        }
    }

    private func firstMatch(_ cursor: Cursor, _ cache: Cache) -> Match? {
        // If the input string is empty, we still need to run the regex once to verify
        // that the empty string matches, thus `isEmpty` check.
        for i in (cursor.characters.isEmpty ? 0..<1 : cursor.range) {
            if let match = firstMatch(cursor.startingAt(i), [:], expression.start, cache) {
                return match
            }
        }
        return nil
    }

    // Find the match in the given string. Captures groups as it goes.
    private func firstMatch(_ cursor: Cursor, _ context: Context, _ state: State, _ cache: Cache, _ level: Int = 0) -> Match? {
        iterations += 1
        os_log(.default, log: Regex.log, "%{PUBLIC}@", "\(String(repeating: " ", count: level))[\(cursor.index), \(cursor.character ?? "∅")] \(state)")

        guard !state.isEnd else { // Found a match
            return Match(cursor)
        }

        let key = Cache.Key(index: cursor.index, state: state, context: context)
        if let match = cache[key] {
            return match.get()
        }

        let isBranching = state.transitions.count > 1

        for transition in state.transitions {
            guard let consumed = transition.condition(cursor, context) else {
                os_log(.default, log: Regex.log, "%{PUBLIC}@", "\(String(repeating: " ", count: level))[\(cursor.index), \(cursor.character ?? "∅")] \("❌")")
                continue
            }

            if isBranching {
                os_log(.default, log: Regex.log, "%{PUBLIC}@", "\(String(repeating: " ", count: level))[\(cursor.index), \(cursor.character ?? "∅")] ᛦ")
            }

            let context = transition.perform(cursor, context)
            var newCursor = cursor

            // Capture a group if needed
            if case let .groupEnd(group)? = state.info,
                let startState = group.capturingStartState,
                let startIndex = cursor.groupsStartIndexes[startState],
                let groupIndex = captureGroups.firstIndex(of: startState) {
                newCursor.groups[groupIndex] = startIndex..<cursor.index
            } else {
                newCursor.groupsStartIndexes[state] = cursor.index
            }

            newCursor.index += consumed // Consume as many characters as need (zero for epsilon transitions)
        
            let match = firstMatch(newCursor, context, transition.toState, cache, isBranching ? level + 1 : level)

            if isBranching {
                os_log(.default, log: Regex.log, "%{PUBLIC}@", "\(String(repeating: " ", count: level))[\(newCursor.index), \(newCursor.character ?? "∅")] \(match == nil ? "✅" : "❌")")
            }

            if let match = match {
                cache[key] = .match(match)
                return match
            }
        }

        cache[key] = .failed
        return nil
    }
}

private extension Regex {
    private final class Cache {
        struct Key: Hashable {
            let index: Int
            let state: State
            let context: Context // TODO: verify whether this check is necessary
        }

        enum Entry {
            // TODO: I don't actually see scenarios where storing matches in
            // cache is useful, should probably be simplified.
            case match(Match)
            case failed

            func get() -> Match? {
                switch self {
                case let .match(match): return match
                case .failed: return nil
                }
            }
        }

        private var cache = [Key: Entry]()

        subscript(key: Key) -> Entry? {
            get { return cache[key] }
            set { cache[key] = newValue }
        }
    }
}

// MARK: - Regex.Match

public extension Regex {
    struct Match {
        public let fullMatch: Substring
        public let groups: [Substring]

        /// Index where the search ended.
        let endIndex: Int

        init(_ cursor: Cursor) {
            self.fullMatch = cursor.substring(cursor.range.lowerBound..<cursor.index)
            self.groups = cursor.groups
                .sorted(by: { $0.key < $1.key }) // Sort by the index of the group
                .map { $0.value }
                .map(cursor.substring)
            self.endIndex = cursor.index
        }
    }
}

// MARK: - Regex.Error

extension Regex {
    public struct Error: Swift.Error, LocalizedError {
        public let message: String
        public let index: Int
        public var pattern: String = ""

        init(_ message: String, _ index: Int) {
            self.message = message
            self.index = index
        }

        public var errorDescription: String? {
            return "\(message) in pattern: \(patternWithHighlightedError)"
        }

        public var patternWithHighlightedError: String {
            let i = pattern.index(pattern.startIndex, offsetBy: index)
            var s = pattern
            s.replaceSubrange(i...i, with: "\(s[i])💥")
            return s
        }
    }
}
