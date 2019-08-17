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
}

// MARK: - Cache

// New items removed least recently added items.
struct Cache<Key: Hashable, Value> {
    private var map = [Key: LinkedList<Entry>.Node]()
    private let list = LinkedList<Entry>()

    let countLimit: Int

    var totalCount: Int {
        return map.count
    }

    init(countLimit: Int) {
        self.countLimit = countLimit
    }

    func value(forKey key: Key) -> Value? {
        guard let node = map[key] else {
            return nil
        }
        return node.value.value
    }

    mutating func set(_ value: Value, forKey key: Key) {
        let entry = Entry(value: value, key: key)
        _add(entry)
        _trim() // _trim is extremely fast, it's OK to call it each time
    }

    @discardableResult
    mutating func removeValue(forKey key: Key) -> Value? {
        guard let node = map[key] else {
            return nil
        }
        _remove(node: node)
        return node.value.value
    }

    private mutating func _add(_ element: Entry) {
        if let existingNode = map[element.key] {
            _remove(node: existingNode)
        }
        map[element.key] = list.append(element)
    }

    private mutating func _remove(node: LinkedList<Entry>.Node) {
        list.remove(node)
        map[node.value.key] = nil
    }

    mutating func removeAll() {
        map.removeAll()
        list.removeAll()
    }

    private mutating func _trim() {
        _trim(toCount: countLimit)
    }

    private mutating func _trim(toCount limit: Int) {
        while totalCount > limit, let node = list.first { // least recently used
            _remove(node: node)
        }
    }

    private struct Entry {
        let value: Value
        let key: Key
    }
}

// MARK: - LinkedList

/// A doubly linked list.
final class LinkedList<Element> {
    // first <-> node <-> ... <-> last
    private(set) var first: Node?
    private(set) var last: Node?

    deinit {
        removeAll()
    }

    var isEmpty: Bool {
        return last == nil
    }

    /// Adds an element to the end of the list.
    @discardableResult
    func append(_ element: Element) -> Node {
        let node = Node(value: element)
        append(node)
        return node
    }

    /// Adds a node to the end of the list.
    func append(_ node: Node) {
        if let last = last {
            last.next = node
            node.previous = last
            self.last = node
        } else {
            last = node
            first = node
        }
    }

    func remove(_ node: Node) {
        node.next?.previous = node.previous // node.previous is nil if node=first
        node.previous?.next = node.next // node.next is nil if node=last
        if node === last {
            last = node.previous
        }
        if node === first {
            first = node.next
        }
        node.next = nil
        node.previous = nil
    }

    func removeAll() {
        // avoid recursive Nodes deallocation
        var node = first
        while let next = node?.next {
            node?.next = nil
            next.previous = nil
            node = next
        }
        last = nil
        first = nil
    }

    final class Node {
        let value: Element
        fileprivate var next: Node?
        fileprivate var previous: Node?

        init(value: Element) {
            self.value = value
        }
    }
}
