// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

class CapturingGroupsTests: XCTestCase {

    func testSimpleGroup() throws {
        let pattern = "(a)"
        let string = "a b"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string)

        guard matches.count == 1 else {
            return XCTFail("Invalid number of matches")
        }

        do {
            let match = matches[0]
            XCTAssertEqual(match.fullMatch, "a")
            XCTAssertEqual(match.groups, ["a"])
        }
    }

    func testNestedGroups() throws {
        let pattern = "((a)(b)c)"
        let string = "abc abd"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string)

        guard matches.count == 1 else {
            return XCTFail("Invalid number of matches")
        }

        do {
            let match = matches[0]
            XCTAssertEqual(match.fullMatch, "abc")
            XCTAssertEqual(match.groups, ["abc", "a", "b"])
        }
    }

    func testReturnsNumberOfCapturingGroups() throws {
        let regex = try Regex(#"(\w+)\s+(car)"#)

        XCTAssertEqual(regex.numberOfCaptureGroups, 2)
    }

    func testNoCaptureGroups() throws {
        let regex = try Regex("car")

        // Expect implicit group to not be counted as a capture group
        XCTAssertEqual(regex.numberOfCaptureGroups, 0)
    }

    func testOneCaptureGroup() throws {
        let regex = try Regex("(\\w+)")

        // Expect implicit group to not be counted as a capture group
        XCTAssertEqual(regex.numberOfCaptureGroups, 1)
    }

    func testCapturingGroups() throws {
        let pattern = #"(\w+)\s+(car)"#
        let string = "Green car red car blue car"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string)

        guard matches.count == 3 else {
            return XCTFail("Invalid number of matches")
        }

        do {
            let match = matches[0]
            XCTAssertEqual(match.fullMatch, "Green car")
            XCTAssertEqual(match.groups, ["Green", "car"])
        }

        do {
            let match = matches[1]
            XCTAssertEqual(match.fullMatch, "red car")
            XCTAssertEqual(match.groups, ["red", "car"])
        }

        do {
            let match = matches[2]
            XCTAssertEqual(match.fullMatch, "blue car")
            XCTAssertEqual(match.groups, ["blue", "car"])
        }
    }

    func testCapturingGroupWithQuantifier() throws {
        let pattern = #"(\w+)+\s+(car)"#
        let string = "Purple green car red car blue car"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string)

        guard matches.count == 3 else {
            return XCTFail("Invalid number of matches")
        }

        // Expect a repeated capturing group will only capture the last iteration.
        do {
            let match = matches[0]
            XCTAssertEqual(match.fullMatch, "green car")
            XCTAssertEqual(match.groups, ["green", "car"])
        }

        do {
            let match = matches[1]
            XCTAssertEqual(match.fullMatch, "red car")
            XCTAssertEqual(match.groups, ["red", "car"])
        }

        do {
            let match = matches[2]
            XCTAssertEqual(match.fullMatch, "blue car")
            XCTAssertEqual(match.groups, ["blue", "car"])
        }
    }

    // MARK: Nesting

    func testNestedCapturingGroupsReportsCorrectCapturingGroupCount() throws {
        let pattern = #"the ((red|white) (king|queen))"#
        let regex = try Regex(pattern)

        XCTAssertEqual(regex.numberOfCaptureGroups, 3)
    }

    func testNestedCapturingGroups() throws {
        let pattern = #"the ((red|white) (king|queen))"#
        let string = "the red queen"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string)

        guard matches.count == 1 else {
            return XCTFail("Invalid number of matches")
        }

        let match = matches[0]
        XCTAssertEqual(match.fullMatch, "the red queen")
        XCTAssertEqual(match.groups, ["red queen", "red", "queen"])
    }

    // MARK: Non-Capturing Groups

    func testNonCapturingGroup() throws {
        let pattern = "(?:a)"
        let string = "a b"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string)

        guard matches.count == 1 else {
            return XCTFail("Invalid number of matches")
        }

        do {
            let match = matches[0]
            XCTAssertEqual(match.fullMatch, "a")
            XCTAssertEqual(match.groups, [])
        }
    }

    func testNonCapturingGroupWithAlternations() throws {
        let pattern = #"the (?:(red|white) (king|queen))"#
        let string = "the red queen"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string)

        guard matches.count == 1 else {
            return XCTFail("Invalid number of matches")
        }

        let match = matches[0]
        XCTAssertEqual(match.fullMatch, "the red queen")
        XCTAssertEqual(match.groups, ["red", "queen"])
    }
}

class GroupsWithQuantifiersTests: XCTestCase {

    func testGrouping() throws {
        let regex = try Regex("(a)")
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertFalse(regex.isMatch("b"))
        XCTAssertFalse(regex.isMatch(""))
    }

    func testGroupingAndZeroOrOneQuantifier() throws {
        let regex = try Regex("a(bc)?")
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("abc"))
        XCTAssertTrue(regex.isMatch("ab"))
        XCTAssertTrue(regex.isMatch("abcd"))
        XCTAssertTrue(regex.isMatch("bda"))
        XCTAssertFalse(regex.isMatch("b"))
    }

    func testMultipleGroupLayers() throws {
        let regex = try Regex("((ab)+(cd)?)+")
        XCTAssertTrue(regex.isMatch("ab"))
        XCTAssertTrue(regex.isMatch("abcd"))
        XCTAssertTrue(regex.isMatch("ababcd"))
        XCTAssertTrue(regex.isMatch("abab"))
        XCTAssertTrue(regex.isMatch("abcdabcdab"))
        XCTAssertTrue(regex.isMatch("abc"))
        XCTAssertTrue(regex.isMatch("abcda"))
        XCTAssertTrue(regex.isMatch("abcdad"))
        XCTAssertFalse(regex.isMatch("a"))
        XCTAssertFalse(regex.isMatch("ac"))
    }

    // MARK: - Error Handling

    func testThrowsUnmatchedParenthesis() throws {
        XCTAssertThrowsError(try Regex("a)")) { error in
            guard let error = (error as? Regex.Error) else { return }
            XCTAssertEqual(error.message, "Unmatched closing parentheses")
        }
    }

    func testThrowsUnmatchedParenthesisNested() throws {
        XCTAssertThrowsError(try Regex("a(b)c)d")) { error in
            guard let error = (error as? Regex.Error) else { return }
            XCTAssertEqual(error.message, "Unmatched closing parentheses")
        }
    }

    func testThrowsUnmatchedOpeningParanthesis() throws {
        XCTAssertThrowsError(try Regex("(a")) { error in
            guard let error = (error as? Regex.Error) else { return }
            XCTAssertEqual(error.message, "Unmatched opening parentheses")
        }
    }

    func testThrowsUnmatchedOpeningParanthesisNested() throws {
        XCTAssertThrowsError(try Regex("(a(b")) { error in
            guard let error = (error as? Regex.Error) else { return }
            XCTAssertEqual(error.message, "Unmatched opening parentheses")
        }
    }
}
