// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

class CharacterClassesTests: XCTestCase {

    func testCharacter() throws {
        let regex = try Regex("a")
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("ba"))
        XCTAssertFalse(regex.isMatch("b"))
        XCTAssertFalse(regex.isMatch(""))
    }

    func testTwoCharactersInARow() throws {
        let regex = try Regex("ab")
        XCTAssertTrue(regex.isMatch("ab"))
        XCTAssertFalse(regex.isMatch("a"))
        XCTAssertFalse(regex.isMatch("ba"))
        XCTAssertFalse(regex.isMatch("b"))
        XCTAssertFalse(regex.isMatch(""))
    }

    func testAnyCharacter() throws {
        let regex = try Regex(".")
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("b"))
        XCTAssertFalse(regex.isMatch(""))
        XCTAssertFalse(regex.isMatch("\n"))
    }

    func testAnyCharacterMixedWithSomeCharacter() throws {
        let regex = try Regex(".a")
        XCTAssertTrue(regex.isMatch("aa"))
        XCTAssertTrue(regex.isMatch("ba"))
        XCTAssertFalse(regex.isMatch("av"))
        XCTAssertFalse(regex.isMatch(""))
    }
}

class CharacterGroupsTests: XCTestCase {

    func testSimpleCharacterGroup() throws {
        let regex = try Regex("[ab]")
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("b"))
        XCTAssertTrue(regex.isMatch("ab"))
        XCTAssertTrue(regex.isMatch("ca"))
        XCTAssertFalse(regex.isMatch("c"))
        XCTAssertFalse(regex.isMatch(""))
    }

    func testCharacterGroupOneCharacter() throws {
        let regex = try Regex("[a]")
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("ab"))
        XCTAssertFalse(regex.isMatch("c"))
        XCTAssertFalse(regex.isMatch(""))
    }

    func testInvertedSet() throws {
        let regex = try Regex("[^ab]")

        // Expect character set to be inverted
        XCTAssertFalse(regex.isMatch("a"))
        XCTAssertFalse(regex.isMatch("b"))
        XCTAssertTrue(regex.isMatch("c"))
        XCTAssertFalse(regex.isMatch(""))
        XCTAssertFalse(regex.isMatch("ab"))
    }

    func testInvertedSetKeywordInsideGroup() throws {
        let regex = try Regex("[a^]")

        // Expect `^` to be treated as a keyword
        XCTAssertTrue(regex.isMatch("^"))

        // Expect character set not to be inveted
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("ab"))
        XCTAssertFalse(regex.isMatch("b"))
        XCTAssertFalse(regex.isMatch(""))
    }

    func testKeywordsAreTreatedAsCharacters() throws {
        let regex = try Regex("[a()|*+?.[]")

        // Expect keywords to be treated as simple characters inside a
        // character group
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("("))
        XCTAssertTrue(regex.isMatch(")"))
        XCTAssertTrue(regex.isMatch("|"))
        XCTAssertTrue(regex.isMatch("*"))
        XCTAssertTrue(regex.isMatch("+"))
        XCTAssertTrue(regex.isMatch("?"))
        XCTAssertTrue(regex.isMatch("."))
        XCTAssertTrue(regex.isMatch("["))
        XCTAssertTrue(regex.isMatch("ab"))
        XCTAssertFalse(regex.isMatch("c"))
        XCTAssertFalse(regex.isMatch(""))
    }

    func testSpecialCharacterInsideCharacterGroups() throws {
        let regex = try Regex(#"[a\d]"#)

        // Expect special character (`\d` - digit) to work inside a character group
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("1"))
        XCTAssertTrue(regex.isMatch("ab"))
        XCTAssertFalse(regex.isMatch("c"))
        XCTAssertFalse(regex.isMatch(""))
    }

    // MARK: Error Handling

    func testThrowsMissingClosingBracket() {
        XCTAssertThrowsError(try Regex("[b")) { error in
            guard let error = (error as? Regex.Error) else {
                return XCTFail("Unexpected error")
            }
            XCTAssertEqual(error.message, "Character group missing closing bracket")
            XCTAssertEqual(error.index, 0)
        }
    }

    func testThrowsEmptyCharacterGroup() {
        XCTAssertThrowsError(try Regex("[]")) { error in
            guard let error = (error as? Regex.Error) else {
                return XCTFail("Unexpected error")
            }
            XCTAssertEqual(error.message, "Character group is empty")
            XCTAssertEqual(error.index, 0)
        }
    }

    func testThrowsEmptyCharacterGroupWithInvertedSet() {
        XCTAssertThrowsError(try Regex("[^]")) { error in
            guard let error = (error as? Regex.Error) else {
                return XCTFail("Unexpected error")
            }
            XCTAssertEqual(error.message, "Character group is empty")
            XCTAssertEqual(error.index, 0)
        }
    }

    func testThrowsUnescapedDelimeterMustBeEscapedWithBackslash() throws {
        XCTAssertThrowsError(try Regex("[/]")) { error in
            guard let error = (error as? Regex.Error) else {
                return XCTFail("Unexpected error")
            }
            XCTAssertEqual(error.message, "An unescaped delimiter must be escaped with a backslash")
            XCTAssertEqual(error.index, 1)
        }
    }
}

class CharacterClassesRangesTests: XCTestCase {

