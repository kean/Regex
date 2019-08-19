// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation
import os.log

// MARK: - Regex

public final class Regex {
    private let options: Options
    private let regex: CompiledRegex

    #if DEBUG
    private let log: OSLog = Regex.isDebugModeEnabled ? OSLog(subsystem: "com.github.kean.regex", category: "default") : .disabled
    private var iterations = 0
    #endif

    /// Returns the number of capture groups in the regular expression.
    public var numberOfCaptureGroups: Int {
        return captureGroups.count
    }

    /// An array of capture groups in an order in which they appear in the pattern.
    private var captureGroups: [CaptureGroup] {
        return regex.captureGroups
    }

    /// Enable debug mode to enable logging.
    public static var isDebugModeEnabled = false

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
            let ast = try Parser(pattern).parse()
            self.regex = try Compiler(ast, options).compile()
            self.options = options
            #if DEBUG
            if self.log.isEnabled { os_log(.default, log: self.log, "Expression: \n%{PUBLIC}@", regex.states[0].description(regex.symbols)) }
            #endif
        } catch {
            var error = error as! Error
            error.pattern = pattern // Attach additional context
            throw error
        }
    }

    /// Determine whether the regular expression pattern occurs in the input text.
    public func isMatch(_ string: String) -> Bool {
        return makeMatcher(for: string, ignoreCaptureGroups: true).firstMatch(in: string) != nil
    }

    /// Returns first match in the given string.
    public func firstMatch(in string: String) -> Match? {
        return makeMatcher(for: string).firstMatch(in: string)
    }

    /// Returns an array containing all the matches in the string.
    public func matches(in string: String) -> [Match] {
        var matches = [Match]()
        makeMatcher(for: string).forMatch(in: string) { match in
            matches.append(match)
            return true // Continue finding matches
        }
        return matches
    }

    /// - paramter ignoreCaptureGroups: enables some performance optimizations
    private func makeMatcher(for string: String, ignoreCaptureGroups: Bool = false) -> Matcher {
        return Matcher(regex: regex, options: options, ignoreCaptureGroups: ignoreCaptureGroups)
    }
}

// MARK: - Regex.Match

public extension Regex {
    struct Match {
        /// A full match.
        ///
        /// Substrings are only intended for short-term storage because they keep
        /// a reference to the original String. When the match is complete and you
        /// want to store the results or pass them on to another subsystem,
        /// you should create a new String from a match substring.
        public let fullMatch: Substring

        public let groups: [Substring]

        /// Index where the search ended.
        let endIndex: String.Index

        init(_ cursor: Cursor, _ hasCaptureGroups: Bool) {
            self.fullMatch = cursor.string[cursor.startIndex..<cursor.index]
            if hasCaptureGroups {
                self.groups = cursor.groups
                    .sorted(by: { $0.key < $1.key }) // Sort by the index of the group
                    .map { cursor.string[$0.value] }
            } else {
                self.groups = []
            }
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
