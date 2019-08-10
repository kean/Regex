// The MIT License (MIT)
//
// Copyright (c) 2016-2019 Alexander Grebenyuk (github.com/kean).

import Foundation
import os.log

// MARK: - Regex

// A simplified Regex implementation.
//
// Supported Features
// ==================
//
//   Character Escapes
//
// \ - before keyword escapes the keyword, e.g. '\{' means "match {". If used
//       inside the character group escapes the square brackets, e.g. "[\]]"
//       matches a closing square bracket.
// \ - before special character
//       - '\s' - whitespaces (inverted: '\S')
//       - '\d' - digits (inverted: '\D')
//       - '\w' - word character (inverted: '\W')
//
//   Character Classes
//
// a - matches a character
// . - any character
// [abc] - a character group matches either a or b or c
// [^abc] - a negated character group
// a-z - any character from a to z
//
//   Anchors
//
// ^ - matches the beginning of a string
// $ - matches the end of a string
// \b - the match must occur on a word boundary (non-word boundary: '\B')
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
// Reference used:
// https://docs.microsoft.com/en-us/dotnet/standard/base-types/regular-expression-language-quick-reference
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
        public static let caseInsensitive = Options(rawValue: 1 << 0)
    }

    public init(_ p: String, _ options: Options = []) throws {
        do {
            self.machine = try Compiler.compile(Array(p))
            self.options = options
            os_log(.default, log: Regex.log, "Machine: \n\n%{PUBLIC}@", machine.description)
        } catch {
            var error = error as! Error
            error.pattern = p // Attach additional context
            throw error
        }
    }

    public func isMatch(_ s: String) -> Bool {
        // Print number of iterations performed, this is for debug purporses only but
        // it is effectively the only thing making Regex non-thread-safe which we ignore.
        os_log(.default, log: Regex.log, "%{PUBLIC}@", "Started, input: \(s)")
        iterations = 0
        defer {
            os_log(.default, log: Regex.log, "%{PUBLIC}@", "Finished, iterations: \(iterations)")
        }


        let s = options.contains(.caseInsensitive) ? s.lowercased() : s
        let a = Array(s)
        guard !a.isEmpty else {
            // We still need to run the regex to check if regex matches the empty string
            return isMatchBacktracking(Cursor(string: a, index: 0), [:], machine.start, Cache(), 0)
        }
        return a.indices.contains { index in // Check from every index
            isMatchBacktracking(Cursor(string: a, index: index), [:], machine.start, Cache(), 0)
        }
    }

    // MARK: Match (Backtracking)

    // A simple backtracking implementation with cache.
    private func isMatchBacktracking(_ cursor: Cursor, _ context: Context, _ state: State, _ cache: Cache, _ level: Int) -> Bool {
        iterations += 1
        os_log(.default, log: Regex.log, "%{PUBLIC}@", "\(String(repeating: " ", count: level))[\(cursor.index), \(cursor.character ?? "∅")] \(state)")

        guard !state.isEnd else {
            return true // Found a match!
        }

        let key = Cache.Key(index: cursor.index, state: state)
        if let isMatch = cache[key] {
            return isMatch
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
                cursor.index += 1
            }
            let isMatch = isMatchBacktracking(cursor, context, transition.toState, cache, isBranching ? level + 1 : level)
            if isBranching {
                os_log(.default, log: Regex.log, "%{PUBLIC}@", "\(String(repeating: " ", count: level))[\(cursor.index), \(cursor.character ?? "∅")] \(isMatch ? "✅" : "❌")")
            }
            if isMatch {
                return true
            }
        }

        cache[key] = false
        return false
    }
}

private final class Cache {
    struct Key: Hashable {
        let index: Int
        let state: State
    }

    private var cache = [Key: Bool]()

    subscript(key: Key) -> Bool? {
        get { return cache[key] }
        set { cache[key] = newValue }
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
