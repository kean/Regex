// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

class CharacterEscapesTests: XCTestCase {

    func testEscapeOpeningParantheses() throws {
        let regex = try Regex(#"\("#)
        XCTAssertTrue(regex.isMatch("("))
    }

    func testEscapeBackslash() throws {
        let regex = try Regex(#"\\"#)
        XCTAssertTrue(regex.isMatch(#"\"#))
    }

    func testEspaceBracketsInsideCharacterGroup() throws {
        let regex = try Regex(#"[\[\]]"#)
        XCTAssertTrue(regex.isMatch("["))
        XCTAssertTrue(regex.isMatch("]"))
        XCTAssertFalse(regex.isMatch("a"))
    }

    func testThrowsEndingWithAtTrailingBackslash() throws {
        XCTAssertThrowsError(try Regex(#"\"#)) { error in
            guard let error = (error as? Regex.Error) else {
                return XCTFail("Unexpected error")
            }
            XCTAssertEqual(error.message, "Pattern may not end with a trailing backslash")
            XCTAssertEqual(error.index, 0)
        }
    }

    func testThrowsEndingWithAtTrailingBackslashInsideRange() throws {
        XCTAssertThrowsError(try Regex(#"[\"#)) { error in
            guard let error = (error as? Regex.Error) else {
                return XCTFail("Unexpected error")
            }
            XCTAssertEqual(error.message, "Pattern may not end with a trailing backslash")
            XCTAssertEqual(error.index, 1)
        }
    }
}
