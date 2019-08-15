// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation
import os.log

// Inclde this file into compilation to replace `Regex` implementation with the
// one backed by `NSRegularExpression`.

// MARK: - Regex

public final class Regex {
    public static var isDebugModeEnabled = false

    public var numberOfCaptureGroups: Int {
        return regex.numberOfCaptureGroups
    }

    private let regex: NSRegularExpression

    public struct Options: OptionSet {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let caseInsensitive = Options(rawValue: 1 << 0)
        public static let multiline = Options(rawValue: 1 << 1)
        public static let dotMatchesLineSeparators = Options(rawValue: 1 << 2)
    }

    public init(_ pattern: String, _ options: Options = []) throws {
        var ops = NSRegularExpression.Options()
        if options.contains(.caseInsensitive) { ops.insert(.caseInsensitive) }
        if options.contains(.multiline) { ops.insert(.anchorsMatchLines) }
        if options.contains(.dotMatchesLineSeparators) { ops.insert(.dotMatchesLineSeparators)}

        self.regex = try NSRegularExpression(pattern: pattern, options: ops)
    }

    public func isMatch(_ s: String) -> Bool {
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        return regex.firstMatch(in: s, options: [], range: range) != nil
    }

    public func matches(in s: String) -> [Match] {
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        let matches = regex.matches(in: s, options: [], range: range)
        return matches.map { match in
            let ranges = (0..<match.numberOfRanges)
                .map { match.range(at: $0) }
                .filter { $0.location != NSNotFound }
            return Match(fullMatch: s[Range(match.range, in: s)!],
                         groups: ranges.dropFirst().map { s[Range($0, in: s)!] }
            )
        }
    }
}

public extension Regex {
    struct Match {
        public let fullMatch: Substring
        public let groups: [Substring]
    }
}

extension Regex {
    public struct Error: Swift.Error, LocalizedError {
        public let message: String
        public let index: Int
        public var pattern: String = ""
    }
}
