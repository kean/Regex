// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

class BackreferencesTests: XCTestCase {

    func testSimpleBackreference() throws {
        let pattern = #"(a)\1"#
        let string = "aa ab ba"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.fullMatch }

        XCTAssertEqual(matches, ["aa"])
    }

    func testBackreferenceWithGreedyQnatifiers() throws {
        let pattern = #"(a+)\1"#
        let string = "aaaaaa"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.fullMatch }

        XCTAssertEqual(matches, ["aaaaaa"])
    }

    func testReturnsNumberOfCapturingGroups() throws {
        let pattern = #"(\w)\1"#
        let string = "trellis seerlatter summer hoarse lesser aardvark stunned"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.fullMatch }

        XCTAssertEqual(matches, ["ll", "ee", "tt", "mm", "ss", "aa", "nn"])
    }

    // MARK: Error Reporting

    func testThrowsNonExistentSubpattern() throws {
        XCTAssertThrowsError(try Regex("(a)\\2")) { error in
            guard let error = (error as? Regex.Error) else { return }
            XCTAssertEqual(error.message, "The token '\\2' references a non-existent or invalid subpattern")
            XCTAssertEqual(error.index, 0)
        }
    }

    func testThrowsNonExistentSubpatternSubpatterns() throws {
        XCTAssertThrowsError(try Regex("ab\\1")) { error in
            guard let error = (error as? Regex.Error) else { return }
            XCTAssertEqual(error.message, "The token '\\1' references a non-existent or invalid subpattern")
        }
    }
}
