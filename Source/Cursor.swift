// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

/// Cursor represents the input string and the current position in the string.
struct Cursor {
    /// The entire input string.
    let string: String

    /// The index from which we started the search.
    private(set) var startIndex: String.Index

    let endIndex: String.Index

    /// The current index of the cursor.
    private(set) var index: String.Index

    /// Captured groups.
    var groups: [Int: Range<String.Index>]

    /// An index where the previous match occured.
    var previousMatchIndex: String.Index?

    init(string: String) {
        self.string = string
        self.startIndex = string.startIndex
        self.endIndex = string.endIndex
        self.groups = [:]
        self.index = string.startIndex
    }
}

// MARK: - Cursor (Advance)

extension Cursor {
    mutating func startAt(_ index: String.Index) {
        self.startIndex = index
        self.index = index
        self.groups.removeAll()
    }

    mutating func advance(to index: String.Index) {
        self.index = index
    }

    mutating func advance(by offset: Int) {
        self.index = string.index(index, offsetBy: offset)
    }
}

// MARK: - Cursor (Characters)

extension Cursor {
    subscript(range: Range<String.Index>) -> Substring {
        string[range]
    }

    subscript(index: String.Index) -> Character {
        string[index]
    }

    /// Returns the character at the current `index`.
    var character: Character? {
        character(at: index)
    }

    /// Returns the character at the given index if it exists. Returns `nil` otherwise.
    private func character(at index: String.Index) -> Character? {
        guard index < string.endIndex else {
            return nil
        }
        return string[index]
    }

    /// Returns the character at the index with the given offset from the
    /// current index.
    func character(offsetBy offset: Int) -> Character {
        string[string.index(index, offsetBy: offset)]
    }
}

// MARK: - Cursor (Indices)

extension Cursor {
    func index(_ index: String.Index, offsetBy offset: Int, isLimited: Bool = false) -> String.Index? {
        return string.index(index, offsetBy: offset, limitedBy: string.endIndex)
    }

    func index(after index: String.Index) -> String.Index {
        return string.index(after: index)
    }

    /// Returns `true` if there are no more characters to match.
    var isEmpty: Bool {
        index == string.endIndex
    }

    /// Returns `true` if the current index is the index of the last character.
    var isAtLastIndex: Bool {
        index < string.endIndex && string.index(after: index) == string.endIndex
    }
}

// MARK: - Cursor (CustomStringConvertible)

extension Cursor: CustomStringConvertible {
    var description: String {
          let char = String(character ?? "∅")
          return "\(string.offset(for: index)), \(char == "\n" ? "\\n" : char)"
      }
}
