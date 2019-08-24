// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

extension String {
    func index(offsetBy offset: Int) -> String.Index {
        return index(startIndex, offsetBy: offset)
    }

    /// - warning: This is used just for testing purposes!
    func range(of substring: Substring) -> Range<Int> {
        return distance(from: startIndex, to: substring.startIndex)..<distance(from: startIndex, to: substring.endIndex)
    }
}
