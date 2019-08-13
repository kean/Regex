// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

class QuantifierZeroOrMoreTests: XCTestCase {

    func testThrowsThePrecedingTokenIsNotQuantifiableErrorWhenRootEmpty() {
        XCTAssertThrowsError(try Regex("*")) { error in
            guard let error = (error as? Regex.Error) else {
                return XCTFail("Unexpected error")
            }
            XCTAssertEqual(error.message, "The preceeding token is not quantifiable")
        }
    }

    func testThrowsThePrecedingTokenIsNotQuantifiableErrorWhenTwoInARow() {
        XCTAssertNoThrow(try Regex("a**"))
    }

    func testAppliedToLiteralCharacter() throws {
        let regex = try Regex("a*")

        XCTAssertTrue(regex.isMatch(""))
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("aa"))
        XCTAssertTrue(regex.isMatch("ab"))
        // It will always match, see Anchors for more tests
    }

    func testAppliedToTheLatestLiteralCharacter() throws {
        let regex = try Regex("ab*")

        XCTAssertFalse(regex.isMatch(""))
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("aa"))
        XCTAssertTrue(regex.isMatch("ab"))
        XCTAssertTrue(regex.isMatch("ba"))
        XCTAssertTrue(regex.isMatch("abb"))
        XCTAssertFalse(regex.isMatch("b"))
    }

    func testTimesAppliedToTheLatestGroup() throws {
        let regex = try Regex("^(ab)*$")

        XCTAssertTrue(regex.isMatch(""))
        XCTAssertFalse(regex.isMatch("a"))
        XCTAssertFalse(regex.isMatch("aa"))
        XCTAssertTrue(regex.isMatch("ab"))
        XCTAssertFalse(regex.isMatch("ba"))
        XCTAssertFalse(regex.isMatch("abb"))
        XCTAssertFalse(regex.isMatch("b"))
        XCTAssertTrue(regex.isMatch("abab"))
    }

    func testReturnsEmptyMatches() throws {
        let regex = try Regex("(ab)*")
        let s = "a"

        let matches = regex.matches(in: s)

        // Expect to match two empty strings
        guard matches.count == 2 else {
              return XCTFail("Invalid number of matches")
        }

        do {
            let match = matches[0]
            XCTAssertEqual(match.fullMatch, "")
            XCTAssertEqual(match.fullMatch.startIndex, s.startIndex)
            XCTAssertEqual(match.fullMatch.endIndex, s.startIndex)
            XCTAssertTrue(match.groups.isEmpty)
        }

        do {
            let match = matches[1]
            XCTAssertEqual(match.fullMatch, "")
            XCTAssertEqual(match.fullMatch.startIndex, s.index(after: s.startIndex))
            XCTAssertEqual(match.fullMatch.endIndex, s.index(after: s.startIndex))
            XCTAssertTrue(match.groups.isEmpty)
        }
    }

    func testWithAnyCharacter() throws {
        let regex = try Regex(".*")

        XCTAssertTrue(regex.isMatch(""))
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("aa"))
        XCTAssertTrue(regex.isMatch("ab"))
    }
}

// Remaining quantifiers.
class QuantifiersTests: XCTestCase {

    func testOneOrMoreTimes() throws {
        let regex = try Regex("a+")

        XCTAssertFalse(regex.isMatch(""))
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("aa"))
        XCTAssertTrue(regex.isMatch("ab"))
        XCTAssertFalse(regex.isMatch("b"))
    }

    func testZeroOrOneTime() throws {
        let regex = try Regex("a?")

        XCTAssertTrue(regex.isMatch(""))
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("aa"))
        XCTAssertTrue(regex.isMatch("ab"))
        // It will always match, see Anchors for more tests
    }
}

class QuantifiersLazyModifierTests: XCTestCase {

    func testGreedyZeroOrMore() throws {
        let regex = try Regex("a*")
        let string = "aaaa"

        let matches = regex.matches(in: string).map { $0.fullMatch }

        // Expect it to match the entire string in one go.
        XCTAssertEqual(matches, ["aaaa", ""])
    }

    func _testLazyZeroOrMore() throws {
        let regex = try Regex("a*?")
        let string = "aaaa"

        let matches = regex.matches(in: string).map { $0.fullMatch }

        // Expect it to match as little of the input as possible in each go.
        XCTAssertEqual(matches, ["", "a", "", "a", "", "a", "", "a"])
    }
}
