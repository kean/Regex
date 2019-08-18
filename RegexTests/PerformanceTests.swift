// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

class PerformanceNearlyMatchingInputTests: XCTestCase {

    // NSRegularExpression: 0.403 seconds
    // Regex: 0.016 seconds
    func testNearlyMatchingSubstringCreateWithRange() throws {
        let regex = try Regex("a{1000}c")
        let string = String(repeating: "a", count: 50_000) + "b"

        measure {
            let _ = regex.matches(in: string)
        }
    }

    // NSRegularExpression: 0.667 seconds
    // Regex: 0.008 seconds
    func testNearlyMatchingSubstringCreateWithRangeAndAlternation() throws {
        let regex = try Regex("(a{1000}|a{800})c")
        let string = String(repeating: "a", count: 50_000) + "b"

        measure {
            let _ = regex.matches(in: string)
        }
    }

    // NSRegularExpression: 0.165 seconds
    // Regex: 0.048 seconds
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
    // Regex: 0.49 seconds
    func testNearlyMatchingPatternWithLongInput() throws {
        let regex = try Regex("a*c")
        let string = String(repeating: "a", count: 50_000) + "b"

        measure {
            let _ = regex.matches(in: string)
        }
    }

    // NSRegularExpression: 0.106 seconds
    // Regex: 0.050 seconds
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
    // Regex: 0.083 seconds
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
    // Regex: 0.70 seconds
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
    // Regex: 0.072 seconds
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
}

class PerformanceCommonRegexesTests: XCTestCase {
    // NSRegularExpression: 0.006 seconds
    // Regex: 0.133 seconds
    // https://www.regexpal.com/?fam=104037
    func testIPv6Address() throws {
        let regex = try Regex(#"^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$"#)

        measure {
            for _ in 0...500 {
                let _ = regex.isMatch("1200:0000:AB00:1234:O000:2552:7777:1313")    // invalid characters present
            }
        }
    }
}
