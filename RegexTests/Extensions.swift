// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

extension String {
    func index(offsetBy offset: Int) -> String.Index {
        return index(startIndex, offsetBy: offset)
    }
}
