// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

/// Cursor represents the slice in which we are performing the matching and the
/// current index in this slice.
struct Cursor: CustomStringConvertible {
    /// The entire input string.
    var string: String { ref.string }

    /// The index from which we started the search.
    private(set) var startIndex: String.Index

    /// The current index of the cursor.
    private(set) var index: String.Index

    /// Captured groups.
    var groups: [Int: Range<String.Index>] {
        get { ref.groups }
        set { mutate { $0.groups = newValue } }
    }

    /// Indexes where the group with the given start state was captured.
    var groupsStartIndexes: [StateId: String.Index] {
        get { ref.groupsStartIndexes }
        set { mutate { $0.groupsStartIndexes = newValue } }
    }

    /// An index where the previous match occured.
    var previousMatchIndex: String.Index?

    init(string: String) {
        self.ref = Container(string: string)
        self.startIndex = string.startIndex
        self.index = string.startIndex
    }

    mutating func startAt(_ index: String.Index) {
        self.startIndex = index
        self.index = index
        mutate {
            $0.groups = [:]
            $0.groupsStartIndexes = [:]
        }
    }

    mutating func advance(to index: String.Index) {
        self.index = index
    }

    mutating func advance(by offset: Int) {
        self.index = string.index(index, offsetBy: offset)
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

    /// Returns `true` if there are no more characters to match.
    var isEmpty: Bool {
        index == string.endIndex
    }

    /// Returns `true` if the current index is the index of the last character.
    var isAtLastIndex: Bool {
        index < string.endIndex && string.index(after: index) == string.endIndex
    }

    var description: String {
        let char = String(character ?? "∅")
        return "\(string.offset(for: index)), \(char == "\n" ? "\\n" : char)"
    }

    // MARK: - CoW

    private var ref: Container

    private mutating func mutate(_ closure: (Container) -> Void) {
        if !isKnownUniquelyReferenced(&ref) {
            ref = Container(container: ref)
        }
        closure(ref)
    }

    /// Just like many Swift built-in types, `ImageRequest` uses CoW approach to
    /// avoid memberwise retain/releases when `ImageRequest` is passed around.
    private class Container {
        let string: String
        var groups: [Int: Range<String.Index>] = [:]
        var groupsStartIndexes: [StateId: String.Index] = [:]

        /// Creates a resource with a default processor.
        init(string: String) {
            self.string = string
        }

        /// Creates a copy.
        init(container ref: Container) {
            self.string = ref.string
            self.groups = ref.groups
            self.groupsStartIndexes = ref.groupsStartIndexes
        }
    }
}
