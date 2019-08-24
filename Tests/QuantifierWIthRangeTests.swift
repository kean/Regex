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

    func testThrowsMissingClosingBracket() throws {
        XCTAssertThrowsError(try Regex("a{3")) { error in
            guard let error = (error as? Regex.Error) else { return }
            XCTAssertEqual(error.message, "Range quantifier missing closing bracket")
        }
    }

    func testThrowsBoundMustBeNoNegative() throws {
        XCTAssertThrowsError(try Regex("a{-3}")) { error in
            guard let error = (error as? Regex.Error) else { return }
            XCTAssertEqual(error.message, "Range quantifier must be more than zero")
        }
    }

    func testThrowsBoundMustBeNoNegative2() throws {
        XCTAssertThrowsError(try Regex("a{0}")) { error in
            guard let error = (error as? Regex.Error) else { return }
            XCTAssertEqual(error.message, "Range quantifier must be more than zero")
        }
    }

    func testThrowsMissingLowerBound() throws {
        XCTAssertThrowsError(try Regex("a{,3}")) { error in
            guard let error = (error as? Regex.Error) else { return }
            XCTAssertEqual(error.message, "Range quantifier missing lower bound")
        }
    }

    func testThrowsLowerBoundMustBeNoNegative() throws {
        XCTAssertThrowsError(try Regex("a{-1,2}")) { error in
            guard let error = (error as? Regex.Error) else { return }
            XCTAssertEqual(error.message, "Range quantifier lower bound must be non-negative")
        }
    }

    func testThrowsUpperBoundGreaterThanLower() throws {
        XCTAssertThrowsError(try Regex("a{3,2}")) { error in
            guard let error = (error as? Regex.Error) else { return }
            XCTAssertEqual(error.message, "Range quantifier upper bound must be greater than or equal than lower bound")
        }
    }

    func testThrowsMissingRange() throws {
        XCTAssertThrowsError(try Regex("a{}")) { error in
            guard let error = (error as? Regex.Error) else { return }
            XCTAssertEqual(error.message, "Range quantifier missing range")
        }
    }

    func testThrowsInvalidBound2() throws {
        XCTAssertThrowsError(try Regex("a{b}")) { error in
            guard let error = (error as? Regex.Error) else { return }
            XCTAssertEqual(error.message, "Range quantifier has invalid bound")
        }
    }

    func testThrowsInvalidLowerBound() throws {
        XCTAssertThrowsError(try Regex("a{b,2}")) { error in
            guard let error = (error as? Regex.Error) else { return }
            XCTAssertEqual(error.message, "Range quantifier has invalid lower bound")
        }
    }

    func testThrowsInvalidUpperBound() throws {
        XCTAssertThrowsError(try Regex("a{2,b}")) { error in
            guard let error = (error as? Regex.Error) else { return }
            XCTAssertEqual(error.message, "Range quantifier has invalid upper bound")
        }
    }
}
