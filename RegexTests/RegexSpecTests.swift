// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

/// Regex examples from https://docs.microsoft.com/en-us/dotnet/standard/base-types/regular-expressions
class RegexSpecTests: XCTestCase {

    // MARK: Character Classes
    // https://docs.microsoft.com/en-us/dotnet/standard/base-types/character-classes-in-regular-expressions

    func testCharacterClasses1() throws {
        let pattern = #"gr[ae]y\s\S+?[\s\p{P}]"#
        let string = "The gray wolf jumped over the grey wall."

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.fullMatch }

        XCTAssertEqual(matches, ["gray wolf ", "grey wall."])
    }

    func testCharacterClasses2() throws {
        let pattern = #"\b[A-Z]\w*\b"#
        let string = "A city Albany Zulu maritime Marseilles"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.fullMatch }

        XCTAssertEqual(matches, ["A", "Albany", "Zulu", "Marseilles"])
    }

    func testCharacterClasses3() throws {
        let pattern = #"\bth[^o]\w+\b"#
        let string = "thought thing though them through thus thorough this"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.fullMatch }

        XCTAssertEqual(matches, ["thing", "them", "through", "thus", "this"])
    }

    func testCharacterClasses4() throws {
        let pattern = #"\b.*[.?!;:](\s|\z)"#
        let string = "this. what: is? go, thing."

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.fullMatch }

        XCTAssertEqual(matches, ["this. what: is? go, thing."])
    }

    // TODO: add support for 'Sc' category
    func _testCharacterClasses5() throws {
        let pattern = #"(\P{Sc})+"#
        let string = """
        $164,091.78
        £1,073,142.68
        73¢
        €120
        """

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.fullMatch }

        XCTAssertEqual(matches, ["164,091.78", "1,073,142.68", "73", "120"])
    }

    /// This captures whitespaces, I think the author actually meant to use `(?:`
    /// (non-capturing group).
    func testCharacterClasses6() throws {
        let pattern = #"\b\w+(e)?s(\s|$)"#
        let string = "matches stores stops leave leaves"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.fullMatch }

        XCTAssertEqual(matches, ["matches ", "stores ", "stops ", "leaves"])
    }

    // MARK: Groups
    // https://docs.microsoft.com/en-us/dotnet/standard/base-types/grouping-constructs-in-regular-expressions

    func testCaptureGroups1() throws {
        let pattern = #"(\d{3})-(\d{3}-\d{4})"#
        let string = "212-555-6666 906-932-1111 415-222-3333"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string)

        guard matches.count == 3 else {
            return XCTFail("Invalid number of matches")
        }

        do {
            let match = matches[0]
            XCTAssertEqual(match.fullMatch, "212-555-6666")
            XCTAssertEqual(match.groups, ["212", "555-6666"])
        }

        do {
            let match = matches[1]
            XCTAssertEqual(match.fullMatch, "906-932-1111")
            XCTAssertEqual(match.groups, ["906", "932-1111"])
        }

        do {
            let match = matches[2]
            XCTAssertEqual(match.fullMatch, "415-222-3333")
            XCTAssertEqual(match.groups, ["415", "222-3333"])
        }
    }
}
