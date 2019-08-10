// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

class OptionsTests: XCTestCase {

    // MARK: .caseInsensitive

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

    // MARK: .multiline

    func testMultiline() throws {
        let pattern = #"^\d$"#
        let string = """
        1
        1b
        2
        """

        let regex = try Regex(pattern, [.multiline])
        let matches = regex.matches(in: string).map { $0.value }

        XCTAssertEqual(matches, ["1", "2"])
    }
}
