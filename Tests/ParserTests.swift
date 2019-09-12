// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
@testable import Regex

class ParserTests: XCTestCase {
    func parse(_ string: String) throws -> AST? {
        return try Parsers.regex.parse(string)
    }

    // MARK: Validation

    func testThrowsGroupMissingClosingParantheses() {
        XCTAssertThrowsError(try parse("a)")) { error in
             guard let error = (error as? ParserError) else { return }
             XCTAssertEqual(error.message, "Unmatched closing parentheses")
        }
    }
}

// MARK: - Expression

class ParserExpressionTests: XCTestCase {
    func parse(_ string: String) throws -> Any? {
        return try Parsers.expression.parse(string)
    }
}

// MARK: - Character Groups

class ParserCharacterGroupTests: XCTestCase {
    func parse(_ string: String) throws -> CharacterGroup? {
        return try Parsers.characterGroup.parse(string)
    }

    func testGroupNotInvertedByDefault() throws {
        let group =  try XCTUnwrap(parse("[a]"))
        XCTAssertFalse(group.isInverted)
    }

    func testInvertedGroup() throws {
        let group =  try XCTUnwrap(parse("[^a]"))
        XCTAssertTrue(group.isInverted)
    }

    // MARK: Validation

    func testThrowsMissingClosingBracket() {
        XCTAssertThrowsError(try parse("[a")) { error in
             guard let error = (error as? ParserError) else { return }
             XCTAssertEqual(error.message, "Character group missing closing bracket")
         }
    }

    func testThrowsCharacterGroupIsEmpty() {
        XCTAssertThrowsError(try parse("[]")) { error in
            guard let error = (error as? ParserError) else { return }
            XCTAssertEqual(error.message, "Character group is empty")
        }
    }
}

class ParserCharacterGroupItemTests: XCTestCase {
    func parse(_ string: String) throws -> CharacterGroup.Item? {
        return try Parsers.characterGroupItem.parse(string)
    }

    func testCharacter() throws {
        XCTAssertEqual(try parse("d"), CharacterGroup.Item.character("d"))
    }

    func testThrowsWhenEncountersUnescapedDelimeter() throws {
        XCTAssertThrowsError(try parse("/")) { error in
            guard let error = (error as? ParserError) else { return }
            XCTAssertEqual(error.message, "An unescaped delimiter must be escaped with a backslash")
        }
    }
}

class ParserCharacterClassTests: XCTestCase {
    func parse(_ string: String) throws -> CharacterSet? {
        return try Parsers.characterClass.parse(string)
    }

    func testSupportedCharacterClass() throws {
        XCTAssertNotNil(try parse("\\d"))
    }

    func testUnsupportedCharacterClass() throws {
        XCTAssertNil(try parse("\\y"))
    }
}

class ParserCharacterClassFromUnicodeCategoryTests: XCTestCase {
    func parse(_ string: String) throws -> CharacterSet? {
        return try Parsers.characterClassFromUnicodeCategory.parse(string)
    }

    func testSupportedCategory() throws {
        XCTAssertNotNil(try parse("\\p{P}"))
    }

    // MARK: Validation

    func testThrowsUnicodeCategoryMissingOpeningBrace() throws {
        XCTAssertThrowsError(try parse("\\pP}")) { error in
            guard let error = (error as? ParserError) else { return }
            XCTAssertEqual(error.message, "Missing unicode category name")
        }
    }

    func testThrowsUnicodeCategoryMissingBrace() throws {
        XCTAssertThrowsError(try parse("\\p{P")) { error in
            guard let error = (error as? ParserError) else { return }
            XCTAssertEqual(error.message, "Missing closing brace")
        }
    }

    func testThrowsMissingCategoryName() throws {
        XCTAssertThrowsError(try parse("\\p{}")) { error in
            guard let error = (error as? ParserError) else { return }
            XCTAssertEqual(error.message, "Missing unicode category name")
        }
    }

    func testThrowsUnsupportedCategory() throws {
        XCTAssertThrowsError(try parse("\\p{123}")) { error in
             guard let error = (error as? ParserError) else { return }
             XCTAssertEqual(error.message, "Unsupported unicode category '123'")
        }
    }
}

