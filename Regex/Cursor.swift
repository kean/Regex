// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

/// Cursor represents a string and a position within this string.
struct Cursor { // Not sure this is the best word
    let string: [Character]
    var index: Int

    init(string: [Character], index: Int) {
        self.string = string
        self.index = index
    }

    var character: Character? {
        guard !isEmpty else {
            return nil
        }
        return string[index]
    }

    func character(at index: Int) -> Character? {
        guard string.indices.contains(index) else {
            return nil
        }
        return string[index]
    }

    func character(offsetBy offset: Int) -> Character? {
        return character(at: index + offset)
    }

    var isEmpty: Bool {
        return index >= string.endIndex
    }
}
