// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

class QuantifierWithRangeTests: XCTestCase {

    func testExactMatch() throws {
        let regex = try Regex("a{2}")

        XCTAssertFalse(regex.isMatch(""))
        XCTAssertFalse(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("aa"))
        XCTAssertTrue(regex.isMatch("aaa"))
        XCTAssertFalse(regex.isMatch("a"))
        XCTAssertFalse(regex.isMatch("ba"))
    }

    func testExactMatchAlternativeNotation() throws {
        let regex = try Regex("a{2,2}")

        XCTAssertTrue(regex.isMatch("aa"))
        XCTAssertTrue(regex.isMatch("baa"))
        XCTAssertTrue(regex.isMatch("aaa"))
        XCTAssertFalse(regex.isMatch(""))
        XCTAssertFalse(regex.isMatch("a"))
        XCTAssertFalse(regex.isMatch("ba"))
    }

    func testGreaterThanOrEqual() throws {
        let regex = try Regex("a{2,}")

        XCTAssertFalse(regex.isMatch(""))
        XCTAssertFalse(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("aa"))
        XCTAssertTrue(regex.isMatch("aaa"))
        XCTAssertTrue(regex.isMatch("aaaa"))
    }

    func testRange() throws {
        let regex = try Regex("a{2,4}")

        XCTAssertFalse(regex.isMatch(""))
        XCTAssertFalse(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("aa"))
        XCTAssertTrue(regex.isMatch("aaa"))
        XCTAssertTrue(regex.isMatch("aaaa"))
        XCTAssertTrue(regex.isMatch("aaaaa"))
        // See RegexMatchFromTheBeginningTests for more
    }

    func testRangeWithWordAnchor() throws {
        let regex = try Regex(#"\.[a-z]{2,6}\\b"#)

        XCTAssertFalse(regex.isMatch(".invalid"))

    }

    func testBigRange() throws {
        let regex = try Regex("a{12}")

        XCTAssertFalse(regex.isMatch("aaaaaaaaaaa"))
        XCTAssertTrue(regex.isMatch("aaaaaaaaaaaa"))
        XCTAssertFalse(regex.isMatch("bbaaaaaaaaaaa"))
        XCTAssertFalse(regex.isMatch("a"))
    }

    // MARK: - Validations

    func testMissingClosingBracketInterpetedLiterally() throws {
        let regex = try Regex("a{3")
        XCTAssertTrue(regex.isMatch("a{3"))
    }

    func testBoundMustBeNoNegativeInterpetedLiterally() throws {
        let regex = try Regex("a{-3}")
        XCTAssertTrue(regex.isMatch("a{-3}"))
    }

    func testMissingLowerBoundInterpetedLiterally() throws {
        let regex = try Regex("a{,3}")
        XCTAssertTrue(regex.isMatch("a{,3}"))
    }

    func testLowerBoundMustBeNoNegativeInterpetedLiterally() throws {
        let regex = try Regex("a{-1,2}")
        XCTAssertTrue(regex.isMatch("a{-1,2}"))
    }

    func testMissingRangeInterpetedLiterally() throws {
        let regex = try Regex("a{}")
        XCTAssertTrue(regex.isMatch("a{}"))
    }

    func testInvalidBound2InterpetedLiterally() throws {
        let regex = try Regex("a{b}")
        XCTAssertTrue(regex.isMatch("a{b}"))
    }

    func testInvalidLowerBoundInterpetedLiterally() throws {
        let regex = try Regex("a{b,2}")
        XCTAssertTrue(regex.isMatch("a{b,2}"))
    }

    func testInvalidUpperBoundInterpetedLiterally() throws {
        let regex = try Regex("a{2,b}")
        XCTAssertTrue(regex.isMatch("a{2,b}"))
    }

    func testThrowsUpperBoundGreaterThanLower() throws {
        XCTAssertThrowsError(try Regex("a{3,2}")) { error in
            guard let error = (error as? Regex.Error) else { return }
            XCTAssertEqual(error.message, "Invalid range quantifier. Upper bound must be greater than or equal than lower bound")
        }
    }
}
