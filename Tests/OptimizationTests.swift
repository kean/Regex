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

    func testNearlyMatpching() throws {
        let regex = try Regex("a{10}c")
        let string = String(repeating: "a", count: 15) + "c" + String(repeating: "a", count: 100) + "b"

        let matches = regex.matches(in: string).map { $0.fullMatch }
        XCTAssertEqual(matches.map(string.range(of:)), [5..<16])
    }
}
