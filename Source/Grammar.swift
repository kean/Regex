// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

extension Parsers {
    static let regex: Parser<AST> = zip(
        startOfStringAnchor.optional,
        expression,
        oneOf(
            end, // Parsed the entire string, we are good
            literal(")").map { throw ParserError("Unmatched closing parentheses") } // Make sure no umnatches parantheses are left
        )
    ).map { anchor, expression, _ in
        return AST(root: expression, isFromStartOfString: anchor != nil)
    }

    private static let startOfStringAnchor = literal("^")

    // MARK: - Expression

    static let expression: Parser<Unit> = zip(
        subexpression,
        zip("|", _expression).optional // Recursively parse the right side of the alternation
    ).map { lhs, rhs in
        guard let rhs = rhs else { return lhs } // No alternation matched
        return Alternation(children: [lhs, rhs.1])
    }

    // Tricks the compile into allowing us to define expression recursively (see `lazy`)
    private static let _expression: Parser<Unit> = lazy(expression)

    /// Parses anything that can be on a side of the alternation.
    private static let subexpression: Parser<Unit> = oneOf(
        quantified(lazy(group).map { $0 as Unit }),
        anchor.map { $0 as Unit },
        backreference.map { $0 as Unit },
        quantified(match.map { $0 as Unit }),
        literal(from: Keywords.quantifiers).map { throw ParserError("The preceeding token is not quantifiable") }
    ).oneOrMore.orThrow("Pattern must not be empty").map(flatten)

    // MARK: - Match

    // Any subexpression that is used for matching against the input string, e.g.
    // "a" - matches a character, "[a-z]" – matches a character group, etc.
    static let match: Parser<Match> = oneOf(
        matchAnyCharacter,
        matchCharacterGroup,
        matchCharacterSet,
        matchEscapedCharacter,
        matchCharacter
    )

    static let matchAnyCharacter = literal(".").map { Match.anyCharacter }
    static let matchCharacterGroup: Parser<Match> = characterGroup.map(Match.group)
    static let matchCharacterSet: Parser<Match> = characterSet.map(Match.set)
    static let matchEscapedCharacter: Parser<Match> = escapedCharacter.map(Match.character)
    static let matchCharacter: Parser<Match> = char(excluding: ")|" + Keywords.quantifiers).map(Match.character)

    // MARK: - Character Classes

    /// Matches a character group, e.g. "[a-z]", "[abc]", etc.
    static let characterGroup: Parser<CharacterGroup> = zip(
        "[",
        literal("^").optional,
        characterGroupItem.oneOrMore.orThrow("Character group is empty"),
        literal("]").orThrow("Character group missing closing bracket")
    ).map { _, invert, items, _ in
        CharacterGroup(isInverted: invert != nil, items: items)
    }

    static let characterGroupItem: Parser<CharacterGroup.Item> = oneOf(
        literal("/").map { throw ParserError("An unescaped delimiter must be escaped with a backslash") },
        characterSet.map(CharacterGroup.Item.set),
        characterRange.map(CharacterGroup.Item.range),
        escapedCharacter.map(CharacterGroup.Item.character),
        char(excluding: "]").map(CharacterGroup.Item.character)
    )

    /// Character range, e.g. "a-z".
    static let characterRange: Parser<ClosedRange<Unicode.Scalar>> = zip(
        char(excluding: "]"),
        "-",
        char(excluding: "]")
    ).map { lhs, _, rhs in
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
    static let characterClass: Parser<CharacterSet> = zip(
        "\\", char
    ).map { _, char in
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
    static let characterClassFromUnicodeCategory: Parser<CharacterSet> = zip(
        "\\",
        oneOf(char("p"), char("P")),
        literal("{").orThrow("Missing unicode category name"),
        string(excluding: "}").orThrow("Missing unicode category name"),
        literal("}").orThrow("Missing closing brace")
    ).map { _, type, _, category, _ in
        let set: CharacterSet
        switch category {
        case "P": set = .punctuationCharacters
        case "Lt": set = .capitalizedLetters
        case "Ll": set = .lowercaseLetters
        case "N": set = .nonBaseCharacters
        case "S": set = .symbols
        default: throw ParserError("Unsupported unicode category '\(category)'")
        }
        return type == "p" ? set : set.inverted
    }

    // MARK: - Group

    static let group: Parser<Group> = zip(
        "(",
        literal("?:").optional,
        expression,
        literal(")").orThrow("Unmatched opening parentheses")
    ).map { _, nonCapturingModifier, expression, _ in
        Group(index: nil, isCapturing: nonCapturingModifier == nil, children: [expression])
    }

    // MARK: - Quantifiers

    static let quantifier: Parser<Quantifier> = zip(
        quantifierType, literal("?").optional
    ).map { type, lazy in
        Quantifier(type: type, isLazy: lazy != nil)
    }

    /// Parses quantifier type, e.g. zero or more, range quantifier.
    static let quantifierType: Parser<QuantifierType> = oneOf(
        literal("*").map { .zeroOrMore },
        literal("+").map { .oneOrMore },
        literal("?").map { .zeroOrOne },
        rangeQuantifier.map(QuantifierType.range)
    )

    /// Parsers range quantifier, e.g. "{2,4}", "{2}", "{4,}".
    static let rangeQuantifier: Parser<RangeQuantifier> = zip(
        "{", number, zip(",", number.optional).optional, "}"
    ).map { _, lhs, rhs, _ in
        RangeQuantifier(lowerBound: lhs, upperBound: rhs == nil ? lhs : rhs?.1)
    }

    /// Wrap the parser to allow the parsed expression to be quantified.
    static func quantified(_ parser: Parser<Unit>) -> Parser<Unit> {
        zip(parser, quantifier.optional).map { expression, quantifier in
            guard let quantifier = quantifier else { return expression }
            return QuantifiedExpression(quantifier: quantifier, expression: expression)
        }
    }

    // MARK: - Anchors

    static let anchor: Parser<Anchor> = oneOf(
        escapedAnchor,
        literal("$").map { .endOfString }
    )

    private static let escapedAnchor: Parser<Anchor> = zip("\\", char).map { _, char in
        switch char {
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

    static let backreference: Parser<Backreference> = zip(
        "\\", number
    ).map { _, index in
        Backreference(index: index)
    }

    // MARK: - Misc

    static let escapedCharacter = zip(
        "\\",
        char.orThrow("Pattern may not end with a trailing backslash")
    ).map { _, char in char }

    /// Creates a unit which represents an expression. If there is only one
    /// child, returns a child itself to avoid additional overhead.
    private static func flatten(_ children: [Unit]) -> Unit? {
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
