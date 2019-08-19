// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

class PerformanceNearlyMatchingInputTests: XCTestCase {

    // NSRegularExpression: 0.165 seconds
    // Regex: 0.025 seconds
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
    // Regex: 0.23 seconds
    func testNearlyMatchingPatternWithLongInput() throws {
        let regex = try Regex("a*c")
        let string = String(repeating: "a", count: 50_000) + "b"

        measure {
            let _ = regex.matches(in: string)
        }
    }

    // NSRegularExpression: 0.106 seconds
    // Regex: 0.028 seconds
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
    // Regex: 0.048 seconds
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
    // Regex: 0.040 seconds
    func testNearlyMatchingPattern() throws {
        let regex = try Regex("X(.+)+X")
        let string = "=XX========================================="

        measure {
             for _ in 0...1000 {
                 let _ = regex.matches(in: string)
             }
         }
    }

    // NSRegularExpression: 0.004 seconds
    // Regex: 0.033 seconds
    func testNearlyMatchingSubstring() throws {
        let p = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaac"
        let s = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab"

        let regex = try Regex(p)

        measure {
            for _ in 0...1000 {
                let _ = regex.matches(in: s)
            }
        }
    }

    // NSRegularExpression: 0.036 seconds
    // Regex: 0.119 seconds
    func testNearlyMatchingSubstringCreateWithRange() throws {
        let regex = try Regex("a{1000}c")
        let string = String(repeating: "a", count: 5_000) + "b"

        measure {
            let _ = regex.matches(in: string)
        }
    }

    // NSRegularExpression: 0.064 seconds
    // Regex: 0.221 seconds
    func testNearlyMatchingSubstringCreateWithRangeAndAlternation() throws {
        let regex = try Regex("(a{1000}|a{800})c")
        let string = String(repeating: "a", count: 5_000) + "b"

        measure {
            let _ = regex.matches(in: string)
        }
    }
}
