// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

class PerformanceTests: XCTestCase {
    // MARK: - Nearly Matching Input

    // NSRegularExpression: 0.002 seconds
    // Regex: 0.180 seconds
    func testNearlyMatchingSubstring() throws {
        let regex = try Regex("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaac")
        let string = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab"

        measure {
            for _ in 0...1000 {
                let _ = regex.matches(in: string)
            }
        }
    }

    // NSRegularExpression: 0.165 seconds
    // Regex: 0.114 seconds
    func testNearlyMatchingPatternWithGreedyQuantifier() throws {
        let regex = try Regex("a*c")
        let string = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab"

        measure {
            for _ in 0...1000 {
                let _ = regex.matches(in: string)
            }
        }
    }

    // NSRegularExpression: didn't finish in a reasonable time
    // Regex: 0.138 seconds
    func testNearlyMatchingPatternWithLongInput() throws {
        let regex = try Regex("a*c")
        let string = String(repeating: "a", count: 50_000) + "b"

        measure {
            let _ = regex.matches(in: string)
        }
    }

    // NSRegularExpression: 0.106 seconds
    // Regex: 0.137 seconds
    func testNearlyMatchingPatternWithNestedGreedyQuantifier2() throws {
        let regex = try Regex("(aa)*c")
        let string = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab"

        measure {
            for _ in 0...1000 {
                let _ = regex.matches(in: string)
            }
        }
    }

    // NSRegularExpression: didn't finish in a reasonable time
    // Regex: 0.117 seconds
    func testNearlyMatchingPatternWithNestedGreedyQuantifier() throws {
        let regex = try Regex("(a*)*c")
        let string = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab"

        measure {
            for _ in 0...1000 {
                let _ = regex.matches(in: string)
            }
        }
    }

    // NSRegularExpression: didn't finish in a reasonable time
    // Regex: 0.144 seconds
    func testNearlyMatchingPattern() throws {
        let regex = try Regex("X(.+)+X")
        let string = "=XX========================================="

        measure {
             for _ in 0...1000 {
                 let _ = regex.matches(in: string)
             }
         }
    }
}
