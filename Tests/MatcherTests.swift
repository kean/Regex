// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

class MatcherTests: XCTestCase {

    func testReturnsAllFoundMatches() throws {
        let pattern = "a"
        let string = "a b ab"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string)

        guard matches.count == 2 else {
            return XCTFail("Invalid number of matches")
        }

        do {
            let match = matches[0]
            XCTAssertEqual(match.fullMatch, "a")
            XCTAssertEqual(match.fullMatch.startIndex, string.index(offsetBy: 0))
            XCTAssertEqual(match.fullMatch.endIndex, string.index(offsetBy: 1))
        }

        do {
            let match = matches[1]
            XCTAssertEqual(match.fullMatch, "a")
            XCTAssertEqual(match.fullMatch.startIndex, string.index(offsetBy: 4))
            XCTAssertEqual(match.fullMatch.endIndex, string.index(offsetBy: 5))
        }
    }

    func testReturnsAllFoundMatches2() throws {
        let pattern = "a"
        let string = "a b a"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string)

        guard matches.count == 2 else {
            return XCTFail("Invalid number of matches")
        }

        do {
            let match = matches[0]
            XCTAssertEqual(match.fullMatch, "a")
            XCTAssertEqual(match.fullMatch.startIndex, string.index(offsetBy: 0))
            XCTAssertEqual(match.fullMatch.endIndex, string.index(offsetBy: 1))
        }

        do {
            let match = matches[1]
            XCTAssertEqual(match.fullMatch, "a")
            XCTAssertEqual(match.fullMatch.startIndex, string.index(offsetBy: 4))
            XCTAssertEqual(match.fullMatch.endIndex, string.index(offsetBy: 5))
        }
    }

    func testGreedyFindsAllMatches() throws {
        let pattern = #"\b(\w+)?\b"#
        let string = "Aa Bb Cc Dd Ee Ff"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.fullMatch }

        XCTAssertEqual(matches, ["Aa", "", "Bb", "", "Cc", "", "Dd", "", "Ee", "", "Ff", ""])
    }
}
