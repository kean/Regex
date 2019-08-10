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
        let matches = regex.matches(in: string).map { $0.value }

        XCTAssertEqual(matches, ["gray wolf ", "grey wall."])
    }

    func testCharacterClasses2() throws {
        let pattern = #"\b[A-Z]\w*\b"#
        let string = "A city Albany Zulu maritime Marseilles"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.value }

        XCTAssertEqual(matches, ["A", "Albany", "Zulu", "Marseilles"])
    }

    func testCharacterClasses3() throws {
        let pattern = #"\bth[^o]\w+\b"#
        let string = "thought thing though them through thus thorough this"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.value }

        XCTAssertEqual(matches, ["thing", "them", "through", "thus", "this"])
    }

    func testCharacterClasses4() throws {
        let pattern = #"\b.*[.?!;:](\s|\z)"#
        let string = "this. what: is? go, thing."

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.value }

        XCTAssertEqual(matches, ["this. what: is? go, thing."])
    }

    // TODO: add support for 'Sc' category
    func testCharacterClasses5() throws {
        let pattern = #"(\P{Sc})+"#
        let string = """
        $164,091.78
        £1,073,142.68
        73¢
        €120
        """

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.value }

        XCTAssertEqual(matches, ["164,091.78", "1,073,142.68", "73", "120"])
    }

    // TODO: add support for capture groups and matching the values of the capture groups
    func testCharacterClasses6() throws {
        let pattern = #"(\w)\1"#
        let string = "trellis seerlatter summer hoarse lesser aardvark stunned"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.value }

        XCTAssertEqual(matches, ["ll", "ee", "tt", "mm", "ss", "aa", "nn"])
    }

    /// This captures whitespaces, I think the author actually meant to use `(?:`
    /// (non-capturing group).
    func testCharacterClasses7() throws {
        let pattern = #"\b\w+(e)?s(\s|$)"#
        let string = "matches stores stops leave leaves"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.value }

        XCTAssertEqual(matches, ["matches ", "stores ", "stops ", "leaves"])
    }
}