// MARK: - Groups

class ParserGroupTests: XCTestCase {
    func parse(_ string: String) throws -> Group? {
        return try Parsers.group.parse(string)
    }

    func testSimpleGroup() throws {
        let group = try XCTUnwrap(parse("(a)"))
        XCTAssertEqual(group.index, nil)
        XCTAssertEqual(group.isCapturing, true)
        XCTAssertTrue(group.children[0] is Match)
    }

    func testNonCapturingGroup() throws {
        let group = try XCTUnwrap(parse("(?:a)"))
        XCTAssertEqual(group.index, nil)
        XCTAssertEqual(group.isCapturing, false)
        XCTAssertTrue(group.children[0] is Match)
    }

    func testNestedGroup() throws {
        let group = try XCTUnwrap(parse("((a)b)"))
        XCTAssertEqual(group.index, nil)
        XCTAssertEqual(group.isCapturing, true)
    }

    // MARK: Validation

    func testThrowsGroupMissingOpeningParentheses() {
        XCTAssertThrowsError(try parse("(a")) { error in
             guard let error = (error as? ParserError) else { return }
             XCTAssertEqual(error.message, "Unmatched opening parentheses")
        }
    }

    func testThrowsIncompleteGroupStructure() {
        XCTAssertThrowsError(try parse("(")) { error in
             guard let error = (error as? ParserError) else { return }
             XCTAssertEqual(error.message, "Pattern must not be empty")
        }
    }
}

// MARK: - Quantifiers

class ParserQuantifierTests: XCTestCase {
    func parse(_ string: String) throws -> Quantifier? {
        return try Parsers.quantifier.parse(string)
    }

    func testZeroOrMore() throws {
        let quantifier = try parse("*")
        XCTAssertEqual(quantifier, Quantifier(type: .zeroOrMore, isLazy: false))
    }

    func testZeroOrMoreLazy() throws {
        let quantifier = try parse("*?")
        XCTAssertEqual(quantifier, Quantifier(type: .zeroOrMore, isLazy: true))
    }

    func testRangeLazy() throws {
        let quantifier = try parse("{1}?")
        let range = RangeQuantifier(lowerBound: 1, upperBound: 1)
        XCTAssertEqual(quantifier, Quantifier(type: .range(range), isLazy: true))
    }
}

// MARK: - Range Quantifier

class ParserRangeQuantifierTests: XCTestCase {
    func parse(_ string: String) throws -> RangeQuantifier? {
        return try Parsers.rangeQuantifier.parse(string)
    }

    func testComplete() throws {
        let quantifier = try XCTUnwrap(try parse("{1,2}"))

        XCTAssertEqual(quantifier.lowerBound, 1)
        XCTAssertEqual(quantifier.upperBound, 2)
    }

    func testUnbounded() throws {
        let quantifier = try XCTUnwrap(try parse("{1,}"))

        XCTAssertEqual(quantifier.lowerBound, 1)
        XCTAssertEqual(quantifier.upperBound, nil)
    }

    func testImplicitRightHandSide() throws {
        let quantifier = try XCTUnwrap(try parse("{1}"))

        XCTAssertEqual(quantifier.lowerBound, 1)
        XCTAssertEqual(quantifier.upperBound, 1)
    }

    // Compiler checks the semantics
    func testIgnoresSemantics() throws {
        let quantifier = try XCTUnwrap(try parse("{2,1}"))

        XCTAssertEqual(quantifier.lowerBound, 2)
        XCTAssertEqual(quantifier.upperBound, 1)
    }

    // MARK: Validation

    func testFailsMissingOpeningParentheses() throws {
        XCTAssertNil(try parse("1,2}"))
    }

    func testFailsMissingClosingParentheses() {
        XCTAssertNil(try parse("{1,2"))
    }

    func testFailsInvalidLowerBound() {
        XCTAssertNil(try parse("{a,2}"))
    }

    func testFailsInvalidUpperBound2() {
        XCTAssertNil(try parse("{b}"))
    }

    func testFailsInvalidUpperBound() {
        XCTAssertNil(try parse("{2,b}"))
    }

    func testFailsNegativeNumber() {
        XCTAssertNil(try parse("{-2}"))
    }
}
