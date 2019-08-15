// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

class AlternationConstructsTests: XCTestCase {

    func testAlternation() throws {
        let regex = try Regex("a|b")

        XCTAssertFalse(regex.isMatch(""))
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("b"))
        XCTAssertTrue(regex.isMatch("ab"))
        XCTAssertTrue(regex.isMatch("ca"))
        XCTAssertFalse(regex.isMatch("c"))
    }

    func testAlternationMultipleOptions() throws {
        let regex = try Regex("a|b|cd")

        XCTAssertFalse(regex.isMatch(""))
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("b"))
        XCTAssertTrue(regex.isMatch("cd"))
        XCTAssertTrue(regex.isMatch("ab"))
        XCTAssertTrue(regex.isMatch("acd"))
        XCTAssertFalse(regex.isMatch("c"))
        XCTAssertFalse(regex.isMatch("dc"))
    }

    func testAlternationsWithGroup() throws {
        let regex = try Regex("a(b|c)")

        XCTAssertFalse(regex.isMatch(""))
        XCTAssertTrue(regex.isMatch("ab"))
        XCTAssertTrue(regex.isMatch("ac"))
        XCTAssertTrue(regex.isMatch("abc"))
        XCTAssertFalse(regex.isMatch("c"))
        XCTAssertFalse(regex.isMatch("ad"))
    }

    func testNestedAlternations() throws {
        let regex = try Regex("(a|b(c|d))")

        XCTAssertFalse(regex.isMatch(""))
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("bc"))
        XCTAssertTrue(regex.isMatch("bd"))
        XCTAssertTrue(regex.isMatch("ab"))
        XCTAssertTrue(regex.isMatch("abc"))
        XCTAssertTrue(regex.isMatch("abd"))
        XCTAssertTrue(regex.isMatch("ad"))
        XCTAssertTrue(regex.isMatch("ac"))
        XCTAssertTrue(regex.isMatch("bcf"))
        XCTAssertFalse(regex.isMatch("b"))
        XCTAssertFalse(regex.isMatch("db"))
    }

    func testAlternationInitEmptyFirstImplititGroup() {
        XCTAssertThrowsError(try Regex("|b")) { error in
            guard let error = (error as? Regex.Error) else { return }
            XCTAssertEqual(error.message, "Pattern must not be empty")
        }
    }

    func testAlternationInitThrows() throws {
        XCTAssertThrowsError(try Regex("(|b)")) { error in
            guard let error = (error as? Regex.Error) else { return }
            XCTAssertEqual(error.message, "Pattern must not be empty")
        }
    }
}
