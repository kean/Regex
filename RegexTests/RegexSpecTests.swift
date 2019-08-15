// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

/// Example of regular expression from https://docs.microsoft.com/en-us/dotnet/standard/base-types/regular-expressions
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

    // MARK: Quantifiers
    // https://docs.microsoft.com/en-us/dotnet/standard/base-types/quantifiers-in-regular-expressions

    // Match Zero or More Times: *
    func testQuantifiers1() throws {
        let pattern = #"\b91*9*\b"#
        let string = "99 95 919 929 9119 9219 999 9919 91119"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.fullMatch }

        XCTAssertEqual(matches, ["99", "919", "9119", "999", "91119"])
    }

    // Match One or More Times: +
    func testQuantifiers2() throws {
        let pattern = #"\ban+\w*?\b"#
        let string = "Autumn is a great time for an annual announcement to all antique collectors."

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.fullMatch }

        XCTAssertEqual(matches, ["an", "annual", "announcement", "antique"])
    }

    // Match Zero or One Time: ?
    func testQuantifiers3() throws {
        let pattern = #"\ban?\b"#
        let string = "An amiable animal with a large snount and an animated nose."

        let regex = try Regex(pattern, [.caseInsensitive])
        let matches = regex.matches(in: string).map { $0.fullMatch }

        XCTAssertEqual(matches, ["An", "a", "an"])
    }

    // Match Exactly n Times: {n}
    func testQuantifier4() throws {
        let pattern = #"\b\d+\,\d{3}\b"#
        let string = "Sales totaled 103,524 million in January, 106,971 million in February, but only 943 million in March."

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.fullMatch }

        XCTAssertEqual(matches, ["103,524", "106,971"])
    }

    // Match at Least n Times: {n,}
    func testQuantifier5() throws {
        let pattern = #"\b\d{2,}\b\D+"#
        let string = "7 days, 10 weeks, 300 years"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.fullMatch }

        XCTAssertEqual(matches, ["10 weeks, ", "300 years"])
    }

    // Match Between n and m Times: {n,m}
    func testQuantifier6() throws {
        let pattern = #"(00\s){2,4}"#
        let string = "0x00 FF 00 00 18 17 FF 00 00 00 21 00 00 00 00 00"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.fullMatch }

        XCTAssertEqual(matches, ["00 00 ", "00 00 00 ", "00 00 00 00 "])
    }

    // Match Zero or More Times (Lazy Match): *?
    func testQuantifier7() throws {
        let pattern = #"\b\w*?oo\w*?\b"#
          let string = "woof root root rob oof woo woe"

          let regex = try Regex(pattern)
          let matches = regex.matches(in: string).map { $0.fullMatch }

          XCTAssertEqual(matches, ["woof", "root", "root", "oof", "woo"])
    }

    // Match One or More Times (Lazy Match): +?
    func testQuantifier8() throws {
        let pattern = #"\b\w+?\b"#
        let string = "Aa Bb Cc Dd Ee Ff"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.fullMatch }

        XCTAssertEqual(matches, ["Aa", "Bb", "Cc", "Dd", "Ee", "Ff"])
    }

    // Match Exactly n Times (Lazy Match): {n}?
    func testQuantifier9() throws {
        let pattern = #"\b(\w{3,}?\.){2}?\w{3,}?\b"#
        let string = "www.apple.com developer.apple.com mywebsite mycompany.com"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.fullMatch }

        XCTAssertEqual(matches, ["www.apple.com", "developer.apple.com"])
    }
}
