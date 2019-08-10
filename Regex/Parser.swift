// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

final class Parser {
    // The index of the next character that wasn't scanned yet.
    private(set) var i = 0

    private var pattern: [Character]

    init(_ pattern: [Character]) {
        self.pattern = pattern
    }

    func peak() -> Character? {
        guard i < pattern.endIndex else {
            return nil
        }
        return pattern[i]
    }

    /// Reads the next character from the pattern.
    func readCharacter() -> Character? {
        guard i < pattern.endIndex else {
            return nil
        }
        defer { i += 1}
        return pattern[i]
    }

    /// Returns true if the next unread character was matching the given character,
    /// consumes the character if it does.
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

    /// Returns true if the character from the end matches the given
    /// character, consumerse the charater if it does.
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
        let isNegative: Bool
        if pattern[i] == "^" {
            i += 1 // Consume '^'
            isNegative = true
        } else {
            isNegative = false
        }

        // Read the characters until the group is closed.
        var set = CharacterSet()

        func insert(_ c: Character) throws {
            // TODO: this is a temporary limitation, need to figure out a better approach
            guard c.unicodeScalars.count < 2 else {
                throw Regex.Error("Character \(c) is not supported", i-1)
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
                if let specialSet = parseSpecialCharacter(c) {
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

    func parseSpecialCharacter(_ c: Character) -> CharacterSet? {
        switch c {
        case "d": return CharacterSet.decimalDigits
        case "D": return CharacterSet.decimalDigits.inverted
        case "s": return CharacterSet.whitespaces
        case "S": return CharacterSet.whitespaces.inverted
        case "w": return CharacterSet.word
        case "W": return CharacterSet.word.inverted
        default: return nil
        }
    }

    // We encounted '{', read a range for range quantifier, e.g. {3}, {3,}
    func readRangeQuantifier() throws -> ClosedRange<Int> {
        func readClosingBracket() -> Int? {
            while i < pattern.endIndex {
                defer { i += 1 }
                if pattern[i] == "}" {
                    return i
                }
            }
            return nil
        }

        // Read until we find a closing bracket
        let openingBracketIndex = i-1
        guard let closingBracketIndex = readClosingBracket() else {
            throw Regex.Error("Range quantifier missing closing bracket", openingBracketIndex)
        }

        let rangeSubstring = String(pattern[(openingBracketIndex+1)..<closingBracketIndex])
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
                throw Regex.Error("Unsupported characters in charcter range", dashIndex)
        }

        guard ub >= lb else {
            throw Regex.Error("Character range is out of order", dashIndex)
        }

        return lb...ub
    }
}
