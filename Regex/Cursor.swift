// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

/// Cursor represents the slice in which we are performing the matching and the
/// current index in this slice.
struct Cursor: CustomStringConvertible {
    /// The entire input string.
    let completeInputString: String

    /// The string in which we are performing the search, a single line of
    /// input when `.multiline` option is enabled (disabled by default).
    let string: Substring

    /// The index from which we started the search.
    private(set) var startIndex: String.Index

    /// The current index of the cursor.
    private(set) var index: String.Index

    /// Captured groups.
    var groups: [Int: Range<String.Index>] = [:]

    /// Indexes where the group with the given start state was captured.
    var groupsStartIndexes: [State: String.Index] = [:]

    /// An index where the previous match occured.
    var previousMatchIndex: String.Index? = nil

    init(string: Substring, completeInputString: String) {
        self.completeInputString = completeInputString
        self.string = string
        self.startIndex = string.startIndex
        self.index = string.startIndex
    }

    mutating func startAt(_ index: String.Index) {
        self.startIndex = index
        self.index = index
    }

    mutating func advance(to index: String.Index) {
        self.index = index
    }

    mutating func advance(by offset: Int) {
        self.index = string.index(index, offsetBy: offset)
    }

    /// Returns the character at the current `index`.
    var character: Character? {
        return character(at: index)
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
        return string[completeInputString.index(index, offsetBy: offset)]
    }

    /// Returns `true` if there are no more characters to match.
    var isEmpty: Bool {
        return index == string.endIndex
    }

    /// Returns `true` if the current index is the index of the last character.
    var isAtLastIndex: Bool {
        return index < string.endIndex && string.index(after: index) == string.endIndex
    }

    var description: String {
        return "\(string.offset(for: index)), \(character ?? "∅")"
    }
}
