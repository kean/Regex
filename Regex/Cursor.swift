// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

/// Cursor represents the slice in which we are performing the matching and the
/// current index in this slice.
struct Cursor { // Not sure this is the best word
    /// The entire input string.
    let string: String

    /// The substring in which we are performing the search.
    let substring: Substring

    /// The characters in the input string.
    let characters: [Character]

    /// The range in which we are performing the search.
    var range: Range<Int>

    /// The index of the current element being matched.
    var index: Int

    /// An index where the previous match occured.
    var previousMatchIndex: String.Index? = nil

    init(string: String, substring: Substring) {
        self.string = string
        self.substring = substring
        self.characters = Array(substring)
        self.range = characters.startIndex..<characters.endIndex
        self.index = characters.startIndex
    }

    /// Focuses the cursor on the range which starts at the given index.
    func startingAt(_ index: Int) -> Cursor {
        var cursor = self
        cursor.index = index
        cursor.range = index..<characters.endIndex
        return cursor
    }

    /// Returns the character at the current `index`.
    var character: Character? {
        return character(at: index)
    }

    /// Returns the character at the given index if it exists. Returns `nil` otherwise.
    private func character(at index: Int) -> Character? {
        guard characters.indices.contains(index) else {
            return nil
        }
        return characters[index]
    }

    /// Returns the character at the index with the given offset from the
    /// current index.
    func character(offsetBy offset: Int) -> Character? {
        return character(at: index + offset)
    }

    /// Returns `true` if there are no more characters to match.
    var isEmpty: Bool {
        return index >= characters.endIndex
    }

    /// Returns `true` if the current index is the index of the last character.
    var isLastIndex: Bool {
        return index == characters.endIndex - 1
    }
}
