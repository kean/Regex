// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

class OptimizationsTests: XCTestCase {
    // Expect the string to be compiled using a single state
    func testNearlyMatchingSubstring() throws {
        let regex = try Regex("aaaac")
        let string = "aaaaaaab"

        XCTAssertTrue(regex.matches(in: string).isEmpty)
    }
}
