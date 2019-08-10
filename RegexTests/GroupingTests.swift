// The MIT License (MIT)
//
// Copyright (c) 2016-2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

class GroupingTests: XCTestCase {

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
            guard let error = (error as? Regex.Error) else {
                return XCTFail("Unexpected error")
            }
            XCTAssertEqual(error.message, "Unmatched closing parentheses")
            XCTAssertEqual(error.index, 1)
        }
    }

    func testThrowsUnmatchedParenthesisNested() throws {
        XCTAssertThrowsError(try Regex("a(b)c)d")) { error in
            guard let error = (error as? Regex.Error) else {
                return XCTFail("Unexpected error")
            }
            XCTAssertEqual(error.message, "Unmatched closing parentheses")
            XCTAssertEqual(error.index, 5)
        }
    }

    func testThrowsUnmatchedOpeningParanthesis() throws {
        XCTAssertThrowsError(try Regex("(a")) { error in
            guard let error = (error as? Regex.Error) else {
                return XCTFail("Unexpected error")
            }
            XCTAssertEqual(error.message, "Unmatched opening parentheses")
            XCTAssertEqual(error.index, 0)
        }
    }

    func testThrowsUnmatchedOpeningParanthesisNested() throws {
        XCTAssertThrowsError(try Regex("(a(b")) { error in
            guard let error = (error as? Regex.Error) else {
                return XCTFail("Unexpected error")
            }
            XCTAssertEqual(error.message, "Unmatched opening parentheses")
            XCTAssertEqual(error.index, 2)
        }
    }
}
