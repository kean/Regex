// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

class PerformanceNearlyMatchingInputTests: XCTestCase {

    // NSRegularExpression: 0.165 seconds
    // Regex: 0.020 seconds
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
    // Regex: 0.21 seconds
    func testNearlyMatchingPatternWithLongInput() throws {
        let regex = try Regex("a*c")
        let string = String(repeating: "a", count: 75_000) + "b"

        measure {
            let _ = regex.matches(in: string)
        }
    }

    // NSRegularExpression: 0.106 seconds
    // Regex: 0.024 seconds
    func testNearlyMatchingPatternWithNestedGreedyQuantifier2() throws {
        let regex = try Regex("(aa)*c")
        let string = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab"

        measure {
            for _ in 0...1500 {
                let _ = regex.matches(in: string)
            }
        }
    }

    // NSRegularExpression: didn't finish in a reasonable time
    // Regex: 0.038 seconds
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
    // Regex: 0.034 seconds
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
    // Regex: 0.027 seconds
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
    // Regex: 0.220 seconds
    func testNearlyMatchingSubstringCreateWithRangeAndAlternation() throws {
        let regex = try Regex("(a{1000}|a{800})c")
        let string = String(repeating: "a", count: 5_000) + "b"

        measure {
            let _ = regex.matches(in: string)
        }
    }
}
