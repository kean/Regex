// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation
import os.log

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

// MARK: - Range

extension Range where Bound == Int {
    /// Returns the range which contains the indexes from both ranges and
    /// everything in between.
    static func merge(_ lhs: Range, _ rhs: Range) -> Range {
        return (Swift.min(lhs.lowerBound, rhs.lowerBound))..<(Swift.max(lhs.upperBound, rhs.upperBound))
    }
}

// MARK: - String

extension String {
    /// Returns a substring with the given range. The indexes are automatically
    /// calculated by offsetting the existing indexes.
    func substring(_ range: Range<Int>) -> Substring {
        return self[index(startIndex, offsetBy: range.lowerBound)..<index(startIndex, offsetBy: range.upperBound)]
    }
}

extension Substring {
    /// Returns a substring with the given range. The indexes are automatically
    /// calculated by offsetting the existing indexes.
    func substring(_ range: Range<Int>) -> Substring {
        return self[index(startIndex, offsetBy: range.lowerBound)..<index(startIndex, offsetBy: range.upperBound)]
    }

    func offset(for index: String.Index) -> Int {
        return distance(from: startIndex, to: index)
    }
}

// MARK: - OSLog

extension OSLog {
    // Returns `true` if the default logging type enabled.
    var isEnabled: Bool {
        return isEnabled(type: .default)
    }
}

// MARK: - MicroSet

// Abuses the following two facts:
//
// - In most regexes there are only up to two states reachable at any given time
// - The order in which states are inserted is deterministic
struct MicroSet<Element: Hashable>: Hashable, Sequence {
    private(set) var count: Int = 0
    // Inlinable
    private var e1: Element?
    private var e2: Element?

    var isEmpty: Bool {
        count == 0
    }

    private var set: ContiguousArray<Element>?

    init() {}

    init(_ element: Element) {
        insert(element)
    }

    mutating func insert(_ element: Element) {
        switch count {
        case 0:
            e1 = element
            count += 1
        case 1:
            guard e2 != element else { return }
            e2 = element
            count += 1
        default:
            guard e1 != element, e2 != element else { return }

            if set == nil {
                set = ContiguousArray()
            }
            if !set!.contains(element) {
                set!.append(element)
                count += 1
            }
        }
    }

    func contains(_ element: Element) -> Bool {
        switch count {
        case 0: return false
        case 1: return e1 == element
        case 2: return e1 == element || e2 == element
        default: return e1 == element || e2 == element || set!.contains(element)
        }
    }

    mutating func removeAll() {
        e1 = nil
        e2 = nil
        set?.removeAll()
        count = 0
    }

    private func element(at index: Int) -> Element? {
        guard index < count else {
            return nil
        }
        switch index {
        case 0: return e1!
        case 1: return e2!
        default: return set![index-2]
        }
    }

    __consuming func makeIterator() -> MicroSet<Element>.Iterator {
        Iterator(set: self)
    }

    struct Iterator: IteratorProtocol {
        private let set: MicroSet
        private var index: Int = 0

        init(set: MicroSet) {
            self.set = set
        }

        mutating func next() -> Element? {
            defer { index += 1 }
            return set.element(at: index)
        }
    }
}
