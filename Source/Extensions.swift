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

// MARK: - OSLog

extension OSLog {
    // Returns `true` if the default logging type enabled.
    var isEnabled: Bool {
        return isEnabled(type: .default)
    }
}

// MARK: - SmallSet

// A set which inlines the first couple of elements and avoid any heap allocations.
//
// This is epsecially useful when executing a BFS algorithm. In most cases,
// there are only up to two states reachable at any given time
struct SmallSet<Element: Hashable>: Hashable, Sequence {
    private(set) var count: Int = 0

    // Inlined elements
    private var e1: Element?
    private var e2: Element?

    // The remaining elements (allocated lazily)
    private var set: ContiguousArray<Element>?

    var isEmpty: Bool { count == 0 }

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
            guard e1 != element else { return }
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

    __consuming func makeIterator() -> SmallSet<Element>.Iterator {
        Iterator(set: self)
    }

    struct Iterator: IteratorProtocol {
        private let set: SmallSet
        private var index: Int = 0

        init(set: SmallSet) {
            self.set = set
        }

        mutating func next() -> Element? {
            defer { index += 1 }
            return set.element(at: index)
        }
    }
}
