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
//
// Implementation Details
// ======================
//
// The key ideas behind the implementation are:
//
// - Every Regex can be transformed to State Machine
// - State Machine cab be executed using backtracking
//
// See https://swtch.com/~rsc/regexp/regexp1.html for more info.
//
public final class Regex {
    private let options: Options
    private let machine: Machine
    private static let log: OSLog = .disabled
    private var iterations = 0

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
            self.machine = try compiler.compile()
            self.options = options
            os_log(.default, log: Regex.log, "Machine: \n\n%{PUBLIC}@", machine.description)
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
                cursor = cursor.startingAt(match.rangeInCharacters.upperBound)
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
            if let match = firstMatch(cursor.startingAt(i), [:], machine.start, cache) {
                return match
            }
        }
        return nil
    }

    // A simple backtracking implementation with cache.
    private func firstMatch(_ cursor: Cursor, _ context: Context, _ state: State, _ cache: Cache, _ level: Int = 0) -> Match? {
        iterations += 1
        os_log(.default, log: Regex.log, "%{PUBLIC}@", "\(String(repeating: " ", count: level))[\(cursor.index), \(cursor.character ?? "∅")] \(state)")

        guard !state.isEnd else {
            return Match(cursor) // Found a match!
        }

        let key = Cache.Key(index: cursor.index, state: state, context: context)
        if let match = cache[key] {
            return match.get()
        }

        let isBranching = state.transitions.count > 1

        for transition in state.transitions {
            guard transition.condition(cursor, context) else {
                os_log(.default, log: Regex.log, "%{PUBLIC}@", "\(String(repeating: " ", count: level))[\(cursor.index), \(cursor.character ?? "∅")] \("❌")")
                continue
            }

            if isBranching {
                os_log(.default, log: Regex.log, "%{PUBLIC}@", "\(String(repeating: " ", count: level))[\(cursor.index), \(cursor.character ?? "∅")] ᛦ")
            }

            let context = transition.perform(context)
            var cursor = cursor
            if !transition.isEpsilon {
                cursor.index += 1 // Consume a character
            }
            let match = firstMatch(cursor, context, transition.toState, cache, isBranching ? level + 1 : level)

            if isBranching {
                os_log(.default, log: Regex.log, "%{PUBLIC}@", "\(String(repeating: " ", count: level))[\(cursor.index), \(cursor.character ?? "∅")] \(match == nil ? "✅" : "❌")")
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

private final class Cache {
    struct Key: Hashable {
        let index: Int
        let state: State
        let context: Context // TODO: verify whether this check is necessary
    }

    enum Entry {
        // TODO: I don't actually see scenarios where storing matches in
        // cache is useful, should probably be simplified.
        case match(Regex.Match)
        case failed

        func get() -> Regex.Match? {
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

// MARK: - Regex.Match

public extension Regex {
    struct Match {
        public let value: Substring
        public let range: Range<String.Index>
        let rangeInCharacters: Range<Int>

        init(_ cursor: Cursor) {
            let string = cursor.substring
            let lb = string.index(string.startIndex, offsetBy: cursor.range.lowerBound)
            let ub = string.index(string.startIndex, offsetBy: cursor.index)
            self.range = lb..<ub
            self.value = string[range]
            self.rangeInCharacters =  cursor.range.lowerBound..<cursor.index
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
