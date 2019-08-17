// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

class PerformanceTests: XCTestCase {
    // MARK: - Nearly Matching Input

    // NSRegularExpression: 0.001 seconds
    // Regex: 0.031 seconds
    func testNearlyMatchingSubstring() throws {
        let regex = try Regex("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaac")
        let string = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab"

        measure {
            for _ in 0...10 {
                let _ = regex.matches(in: string)
            }
        }
    }

    // NSRegularExpression: 0.175 seconds
    // Regex: 0.167 seconds
    func testNearlyMatchingPatternWithGreedyQuantifier() throws {
        let regex = try Regex("a*c")
        let string = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab"

        measure {
            for _ in 0...1000 {
                let _ = regex.matches(in: string)
            }
        }
    }

    // NSRegularExpression: 0.002 seconds
    // Regex: 0.051 seconds
    func testNearlyMatchingPatternWithNestedGreedyQuantifier2() throws {
        let regex = try Regex("(aa)*c")
        let string = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab"

        measure {
            for _ in 0...10 {
                let _ = regex.matches(in: string)
            }
        }
    }

    // NSRegularExpression: didn't finish in reasonable time
    // Regex: 0.004 seconds
    func testNearlyMatchingPatternWithNestedGreedyQuantifier() throws {
        let regex = try Regex("(a*)*c")
        let string = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab"

        measure {
            for _ in 0...10 {
                let _ = regex.matches(in: string)
            }
        }
    }
}
