// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

class AnchorMatchBeginningOfStringTests: XCTestCase {
    func testZeroOrMoreTimes() throws {
        let regex = try Regex("^a*")

        XCTAssertTrue(regex.isMatch(""))
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("aa"))
        XCTAssertTrue(regex.isMatch("ba"))
        XCTAssertTrue(regex.isMatch("ab"))
    }

    func testZeroOrOneTimeZeroOrOne() throws {
        let regex = try Regex("^a?")

        XCTAssertTrue(regex.isMatch(""))
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("aa"))
        XCTAssertTrue(regex.isMatch("ab"))
    }

    func testRange() throws {
        let regex = try Regex("^a{2,4}")

        XCTAssertFalse(regex.isMatch(""))
        XCTAssertFalse(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("aa"))
        XCTAssertTrue(regex.isMatch("aaa"))
        XCTAssertTrue(regex.isMatch("aaaa"))
        XCTAssertTrue(regex.isMatch("aaaaa"))
    }

    func testAlternation() throws {
        let regex = try Regex("^a|b")

        XCTAssertFalse(regex.isMatch(""))
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("b"))
        XCTAssertTrue(regex.isMatch("ab"))
        XCTAssertFalse(regex.isMatch("c"))
        XCTAssertFalse(regex.isMatch("ca"))
    }

    func testEither() throws {
        let regex = try Regex("^[ab]")

        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("b"))
        XCTAssertTrue(regex.isMatch("ab"))
        XCTAssertFalse(regex.isMatch("c"))
        XCTAssertFalse(regex.isMatch(""))
        XCTAssertFalse(regex.isMatch("ca"))
    }
}

