// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

class QuantifierZeroOrMoreTests: XCTestCase {

    func testThrowsThePrecedingTokenIsNotQuantifiableErrorWhenRootEmpty() {
        XCTAssertThrowsError(try Regex("*")) { error in
            guard let error = (error as? Regex.Error) else { return }
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
        let pattern = try Regex("(ab)*")
        let string = "a"

        let matches = pattern.matches(in: string)

        // Expect to match two empty strings
        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches.map { $0.fullMatch }.map(string.range(of:)), [0..<0, 1..<1])
        XCTAssertEqual(matches.map { $0.groups.isEmpty }, [true, true])
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

    // MARK: ZeroOrMore

    func testGreedyZeroOrMore() throws {
        let regex = try Regex("a*")
        let string = "aaaa"

        let matches = regex.matches(in: string).map { $0.fullMatch }

        // Expect it to match the entire string in one go.
        XCTAssertEqual(matches, ["aaaa", ""])
        XCTAssertEqual(matches.map(string.range(of:)), [0..<4, 4..<4])
    }

    /// This is a tricky scenario which works differently in different languages
    /// and depend on the matcher details. In NSRegularExpression and other popular
    /// regex engines like the ones found in JavaScript, Python and Go, this scenario
    /// produces 5 matches. This is the same number of matches, that `Regex` produces.
    /// PCRE on the other hand finds 12 matches. This isn't something that I would
    /// expect, actually. It seems that when PCRE matcher founds a match, it tries
    /// to find the next match by backtracking a checking other alternations if
    /// there are any. In other implementations after the match is found, the FSM
    /// is re-started from the index right after the match.
    func testLazyZeroOrMore() throws {
        let regex = try Regex("a*?")
        let string = "aaaa"

        let matches = regex.matches(in: string).map { $0.fullMatch }

        // Expect it to match as little of the input as possible in each go.
        XCTAssertEqual(matches.count, 5)
        XCTAssertEqual(matches, ["", "", "", "", ""])
        XCTAssertEqual(matches.map(string.range(of:)), [0..<0, 1..<1, 2..<2, 3..<3, 4..<4])
    }

    // MARK: RangeQuantifier

    func testGreedyRangeQuantifier() throws {
        let regex = try Regex("a{1,3}")
        let string = "aaaa"

        let matches = regex.matches(in: string).map { $0.fullMatch }

        // Expect it to match as little of the input as possible in each go.
        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches, ["aaa", "a"])
        XCTAssertEqual(matches.map(string.range(of:)), [0..<3, 3..<4])
    }

    func testLazyRangeQuantifier() throws {
        let regex = try Regex("a{1,3}?")
        let string = "aaaa"

        let matches = regex.matches(in: string).map { $0.fullMatch }

        // Expect it to match as little of the input as possible in each go.
        XCTAssertEqual(matches, ["a", "a", "a", "a"])
        XCTAssertEqual(matches.map(string.range(of:)), [0..<1, 1..<2, 2..<3, 3..<4])
    }

    func testGreedyRangeQuantifierZerOrMore() throws {
        let regex = try Regex("a{2,}")
        let string = "aaaa"

        let matches = regex.matches(in: string).map { $0.fullMatch }

        XCTAssertEqual(matches, ["aaaa"])
        XCTAssertEqual(matches.map(string.range(of:)), [0..<4])
    }
}
