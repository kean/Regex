// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

extension Parsers {
    static let regex: Parser<AST> =
        zip(literal("^").optional, expression, end).map { anchor, expression, _ in
            #warning("TODO: remove 'pattern'")
            return AST(root: expression, isFromStartOfString: anchor != nil, pattern: "13")
    }

    // MARK: - Expression

    // TODO: should be able to parse units until encountering "|" or ")"
    static let expression: Parser<Unit> = zip(subexpression, zip("|", _expression).optional).map { lhs, rhs in
        guard let rhs = rhs else { return lhs }
        return Alternation(children: [lhs, rhs.1], source: 0..<0)
    }

    private static let _expression: Parser<Unit> = lazy(expression) // Trick the compile into allowing us to define expression recursively

    /// Anything that can be on one side of the alternation.
    private static let subexpression: Parser<Unit> = oneOf(
//        literal(")").flatMap { Parser { _ in throw ParserError("Unmatched closing parentheses") } }, // TODO: cleanup
        quantified(lazy(group).map { $0 as Unit }), // Use lazy to enable recursion
        anchor.map { $0 as Unit },
        backreference.map { $0 as Unit },
        quantified(match.map { $0 as Unit })
    ).zeroOrMore.map(flatten)

    /// Creates an node which represents an expression. If there is only one
    /// child, returns a child itself to avoid additional overhead.
    private static func flatten(_ children: [Unit]) throws -> Unit {
        switch children.count {
        case 0: throw Regex.Error("Pattern must not be empty", 0)
        case 1: return children[0]
        default:
            let source = Range.merge(children.first!.source, children.last!.source)
            return Expression(children: children, source: source)
        }
    }

    // MARK: - Match

    static let match: Parser<Match> = matchType.map { type in
        Match(type: type, source: 0..<0)
    }

    #warning("TODO: add support for the remaining types")
    static let matchType: Parser<MatchType> = oneOf(
        matchAnyCharacter,
        matchCharacterGroup,
        matchCharacterClass,
        matchEscapedCharacter,
        matchCharacter
    )

    static let matchAnyCharacter = literal(".").map { MatchType.anyCharacter }
    static let matchCharacterGroup: Parser<MatchType> = characterGroup.map(MatchType.group)
    static let matchCharacterClass: Parser<MatchType> = characterClass.map(MatchType.set)
    static let matchEscapedCharacter: Parser<MatchType> = escapedCharacter.map(MatchType.character)
    static let matchCharacter: Parser<MatchType> = char(excluding: ")|").map(MatchType.character)

    // MARK: - Character Classes

    static let characterGroup: Parser<CharacterGroup> = zip(
        "[",
        literal("^").optional,
        characterGroupItem.oneOrMore.required("Character group is empty"),
        literal("]").required("Character group is missing a closing bracket")
    ).map { _, invert, items, _ in
        CharacterGroup(isInverted: invert != nil, items: items)
    }

    static let characterGroupItem: Parser<CharacterGroup.Item> = oneOf(
        literal("/").flatMap { Parser { _ in throw ParserError("An unescaped delimiter must be escaped with a backslash") } }, // TODO: cleanup
        characterClass.map(CharacterGroup.Item.set),
        characterClassFromUnicodeCategory.map(CharacterGroup.Item.set),
        characterRange.map(CharacterGroup.Item.range),
        escapedCharacter.map(CharacterGroup.Item.character),
        char(excluding: "]").map(CharacterGroup.Item.character)
    )

    /// Character range, e.g. "a-z".
    static let characterRange: Parser<ClosedRange<Unicode.Scalar>> =
        zip(char(excluding: "]"), "-", char(excluding: "]")).map { lhs, _, rhs in
            guard let lb = Unicode.Scalar(String(lhs)), let ub = Unicode.Scalar(String(rhs)) else {
                throw ParserError("Unsupported characters in character range")
            }
            guard ub >= lb else {
                throw ParserError("Character range is out of order")
            }
            return lb...ub
        }

    /// Predefined characters classes, e.g. "\d" - digits.
    static let characterClass: Parser<CharacterSet> = zip("\\", char).map { _, char in
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

    /// A unicode category, e.g. "\p{P}" - punctuation.
    static let characterClassFromUnicodeCategory: Parser<CharacterSet> = zip(
        "\\p",
        literal("{").required("Missing opening brace"),
        string(excluding: "}").required("Missing unicode category name"),
        literal("}").required("Missing closing brace")
    ).map { _, _, category, _ in
        switch category {
        case "P": return .punctuationCharacters
        case "Lt": return .capitalizedLetters
        case "Ll": return .lowercaseLetters
        case "N": return .nonBaseCharacters
        case "S": return .symbols
        default: throw ParserError("Unsupported unicode category '\(category)'")
        }
    }

    // MARK: - Group

    static let group: Parser<Group> = zip(
        "(",
        literal("?:").optional,
        expression,
        literal(")").required("Unmatched opening parentheses")
    ).map { _, nonCapturingModifier, expression, _ in
        Group(index: nil, isCapturing: nonCapturingModifier == nil, children: [expression], source: 0..<0)
    }

    // MARK: - Quantifiers

    static let quantifier: Parser<Quantifier> =
        zip(quantifierType, literal("?").optional)
            .map { type, lazy in Quantifier(type: type, isLazy: lazy != nil) }
            .error("Invalid quantifier.")

    /// Parses quantifier type, e.g. zero or more, range quantifier.
    static let quantifierType: Parser<QuantifierType> = oneOf(
        literal("*").map { .zeroOrMore },
        literal("+").map { .oneOrMore },
        literal("?").map { .zeroOrOne },
        rangeQuantifier.map(QuantifierType.range)
    )

    /// Parsers range quantifier, e.g. "{2,4}", "{2}", "{4,}".
    static let rangeQuantifier: Parser<RangeQuantifier> =
        zip("{", number, zip(",", number.optional).optional, "}")
            .map { _, lhs, rhs, _ in (lhs, rhs == nil ? lhs : rhs?.1) }
            .map(RangeQuantifier.init(lowerBound:upperBound:))

    /// Wrap the parser to allow the parsed expression to be quantified.
    static func quantified(_ parser: Parser<Unit>) -> Parser<Unit> {
        zip(parser, quantifier.optional).map { expression, quantifier in
            guard let quantifier = quantifier else { return expression }
            return QuantifiedExpression(quantifier: quantifier, expression: expression, source: 0..<0)
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

    static let backreference: Parser<Backreference> = zip("\\", number).map { _, index in
        Backreference(index: index, source: 0..<0)
    }

    // MARK: - Misc

    static let escapedCharacter = zip("\\", char).map { _, char in char }
}