// \A
class AnchorBeginningOfStringOnlyTests: XCTestCase {
    func testBeginningOfStringOnly() throws {
        let regex = try Regex(#"\Aa"#)

        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertFalse(regex.isMatch("b"))
        XCTAssertFalse(regex.isMatch("b\na"))
    }

    func testBeginningOfStringMultilineMode() throws {
        let regex = try Regex(#"^a"#, [.multiline])

        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertFalse(regex.isMatch("b"))
        XCTAssertTrue(regex.isMatch("b\na"))
    }

    func testBeginningOfStringOnlyIgnoresMultilineMode() throws {
        let regex = try Regex(#"\Aa"#, [.multiline])

        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertFalse(regex.isMatch("b"))
        XCTAssertFalse(regex.isMatch("b\na"))
    }
}

class AnchorMatchEndOfStringTests: XCTestCase {
    func testZeroOrMoreTimes() throws {
        let regex = try Regex("a*$")

        XCTAssertTrue(regex.isMatch(""))
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("aa"))
        XCTAssertTrue(regex.isMatch("ba"))
        XCTAssertFalse(regex.isMatch("ab"))
    }

    func testCharacters() throws {
        let regex = try Regex("ab$")

        XCTAssertFalse(regex.isMatch(""))
        XCTAssertFalse(regex.isMatch("a"))
        XCTAssertFalse(regex.isMatch("aa"))
        XCTAssertTrue(regex.isMatch("ab"))
    }

    func testMatchesNewlineAtTheEndOfString() throws {
        let regex = try Regex("a$")

        XCTAssertTrue(regex.isMatch("a\n"))
        XCTAssertFalse(regex.isMatch("a\nb"))
    }

    func testMatchesNewlineAtTheEndOfLine() throws {
        let regex = try Regex("a$", [.multiline])

        XCTAssertTrue(regex.isMatch("a\n"))
        XCTAssertTrue(regex.isMatch("a\nb"))
    }
}

// \Z
class AnchorEndOfStringOnlyTests: XCTestCase {
    func testEndOfStringOnly() throws {
        let regex = try Regex(#"a\Z"#)

        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("a\n"))
        XCTAssertFalse(regex.isMatch("b"))
        XCTAssertFalse(regex.isMatch("a\nb"))
    }

    func testEndOfStringMultilineMode() throws {
        let regex = try Regex(#"a$"#, [.multiline])

        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertFalse(regex.isMatch("b"))
        XCTAssertTrue(regex.isMatch("a\nb"))
    }

    func testEndOfStringOnlyIgnoresMultilineMode() throws {
        let regex = try Regex(#"a\Z"#, [.multiline])

        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("a\n"))
        XCTAssertFalse(regex.isMatch("b"))
        XCTAssertFalse(regex.isMatch("a\nb"))
    }
}

// \z
class AnchorEndOfStringOnlyNotNewlineTests: XCTestCase {
    func testEndOfStringOnly() throws {
        let regex = try Regex(#"a\z"#)

        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertFalse(regex.isMatch("a\n"))
        XCTAssertFalse(regex.isMatch("b"))
        XCTAssertFalse(regex.isMatch("a\nb"))
    }

    func testEndOfStringOnlyIgnoresMultilineMode() throws {
        let regex = try Regex(#"a\z"#, [.multiline])

        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertFalse(regex.isMatch("a\n"))
        XCTAssertFalse(regex.isMatch("b"))
        XCTAssertFalse(regex.isMatch("a\nb"))
    }
}

class MatchFromBothEndsTests: XCTestCase {
    func testZeroOrMoreTimes() throws {
        let regex = try Regex("^a*$")

        XCTAssertTrue(regex.isMatch(""))
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("aa"))
        XCTAssertFalse(regex.isMatch("ba"))
        XCTAssertFalse(regex.isMatch("ab"))
    }

    func testZeroOrOneTimeZeroOrOne() throws {
        let regex = try Regex("^a?$")

        XCTAssertTrue(regex.isMatch(""))
        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertFalse(regex.isMatch("aa"))
        XCTAssertFalse(regex.isMatch("ab"))
    }

    func testRange() throws {
        let regex = try Regex("^a{2,4}$")

        XCTAssertFalse(regex.isMatch(""))
        XCTAssertFalse(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("aa"))
        XCTAssertTrue(regex.isMatch("aaa"))
        XCTAssertTrue(regex.isMatch("aaaa"))
        XCTAssertFalse(regex.isMatch("aaaaa"))
    }

    func testBigRange() throws {
        let regex = try Regex("^a{12}$")

        XCTAssertFalse(regex.isMatch("aaaaaaaaaaa"))
        XCTAssertTrue(regex.isMatch("aaaaaaaaaaaa"))
        XCTAssertFalse(regex.isMatch("aaaaaaaaaaaaa"))
        XCTAssertFalse(regex.isMatch("a"))
    }

    func testCharacterSet() throws {
        let regex = try Regex("^[ab]$")

        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("b"))
        XCTAssertFalse(regex.isMatch("ab"))
        XCTAssertFalse(regex.isMatch("ca"))
        XCTAssertFalse(regex.isMatch("c"))
        XCTAssertFalse(regex.isMatch(""))
    }

    func testGroupingAndZeroOrOneQuantifier() throws {
        let regex = try Regex("^a(bc)?$")

        XCTAssertTrue(regex.isMatch("a"))
        XCTAssertTrue(regex.isMatch("abc"))
        XCTAssertFalse(regex.isMatch("ab"))
        XCTAssertFalse(regex.isMatch("abcd"))
        XCTAssertFalse(regex.isMatch("bda"))
    }
}

// \G
class MatchWherePreviousMatchEndedTests: XCTestCase {

    func testContiguosMatches() throws {
        let pattern = #"\G(\w+\s?\w*),?"#
        let string = "capybara,squirrel,chipmunk,porcupine,gopher,beaver,groundhog,hamster"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.value }

        // We can't currently capture groups so the match is a bit clunky.
        XCTAssertEqual(matches, ["capybara,", "squirrel,", "chipmunk,", "porcupine,", "gopher,", "beaver,", "groundhog,", "hamster"])
    }
}

// \b, \B
class MatchAtWordBoundaryTests: XCTestCase {

    func testMatchAtWordBoundary() throws {
        let regex = try Regex(#"\bab\b"#)

        XCTAssertTrue(regex.isMatch("ab"))
        XCTAssertTrue(regex.isMatch("a ab"))
        XCTAssertTrue(regex.isMatch("ab b"))
        XCTAssertFalse(regex.isMatch("aab"))
        XCTAssertFalse(regex.isMatch("abb"))
    }

    func testMatchAtWordBoundaryInverted() throws {
        let regex = try Regex(#"\Bab\B"#)

        XCTAssertFalse(regex.isMatch("ab"))
        XCTAssertFalse(regex.isMatch("a ab"))
        XCTAssertFalse(regex.isMatch("ab b"))
        XCTAssertFalse(regex.isMatch("aab"))
        XCTAssertFalse(regex.isMatch("abb"))
        XCTAssertTrue(regex.isMatch("cabc"))
        XCTAssertTrue(regex.isMatch("cabc"))
    }
}
