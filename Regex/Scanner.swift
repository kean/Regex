// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

final class Scanner {
    // The index of the next character that wasn't read yet.
    private(set) var i = 0

    private var patternString: String
    private var pattern: [Character]

    init(_ pattern: String) {
        self.patternString = pattern
        self.pattern = Array(pattern)
    }

    /// Returns the next character in the pattern without consuming it.
    func peak() -> Character? {
        guard i < pattern.endIndex else {
            return nil
        }
        return pattern[i]
    }

    // TODO: remove this temp workardoun
    func undoRead() {
        i -= 1
    }

    /// Reads the next character in the pattern.
    func deprecatedReadCharacter() -> Character? {
        guard i < pattern.endIndex else {
            return nil
        }
        defer { i += 1}
        return pattern[i]
    }

    /// Reads a single character (unconditionally) from the input string.
    @discardableResult
    func read() -> Substring {
        defer { i += 1 }
        return substring(range: i..<i+1)
    }

    /// Reads the next character if it matches the given character. Returns
    /// `true` if the character was read successfully.
    func read(_ c: Character) -> Substring? {
        return read(String(c))
    }

    func read(_ s: String) -> Substring? {
        let s = Array(s)
        var j = i
        var z = 0
        while j < pattern.endIndex {
            guard z < s.endIndex else {
                defer { i = j }
                return substring(range: i..<j)
            }
            guard pattern[j] == s[z] else {
                return nil
            }
            j += 1
            z += 1
        }
        return nil
    }

    private func substring(range: Range<Int>) -> Substring {
        let s = patternString
        let lb = s.index(s.startIndex, offsetBy: range.lowerBound)
        let ub = s.index(s.startIndex, offsetBy: range.upperBound)
        return s[lb..<ub]
    }

    /// Reads the string until reaching the given character. If successfull,
    /// consumes all the characters including the given character.
    func read(until c: Character) -> String? {
        var j = i
        while j < pattern.endIndex {
            if pattern[j] == c {
                defer { i = j + 1 }
                return String(pattern[i..<j])
            }
            j += 1
        }
        return nil
    }

    /// Reads characters while the closure returns true.
    func read(while closure: (Character) -> Bool) -> String {
        var string = ""
        while i < pattern.endIndex, closure(pattern[i]) {
            string.append(pattern[i])
            i += 1
        }
        return string
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

    func readInteger() -> (Substring, Int)? {
        let startIndex = i
        let digits = CharacterSet.decimalDigits
        let string = read(while: { digits.contains($0) })
        guard !string.isEmpty else {
            return nil
        }
        guard let int = Int(string) else {
            i = startIndex
            return nil
        }
        return (substring(range: startIndex..<i), int)
    }

    /// We encountered `[`, read a character group, e.g. [abc], [^ab]
    func readCharacterSet() throws -> (CharacterSet, Substring) {
        let openingBracketIndex = i
        i += 1

        // Check if the pattern is negative.
        let isNegative = read("^") != nil

        // Make sure that the group is not empty
        guard peak() != "]" else {
            throw Regex.Error("Character group is empty", openingBracketIndex)
        }

        // Read the characters until the group is closed.
        var set = CharacterSet()

        while let c = deprecatedReadCharacter() {
            switch c {
            case "]":
                if isNegative {
                    set.invert()
                }
                return (set, substring(range: openingBracketIndex..<i))
            case "\\":
                guard let c = deprecatedReadCharacter() else {
                    throw Regex.Error("Pattern may not end with a trailing backslash", i-1)
                }
                if let specialSet = try readCharacterClassSpecialCharacter(c) {
                    set.formUnion(specialSet)
                } else {
                    set.insert(c)
                }
            case "/":
                throw Regex.Error("An unescaped delimiter must be escaped with a backslash", i-1)
            default:
                if let range = try readCharacterRange(startingWith: c) {
                    set.insert(charactersIn: range)
                } else {
                    set.insert(c)
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
        guard read("{") != nil else {
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
        i += 1

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
        guard read("-") != nil else {
            return nil // Not a range
        }
        if peak() == "]" {
            i -= 1 // Undo reading '-'
            return nil // Just treat as regular characters
        }
        guard let upperBound = deprecatedReadCharacter() else {
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