    func testAlphabet() throws {
        let regex = try Regex("[a-z]")
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("h"))
        XCTAssertTrue(regex.isMatch("z"))
        XCTAssertFalse(regex.isMatch("H"))
        XCTAssertFalse(regex.isMatch("1"))
        XCTAssertFalse(regex.isMatch("_"))
    }

    func testAlphabetUppercased() throws {
        let regex = try Regex("[A-Z]")
        XCTAssertTrue(regex.isMatch("A"))
        XCTAssertTrue(regex.isMatch("H"))
        XCTAssertTrue(regex.isMatch("Z"))
        XCTAssertFalse(regex.isMatch("h"))
        XCTAssertFalse(regex.isMatch("1"))
        XCTAssertFalse(regex.isMatch("_"))
    }

    func testIncompleteRangeAsLiterals() throws {
        let regex = try Regex("[a-]")

        // Expect a hyphen character (-) to be interpreted as the range separator
        // unless it is the first or last character of the group.
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("-"))
        XCTAssertFalse(regex.isMatch("c"))
        XCTAssertFalse(regex.isMatch("1"))
    }

    func testIncompleteRangeAsLiterals2() throws {
        let regex = try Regex("[-a]")

        // Expect a hyphen character (-) to be interpreted as the range separator
        // unless it is the first or last character of the group.
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("-"))
        XCTAssertFalse(regex.isMatch("c"))
        XCTAssertFalse(regex.isMatch("1"))
    }

    func testNoSpecialMeaningOutsideCharacterGroup() throws {
        let regex = try Regex("a-z")
        XCTAssertTrue(regex.isMatch("a-z"))
        XCTAssertFalse(regex.isMatch("b"))
        XCTAssertFalse(regex.isMatch("c"))
        XCTAssertFalse(regex.isMatch("_"))
    }

    func testNoSpecialMeaningOutsideCharacterGroup2() throws {
        let regex = try Regex("a-")
        XCTAssertTrue(regex.isMatch("a-"))
        XCTAssertTrue(regex.isMatch("a-z"))
        XCTAssertFalse(regex.isMatch("b"))
        XCTAssertFalse(regex.isMatch("c"))
        XCTAssertFalse(regex.isMatch("_"))
    }

    func testRangeWithASingleCharacterAlsoAllowed() throws {
        let regex = try Regex("[a-a]")
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertFalse(regex.isMatch("z"))
        XCTAssertFalse(regex.isMatch("H"))
        XCTAssertFalse(regex.isMatch("1"))
        XCTAssertFalse(regex.isMatch("_"))
    }

    func testThrowsMissingClosingBracket() {
        XCTAssertThrowsError(try Regex("[z-a]")) { error in
            guard let error = (error as? Regex.Error) else {
                return XCTFail("Unexpected error")
            }
            XCTAssertEqual(error.message, "Character range is out of order")
            XCTAssertEqual(error.index, 2)
        }
    }
}

class SpecialCharactersTests: XCTestCase {

    func testDigits() throws {
        let regex = try Regex("\\d")

        XCTAssertTrue(regex.isMatch("1"))
        XCTAssertFalse(regex.isMatch("a"))
    }

    func testNonDigits() throws {
        let regex = try Regex("\\D")

        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertFalse(regex.isMatch("1"))
    }

    func testWhitespaces() throws {
        let regex = try Regex("\\s")

        XCTAssertTrue(regex.isMatch(" "))
        XCTAssertTrue(regex.isMatch("\t"))
        XCTAssertFalse(regex.isMatch("a"))
    }

    func testNotWhitespaces() throws {
        let regex = try Regex("\\S")

        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertFalse(regex.isMatch(" "))
        XCTAssertFalse(regex.isMatch("\t"))
    }

    func testWordCharacters() throws {
        let regex = try Regex("\\w")

        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("F"))
        XCTAssertTrue(regex.isMatch("2"))
        XCTAssertTrue(regex.isMatch("_"))
        XCTAssertFalse(regex.isMatch(" "))
        XCTAssertFalse(regex.isMatch("/"))
        XCTAssertFalse(regex.isMatch("*"))
    }

    func testNotWordCharacters() throws {
        let regex = try Regex("\\W")

        XCTAssertFalse(regex.isMatch("a"))
        XCTAssertFalse(regex.isMatch("F"))
        XCTAssertFalse(regex.isMatch("2"))
        XCTAssertFalse(regex.isMatch("_"))
        XCTAssertTrue(regex.isMatch(" "))
        XCTAssertTrue(regex.isMatch("/"))
        XCTAssertTrue(regex.isMatch("*"))
    }

    func testThrowsInvalidSpecialCharacter() throws {
        XCTAssertThrowsError(try Regex("\\p")) { error in
            guard let error = (error as? Regex.Error) else {
                return XCTFail("Unexpected error")
            }
            XCTAssertEqual(error.message, "Invalid special character 'p'")
            XCTAssertEqual(error.index, 1)
        }
    }
}

class CharacterGroupsIntegrationTests: XCTestCase {

    func testMixingRangesAndSpecialCharacterInAGroup() throws {
        let regex = try Regex(#"[13-4\s]"#)

        XCTAssertTrue(regex.isMatch("1"))
        XCTAssertFalse(regex.isMatch("2"))
        XCTAssertTrue(regex.isMatch("3"))
        XCTAssertTrue(regex.isMatch("4"))
        XCTAssertTrue(regex.isMatch(" "))
        XCTAssertFalse(regex.isMatch("a"))
    }
}
