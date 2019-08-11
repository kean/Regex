// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

final class Parser {
    // The index of the next character that wasn't read yet.
    private(set) var i = 0

    private var pattern: [Character]

    init(_ pattern: [Character]) {
        self.pattern = pattern
    }

    /// Returns the next character in the pattern without consuming it.
    func peak() -> Character? {
        guard i < pattern.endIndex else {
            return nil
        }
        return pattern[i]
    }

    /// Reads the next character in the pattern.
    func readCharacter() -> Character? {
        guard i < pattern.endIndex else {
            return nil
        }
        defer { i += 1}
        return pattern[i]
    }

    /// Reads the next character if it matches the given character. Returns
    /// `true` if the character was read successfully.
    func read(_ c: Character) -> Bool {
        guard i < pattern.endIndex else {
            return false
        }
        guard pattern[i] == c else {
            return false
        }
        i += 1 // Matches, consume it
        return true
    }

    /// Reads the string until reaching the given character. If successfull,
    /// consumes all the characters including the given character.
    func read(until c: Character) -> String? {
        let startIndex = i
        while i < pattern.endIndex {
            defer { i += 1 }
            if pattern[i] == c {
                return String(pattern[startIndex..<i])
            }
        }
        i = startIndex
        return nil
    }

    /// Reads the character from the end of the pattern if it matches the given
    /// character. Returns `true` if the character was read successfully.
    func readFromEnd(_ c: Character) -> Bool {
        guard pattern.last == c else {
            return false
        }
        pattern.removeLast()
        return true
    }

    /// We encountered `[`, read a character group, e.g. [abc], [^ab]
    /// - warning: doesn't support emoji.
    func readCharacterSet() throws -> CharacterSet {
        let openingBracketIndex = i - 1

        // Check if the pattern is negative.
        let isNegative = read("^")

        // Make sure that the group is not empty
        guard peak() != "]" else {
            throw Regex.Error("Character group is empty", openingBracketIndex)
        }

        // Read the characters until the group is closed.
        var set = CharacterSet()

        func insert(_ c: Character) throws {
            // TODO: this is a temporary limitation, need to figure out a better approach
            guard c.unicodeScalars.count < 2 else {
                throw Regex.Error("Character \(c) is not supported", i - 1)
            }
            for scalar in c.unicodeScalars {
                set.insert(scalar)
            }
        }

        while let c = readCharacter() {
            switch c {
            case "]":
                if isNegative {
                    set.invert()
                }
                return set
            case "\\":
                guard let c = readCharacter() else {
                    throw Regex.Error("Pattern may not end with a trailing backslash", i-1)
                }
                if let specialSet = try readCharacterClassSpecialCharacter(c) {
                    set.formUnion(specialSet)
                } else {
                    try insert(c)
                }
            case "/":
                throw Regex.Error("An unescaped delimiter must be escaped with a backslash", i-1)
            default:
                if let range = try readCharacterRange(startingWith: c) {
                    set.insert(charactersIn: range)
                } else {
                    try insert(c)
                }
            }
        }

        throw Regex.Error("Character group missing closing bracket", openingBracketIndex)
    }

    func readCharacterClassSpecialCharacter(_ c: Character) throws -> CharacterSet? {
        switch c {
        case "d": return CharacterSet.decimalDigits
        case "D": return CharacterSet.decimalDigits.inverted
        case "s": return CharacterSet.whitespaces
        case "S": return CharacterSet.whitespaces.inverted
        case "w": return CharacterSet.word
        case "W": return CharacterSet.word.inverted
        case "p": return try readUnicodeCategory()
        case "P": return try readUnicodeCategory().inverted
        default: return nil
        }
    }

    /// Reads unicode category set, e.g. "P" stands for all punctuation characters.
    func readUnicodeCategory() throws -> CharacterSet {
        let pSymbolIndex = i-1
        guard read("{") else {
            throw Regex.Error("Missing unicode category name", pSymbolIndex)
        }
        guard let name = read(until: "}") else {
            throw Regex.Error("Missing closing bracket for unicode category name", pSymbolIndex)
        }
        guard !name.isEmpty else {
            throw Regex.Error("Unicode category name is empty", pSymbolIndex)
        }
        switch name {
        case "P": return .punctuationCharacters
        case "Lt": return .capitalizedLetters
        case "Ll": return .lowercaseLetters
        case "N": return .nonBaseCharacters
        case "S": return .symbols
        default: throw Regex.Error("Unsupported unicode category '\(name)'", pSymbolIndex)
        }
    }

    // We encounted '{', read a range for range quantifier, e.g. {3}, {3,}
    func readRangeQuantifier() throws -> ClosedRange<Int> {
        // Read until we find a closing bracket
        let openingBracketIndex = i-1
        guard let rangeSubstring = read(until: "}") else {
            throw Regex.Error("Range quantifier missing closing bracket", openingBracketIndex)
        }

        guard !rangeSubstring.isEmpty else {
            throw Regex.Error("Range quantifier missing range", openingBracketIndex)
        }

        let components = rangeSubstring.split(separator: ",", omittingEmptySubsequences: false)

        switch components.count {
        case 0:
            throw Regex.Error("Range quantifier missing range", openingBracketIndex)
        case 1:
            guard let bound = Int(String(components[0])) else {
                throw Regex.Error("Range quantifier has invalid bound", openingBracketIndex)
            }
            guard bound > 0 else {
                throw Regex.Error("Range quantifier must be more than zero", openingBracketIndex)
            }
            return bound...bound
        case 2:
            guard !components[0].isEmpty else {
                throw Regex.Error("Range quantifier missing lower bound", openingBracketIndex)
            }
            guard let lowerBound = Int(String(components[0])) else {
                throw Regex.Error("Range quantifier has invalid lower bound", openingBracketIndex)
            }
            guard lowerBound >= 0 else {
                throw Regex.Error("Range quantifier lower bound must be non-negative", openingBracketIndex)
            }
            if components[1].isEmpty {
                return lowerBound...Int.max
            }
            guard let upperBound = Int(String(components[1])) else {
                throw Regex.Error("Range quantifier has invalid upper bound", openingBracketIndex)
            }
            guard upperBound >= lowerBound else {
                throw Regex.Error("Range quantifier upper bound must be greater than or equal than lower bound", openingBracketIndex)
            }
            return lowerBound...upperBound
        default:
            throw Regex.Error("Range quantifier has invalid bound", openingBracketIndex)
        }
    }

    /// Reads a character range in a form "a-z", "A-Z", etc. Character range must be provided
    /// in a valid order.
    func readCharacterRange(startingWith lowerBound: Character) throws -> ClosedRange<Unicode.Scalar>? {
        let dashIndex = i
        guard read("-") else {
            return nil // Not a range
        }
        if peak() == "]" {
            i -= 1 // Undo reading '-'
            return nil // Just treat as regular characters
        }
        guard let upperBound = readCharacter() else {
            return nil // The character group seems incomplete, let the upper layer handle the issue
        }
        // TODO: this is probably not the best way to convert these
        guard let lb = Unicode.Scalar(String(lowerBound)),
            let ub = Unicode.Scalar(String(upperBound)) else {
                throw Regex.Error("Unsupported characters in character range", dashIndex)
        }

        guard ub >= lb else {
            throw Regex.Error("Character range is out of order", dashIndex)
        }

        return lb...ub
    }
}
