// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

class IntegrationTests: XCTestCase {
    func testDigitsWithQuantifier() throws {
        let regex = try Regex(#"\d+"#)
        XCTAssertTrue(regex.isMatch("1"))
        XCTAssertTrue(regex.isMatch("12"))
        XCTAssertTrue(regex.isMatch("1a"))
        XCTAssertTrue(regex.isMatch("a2"))
        XCTAssertFalse(regex.isMatch("a"))
        XCTAssertFalse(regex.isMatch("bb++"))
    }
}
