// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

class BackreferencesTests: XCTestCase {

    func testReturnsNumberOfCapturingGroups() throws {
        let pattern = #"(\w)\1"#
        let string = "trellis seerlatter summer hoarse lesser aardvark stunned"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.fullMatch }

        XCTAssertEqual(matches, ["ll", "ee", "tt", "mm", "ss", "aa", "nn"])
    }
}
