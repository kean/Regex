// The MIT License (MIT)
//
// Copyright (c) 2016-2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

class QuantifiersTests: XCTestCase {

    func testThrowsThePrecedingTokenIsNotQuantifiableErrorWhenRootEmpty() {
        XCTAssertThrowsError(try Regex("*")) { error in
            guard let error = (error as? Regex.Error) else {
                return XCTFail("Unexpected error")
            }
            XCTAssertEqual(error.message, "The preceeding token is not quantifiable")
            XCTAssertEqual(error.index, 0)
        }
    }

    func testThrowsThePrecedingTokenIsNotQuantifiableErrorWhenTwoInARow() {
        XCTAssertNoThrow(try Regex("a**"))
    }

    func testZeroOrMoreTimes() throws {
        let regex = try Regex("a*")
        XCTAssertTrue(regex.isMatch(""))
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("aa"))
        XCTAssertTrue(regex.isMatch("ab"))
        // It will always match, see Anchors for more tests
    }

    func testZeroOrMoreTimesWithAnotherGroupBeforeIt() throws {
        let regex = try Regex("ab*")
        XCTAssertFalse(regex.isMatch(""))
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("aa"))
        XCTAssertTrue(regex.isMatch("ab"))
        XCTAssertTrue(regex.isMatch("ba"))
        XCTAssertTrue(regex.isMatch("abb"))
        XCTAssertFalse(regex.isMatch("b"))
    }

    func testZeroOrMoreTimesWithAnyCharacter() throws {
        let regex = try Regex(".*")
        XCTAssertTrue(regex.isMatch(""))
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("aa"))
        XCTAssertTrue(regex.isMatch("ab"))
    }

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
