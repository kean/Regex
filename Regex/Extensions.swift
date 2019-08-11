// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

// MARK: - CharacterSet

extension CharacterSet {
    // Analog of '\w' (word set)
    static let word = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: "_"))

    /// Insert all the individual unicode scalars which the character
    /// consists of.
    mutating func insert(_ c: Character) {
        for scalar in c.unicodeScalars {
            insert(scalar)
        }
    }

    /// Returns true if all of the unicode scalars in the given character
    /// are in the characer set.
    func contains(_ c: Character) -> Bool {
        return c.unicodeScalars.allSatisfy(contains)
    }
}

// MARK: - Character

extension Character {
    // Returns `true` if the character belong to "word" category ('\w')
    var isWord: Bool {
        return CharacterSet.word.contains(self)
    }
}
