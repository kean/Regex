// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

class OptionsTests: XCTestCase {

    func testCaseInsensitive() throws {
        let regex = try Regex("a", [.caseInsensitive])
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("A"))
        XCTAssertFalse(regex.isMatch("b"))
    }

    func testCaseInsensitiveWithCharacterGroups() throws {
        let regex = try Regex("[a-z]", [.caseInsensitive])
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("A"))
        XCTAssertTrue(regex.isMatch("b"))
        XCTAssertFalse(regex.isMatch("_"))
    }
}
