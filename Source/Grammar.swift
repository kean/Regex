// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

extension Parsers {

    static let regex = (optional("^") <*> expression <* endOfPattern).map(AST.init)

    static let endOfPattern = oneOf(
        end, // Parsed the entire string, we are good
        string(")").zero.orThrow("Unmatched closing parentheses") // Make sure no unmatched parentheses left!
    )

    // MARK: - Expression

    /// The entry point for parsing any regex expression. The right side is
    /// defined recursively.
    static let expression = (subexpression <*> optional("|" *> _expression)).map(makeExpression)

    static func makeExpression(_ lhs: Unit, _ rhs: Unit?) -> Unit {
        guard let rhs = rhs else { return lhs }
        return Alternation(children: [lhs, rhs]) // Optimizer later transforms tree into array
    }

    /// Wraps `expression` parser into a closure to allow us to define `expression` recursively
    static let _expression: Parser<Unit> = lazy(expression)

    /// Parses anything that can be on a side of the alternation.
    static let subexpression: Parser<Unit> = oneOf(
        quantified(lazy(group).map { $0 as Unit }),
        anchor.map { $0 as Unit },
        backreference.map { $0 as Unit },
        quantified(match.map { $0 as Unit }),
        char(from: Keywords.quantifiers).zeroOrThrow("The preceeding token is not quantifiable")
    ).oneOrMore.orThrow("Pattern must not be empty").map(flatten)

    // MARK: - Group

    static let group = ("(" *> optional("?:") <*> expression <* string(")").orThrow("Unmatched opening parentheses")).map(makeGroup)

    static func makeGroup(isNonCapturing: Bool, expression: Unit) -> Group {
        Group(index: nil, isCapturing: !isNonCapturing, children: [expression])
    }

    // MARK: - Match

    /// Any subexpression that is used for matching against the input string, e.g.
    /// "a" - matches a character, "[a-z]" – matches a character group, etc.
    static let match = oneOf(
        string(".").map { Match.anyCharacter },
        characterGroup.map(Match.group),
        characterSet.map(Match.set),
        escapedCharacter.map(Match.character),
        char(excluding: ")|" + Keywords.quantifiers).map(Match.character)
    )

    // MARK: - Character Classes

    /// Matches a character group, e.g. "[a-z]", "[abc]", etc.
    static let characterGroup = (
        "[" *> optional("^") <*>
        characterGroupItem.oneOrMore.orThrow("Character group is empty") <*
        string("]").orThrow("Character group missing closing bracket")
    ).map(CharacterGroup.init)

    static let characterGroupItem = oneOf(
        string("/").zeroOrThrow("An unescaped delimiter must be escaped with a backslash"),
        characterSet.map(CharacterGroup.Item.set),
        characterRange.map(CharacterGroup.Item.range),
        escapedCharacter.map(CharacterGroup.Item.character),
        char(excluding: "]").map(CharacterGroup.Item.character)
    )

    /// Character range, e.g. "a-z".
    static let characterRange = (char(excluding: "]") <* "-" <*> char(excluding: "]")).map(makeCharacterRange)

    static func makeCharacterRange(_ lhs: Character, _ rhs: Character) throws -> ClosedRange<Unicode.Scalar> {
        guard let lb = Unicode.Scalar(String(lhs)), let ub = Unicode.Scalar(String(rhs)) else {
            throw ParserError("Unsupported characters in character range")
        }
        guard ub >= lb else {
            throw ParserError("Character range is out of order")
        }
        return lb...ub
    }

    static let characterSet = oneOf(characterClass, characterClassFromUnicodeCategory)

    /// Predefined characters classes, e.g. "\d" - digits.
    static let characterClass = ("\\" *> char).map(makeCharacterClass)

    static func makeCharacterClass(_ char: Character) -> CharacterSet? {
        switch char {
        case "d": return CharacterSet.decimalDigits
        case "D": return CharacterSet.decimalDigits.inverted
        case "s": return CharacterSet.whitespaces
        case "S": return CharacterSet.whitespaces.inverted
        case "w": return CharacterSet.word
        case "W": return CharacterSet.word.inverted
        default: return nil
        }
    }

    /// A unicode category, e.g. "\p{P}" - all punctuation characters.
    static let characterClassFromUnicodeCategory: Parser<CharacterSet> =
        ("\\" *> char(from: "pP") <*> unicodeCategory)
            .map { type, category in type == "p" ? category : category.inverted }

    static let unicodeCategory = (
        string("{").orThrow("Missing unicode category name") *>
        string(excluding: "}").orThrow("Missing unicode category name") <*
        string("}").orThrow("Missing closing brace")
    ).map(makeUnicodeCategory)

    static func makeUnicodeCategory(_ name: String) throws -> CharacterSet? {
        switch name {
        case "P": return .punctuationCharacters
        case "Lt": return .capitalizedLetters
        case "Ll": return .lowercaseLetters
        case "N": return .nonBaseCharacters
        case "S": return .symbols
        default: throw ParserError("Unsupported unicode category '\(name)'")
        }
    }

    // MARK: - Quantifiers

    // Parses the quantifier, e.g. "*", "*?", "{2,4}".
    static let quantifier = (quantifierType <*> optional("?")).map(Quantifier.init)

    /// Parses quantifier type, e.g. zero or more, range quantifier.
    static let quantifierType: Parser<QuantifierType> = oneOf(
        string("*").map { .zeroOrMore },
        string("+").map { .oneOrMore },
        string("?").map { .zeroOrOne },
        rangeQuantifier.map(QuantifierType.range)
    )

    /// Parses range quantifier, e.g. "{2,4}", "{2}", "{4,}".
    static let rangeQuantifier = ("{" *> number <*> optional("," *> optional(number)) <* "}").map(makeRangeQuantifier)

    static func makeRangeQuantifier(_ lhs: Int, _ rhs: Int??) -> RangeQuantifier {
        RangeQuantifier(lowerBound: lhs, upperBound: rhs == nil ? lhs : rhs!)
    }

    /// Wrap the parser to allow the parsed expression to be quantified.
    static func quantified(_ parser: Parser<Unit>) -> Parser<Unit> {
        (parser <*> optional(quantifier)).map { expression, quantifier in
            guard let quantifier = quantifier else { return expression }
            return QuantifiedExpression(expression: expression, quantifier: quantifier)
        }
    }

    // MARK: - Anchors

    static let anchor = oneOf(escapedAnchor, string("$").map { .endOfString })

    static let escapedAnchor = ("\\" *> char).map(makeAnchor)

    static func makeAnchor(_ name: Character) -> Anchor? {
        switch name {
        case "b": return .wordBoundary
        case "B": return .nonWordBoundary
        case "A": return .startOfStringOnly
        case "Z": return .endOfStringOnly
        case "z": return .endOfStringOnlyNotNewline
        case "G": return .previousMatchEnd
        default: return nil
        }
    }

    // MARK: - Backreference

    static let backreference = ("\\" *> number).map(Backreference.init)

    // MARK: - Misc

    static let escapedCharacter = "\\" *> char.orThrow("Pattern may not end with a trailing backslash")

    /// Creates a unit which represents an expression. If there is only one
    /// child, returns a child itself to avoid additional overhead.
    static func flatten(_ children: [Unit]) -> Unit? {
        switch children.count {
        case 0: return nil
        case 1: return children[0]
        default: return ImplicitGroup(children: children)
        }
    }
}

private struct Keywords {
    static let quantifiers = "*+?"
}
