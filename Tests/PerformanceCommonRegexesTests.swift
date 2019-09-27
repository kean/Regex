// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

// Test some commonly used regular expressions.
class RegexTests: XCTestCase {
    func testColorHexRegex() throws {
        let regex = try Regex("^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$")
        
        measure {
            for _ in 0...1500 {
                _ = regex.isMatch("#1f1f1F")
                _ = regex.isMatch("#AFAFAF")
                _ = regex.isMatch("#1AFFa1")
                _ = regex.isMatch("#222fff")
                _ = regex.isMatch("#F00")
                
                _ = regex.isMatch("123456") // must start with a “#” symbol
                _ = regex.isMatch("#afafah") // 'h' is not allowed
                _ = regex.isMatch("#123abce") // either 6 length or 3 length
                _ = regex.isMatch("aFaE3f") // must start with a “#” symbol
                _ = regex.isMatch("F00") // must start with a “#” symbol
                _ = regex.isMatch("#afaf") // either 6 length or 3 length
            }
        }
    }

    // We expect DFS to perform slightly better in this scenario.
    func testGreedyQuantifiers() throws {
        let regex = try Regex("a*")

        measure {
            for _ in 0...100 {
                _ = regex.isMatch(String(repeating: "a", count: 1_000))
            }
        }
    }
}

// From https://digitalfortress.tech/tricks/top-15-commonly-used-regex/
class RegexDiditalFortressCommonlyUsedRegexTests: XCTestCase {
    
    // MARK: - Numbers
    
    // https://www.regexpal.com/?fam=104020
    func testWholeNumber() throws {
        let regex = try Regex(#"^\d+$"#)
        
        measure {
            for _ in 0...10000 {
                _ = regex.isMatch("45")
                _ = regex.isMatch("45.5")
                _ = regex.isMatch("+99")
                _ = regex.isMatch("-100")
                _ = regex.isMatch("0")
            }
        }
    }
    
    // https://www.regexpal.com/?fam=104021
    func testDecimalNumber() throws {
        let regex = try Regex(#"^\d*\.\d+$"#)
        
        measure {
            for _ in 0...5000 {
                _ = regex.isMatch("100")
                _ = regex.isMatch("10.2")
                _ = regex.isMatch("0.5")
                _ = regex.isMatch("0.")
                _ = regex.isMatch(".5")
                _ = regex.isMatch("-0.5")
                _ = regex.isMatch("+0.5")
            }
        }
    }
    
    // https://www.regexpal.com/?fam=104022
    func testWholePlusDecimalNumber() throws {
        let regex = try Regex(#"^\d*(\.\d+)?$"#)
        
        measure {
            for _ in 0...5000 {
                _ = regex.isMatch("5.0")
                _ = regex.isMatch("3")
                _ = regex.isMatch("0.0")
                _ = regex.isMatch("-3.5")
                _ = regex.isMatch("+2.5")
                _ = regex.isMatch("+2")
                _ = regex.isMatch("-3")
                _ = regex.isMatch("100")
            }
        }
    }
    
    // https://www.regexpal.com/?fam=104023
    func testNegativePositiveWholeAndDecimalNumber() throws {
        let regex = try Regex(#"^-?\d*(\.\d+)?$"#)
        
        measure {
            for _ in 0...1500 {
                _ = regex.isMatch("100")
                _ = regex.isMatch("10.2")
                _ = regex.isMatch("0.5")
                _ = regex.isMatch("0.")
                _ = regex.isMatch(".5")
                _ = regex.isMatch("-0.5")
                _ = regex.isMatch("-100")
                _ = regex.isMatch("abcd")
            }
        }
    }
    
    // https://www.regexpal.com/94462
    func testWholePlusDecimalPlusFractionNumber() throws {
        let regex = try Regex(#"^[-]?[0-9]+[,.]?[0-9]*([\/][0-9]+[,.]?[0-9]*)*$"#)
        
        measure {
            for _ in 0...1000 {
                _ = regex.isMatch("123.4")
                _ = regex.isMatch("123")
                _ = regex.isMatch("21cc")
                _ = regex.isMatch("3/4")
                _ = regex.isMatch("23.4/21")
                _ = regex.isMatch("-23/")
                _ = regex.isMatch("-3")
                _ = regex.isMatch("-4,55/2345.24")
                _ = regex.isMatch("4.33/")
                _ = regex.isMatch("abcd")
            }
        }
    }
    
    // https://www.regexpal.com/?fam=104024
    func testAlphanumericWithoutSpace() throws {
        let regex = try Regex("^[a-zA-Z0-9]*$")
        
        measure {
            for _ in 0...5000 {
                _ = regex.isMatch("hello")
                _ = regex.isMatch("what")
                _ = regex.isMatch("how are you?")
                _ = regex.isMatch("hi5")
                _ = regex.isMatch("8ask")
            }
        }
    }
    
    // https://www.regexpal.com/?fam=104025
    func testAlphanumericWithSpace() throws {
        let regex = try Regex("^[a-zA-Z0-9 ]*$")
        
        measure {
            for _ in 0...1000 {
                _ = regex.isMatch("hello")
                _ = regex.isMatch("what")
                _ = regex.isMatch("how are you")
                _ = regex.isMatch("how are you?")
                _ = regex.isMatch("hi5")
                _ = regex.isMatch("8ask")
                _ = regex.isMatch("yyyy.")
                _ = regex.isMatch("\t! dff")
                _ = regex.isMatch("NoSpecialcharacters#")
                _ = regex.isMatch("54445566")
            }
        }
    }
    
    // MARK: - Email
    
    // https://www.regexpal.com/?fam=104026
    func testCommonEmail() throws {
        let regex = try Regex(#"^([a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6})*$"#)
        
        measure {
            for _ in 0...200 {
                _ = regex.isMatch("email@example.com")
                _ = regex.isMatch("firstname.lastname@example.com")
                _ = regex.isMatch("email@subdomain.example.com")
                _ = regex.isMatch("firstname+lastname@example.com") // this is actually valid
                _ = regex.isMatch("email@123.123.123.123")          // valid
                _ = regex.isMatch("email@[123.123.123.123]")        // valid
                _ = regex.isMatch("\"email\"@example.com")          // valid
                _ = regex.isMatch("1234567890@example.com")
                _ = regex.isMatch("email@example-one.com")
                _ = regex.isMatch("_______@example.com")
                _ = regex.isMatch("email@example.name")
                _ = regex.isMatch("email@example.museum")
                _ = regex.isMatch("email@example.co.jp")
                _ = regex.isMatch("firstname-lastname@example.com")
            }
        }
    }
    
    // https://www.regexpal.com/?fam=104027
    func testUncommonEmail() throws {
        let regex = try Regex(#"^([a-z0-9_\.\+-]+)@([\da-z\.-]+)\.([a-z\.]{2,6})$"#)
        
        measure {
            for _ in 0...200 {
                _ = regex.isMatch("email@example.com")
                _ = regex.isMatch("firstname.lastname@example.com")
                _ = regex.isMatch("email@subdomain.example.com")
                _ = regex.isMatch("firstname+lastname@example.com")
                _ = regex.isMatch("1234567890@example.com")
                _ = regex.isMatch("email@example-one.com")
                _ = regex.isMatch("_______@example.com")
                _ = regex.isMatch("email@example.name")
                _ = regex.isMatch("email@example.museum")
                _ = regex.isMatch("email@example.co.jp")
                _ = regex.isMatch("firstname-lastname@example.com")
                _ = regex.isMatch("_@baz.com")
            }
        }
    }
    
    // MARK: - Passwords
    
    // https://www.regexpal.com/?fam=104028
    func _testComplex() throws {
        // TODO: fails because we don't support '?=' (Zero-Width Positive Lookahead Assertions)
        
        let regex = try Regex(#"(?=(.*[0-9])(?=.*[\!@#$%^&*()\\[\]{}\-_+=~`|:;"'<>,./?])(?=.*[a-z])(?=(.*[A-Z])(?=(.*).{8,}"#)
        
        measure {
            _ = regex.isMatch("hello")
            _ = regex.isMatch("helloworld")
            _ = regex.isMatch("helloWorld")
            _ = regex.isMatch("helloWorld555")
            _ = regex.isMatch("helloWorld555@")
            _ = regex.isMatch("helloWorld555@!")
        }
    }
    
    // https://www.regexpal.com/?fam=104029
    func _testModerate() throws {
        // TODO: fails because we don't support '?=' (Zero-Width Positive Lookahead Assertions)
        
        let regex = try Regex(#"(?=(.*[0-9])((?=.*[A-Za-z0-9])(?=.*[A-Z])(?=.*[a-z])^.{8,}$"#)
        
        measure {
            _ = regex.isMatch("hello")
            _ = regex.isMatch("hello5")
            _ = regex.isMatch("helloworld")
            _ = regex.isMatch("helloWorld")
            _ = regex.isMatch("helloWorld555")
            _ = regex.isMatch("hello555@")
            _ = regex.isMatch("Hello555")
            _ = regex.isMatch("helloWorld555@!")
        }
    }
    
    // https://www.regexpal.com/?fam=104030
    func testUsername() throws {
        let regex = try Regex(#"^[a-z0-9_-]{3,16}$"#, [.caseInsensitive])
        
        measure {
            for _ in 0...1000 {
                _ = regex.isMatch("hi")
                _ = regex.isMatch("hi!")
                _ = regex.isMatch("hie")
                _ = regex.isMatch("helloWorld")
                _ = regex.isMatch("hello@world")
                _ = regex.isMatch("hello_world")
                _ = regex.isMatch("hello!world")
                _ = regex.isMatch("hello-world")
            }
        }
    }
    
    // MARK: - URLs
    
    // https://www.regexpal.com/?fam=104034
    func testURL() throws {
        let regex = try Regex(#"^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#()?&\/=]*)$"#)
        
        measure {
            for _ in 0...100 {
                _ = regex.isMatch("http://foo.com/blah_blah")
                _ = regex.isMatch("http://foo.com/blah_blah/")
                _ = regex.isMatch("http://foo.com/blah_blah_(wikipedia)")
                _ = regex.isMatch("http://www.example.com/wpstyle/?p=364")
                _ = regex.isMatch("https://www.example.com/foo/?bar=baz&inga=42&quux")
                _ = regex.isMatch("http://userid:password@example.com:8080")
                _ = regex.isMatch("http://foo.com/blah_(wikipedia)#cite-1")
                _ = regex.isMatch("www.google.com")
                _ = regex.isMatch("http://../")
                _ = regex.isMatch("http:// shouldfail.com")
                _ = regex.isMatch("http://224.1.1.1")
                _ = regex.isMatch("http://142.42.1.1:8080/")
                _ = regex.isMatch("ftp://foo.bar/baz")
                _ = regex.isMatch("http://1337.net")
                _ = regex.isMatch("http://foo.bar/?q=Test%20URL-encoded%20stuff")
                _ = regex.isMatch("http://code.google.com/events/#&product=browser")
                _ = regex.isMatch("http://-error-.invalid/")
                _ = regex.isMatch("http://3628126748")
                _ = regex.isMatch("http://उदाहरण.परीक्षा")
            }
        }
    }
    
    // https://www.regexpal.com/?fam=104035
    func testURLProtocolOptional() throws {
        let regex = try Regex(#"^(https?:\/\/)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#()?&\/=]*)$"#)
        
        measure {
            for _ in 0...100 {
                _ = regex.isMatch("http://foo.com/blah_blah")
                _ = regex.isMatch("http://foo.com/blah_blah/")
                _ = regex.isMatch("http://foo.com/blah_blah_(wikipedia)")
                _ = regex.isMatch("http://www.example.com/wpstyle/?p=364")
                _ = regex.isMatch("https://www.example.com/foo/?bar=baz&inga=42&quux")
                _ = regex.isMatch("http://userid:password@example.com:8080")
                _ = regex.isMatch("http://foo.com/blah_(wikipedia)#cite-1")
                _ = regex.isMatch("google.com")
                _ = regex.isMatch("www.google.com")
                _ = regex.isMatch("http://../")
                _ = regex.isMatch("http://224.1.1.1")
                _ = regex.isMatch("http://142.42.1.1:8080/")
                _ = regex.isMatch("ftp://foo.bar/baz")
                _ = regex.isMatch("http://1337.net")
                _ = regex.isMatch("http://foo.bar/?q=Test%20URL-encoded%20stuff")
                _ = regex.isMatch("http://code.google.com/events/#&product=browser")
                _ = regex.isMatch("http://-error-.invalid/")
                _ = regex.isMatch("http://3628126748")
                _ = regex.isMatch("http://उदाहरण.परीक्षा")
            }
        }
    }
    
    // MARK: - IP Addresses
    
    // https://www.regexpal.com/?fam=104036
    func testIPv4Address() throws {
        let regex = try Regex(#"^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"#)
        
        measure {
            for _ in 0...500 {
                _ = regex.isMatch("0.0.0.0")
                _ = regex.isMatch("9.255.255.255")
                _ = regex.isMatch("11.0.0.0")
                _ = regex.isMatch("126.255.255.255")
                _ = regex.isMatch("129.0.0.0")
                _ = regex.isMatch("169.253.255.255")
                _ = regex.isMatch("169.255.0.0")
                _ = regex.isMatch("172.15.255.255")
                _ = regex.isMatch("172.32.0.0")
                _ = regex.isMatch("256.0.0.0")
                _ = regex.isMatch("191.0.1.255")
                _ = regex.isMatch("192.88.98.255")
                _ = regex.isMatch("192.88.100.0")
                _ = regex.isMatch("192.167.255.255")
                _ = regex.isMatch("192.169.0.0")
                _ = regex.isMatch("198.17.255.255")
                _ = regex.isMatch("223.255.255.255")
            }
        }
    }
    
    // https://www.regexpal.com/?fam=104037
    func _testIPv6Address() throws {
        let regex = try Regex(#"^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])$"#)
        
        measure {
            _ = regex.isMatch("1200:0000:AB00:1234:0000:2552:7777:1313")
            _ = regex.isMatch("1200::AB00:1234::2552:7777:1313")
            _ = regex.isMatch("21DA:D3:0:2F3B:2AA:FF:FE28:9C5A")
            _ = regex.isMatch("1200:0000:AB00:1234:O000:2552:7777:1313")    // invalid characters present
            _ = regex.isMatch("FE80:0000:0000:0000:0202:B3FF:FE1E:8329")
            _ = regex.isMatch("[2001:db8:0:1]:80")                          // valid, no support for port numbers
            _ = regex.isMatch("http://[2001:db8:0:1]:80")                   // valid, no support for IP address in a URL
        }
    }
    
    // MARK: - Date Format
    
    // https://www.regexpal.com/?fam=104039
    func _testValidateDateFormat() throws {
        let regex = try Regex(#"^([12]\d{3}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$"#)
        
        measure {
            _ = regex.isMatch("1900-10-23")
            _ = regex.isMatch("2002-5-5")
            _ = regex.isMatch("2009-23-5")
            _ = regex.isMatch("2008-09-31")
            _ = regex.isMatch("1600-12-25")
            _ = regex.isMatch("1942-11-1")
            _ = regex.isMatch("1942-11-0")
            _ = regex.isMatch("1942-00-25")
            _ = regex.isMatch("2000-10-00")
            _ = regex.isMatch("2000-10-10")
        }
    }
    
    // https://regexr.com/?346hf
    func _testValidateDateFormat2() throws {
        let regex = try Regex(#"^^(?:(?:31(\/|-|\.)(?:0?[13578]|1[02])\1|(?:(?:29|30)(\/|-|\.)(?:0?[1,3-9]|1[0-2])\2)(?:(?:1[6-9]|[2-9]\d)?\d{2})$|^(?:29(\/|-|\.)0?2\3(?:(?:(?:1[6-9]|[2-9]\d)?(?:0[48]|[2468][048]|[13579][26])|(?:(?:16|[2468][048]|[3579][26])00))$|^(?:0?[1-9]|1\d|2[0-8])(\/|-|\.)(?:(?:0?[1-9])|(?:1[0-2])\4(?:(?:1[6-9]|[2-9]\d)?\d{2})$"#)
        
        measure {
            _ = regex.isMatch("01/01/2000")
            _ = regex.isMatch("31/01/2000")
            _ = regex.isMatch("32/01/2000")
            _ = regex.isMatch("01/1/2000")
            _ = regex.isMatch("01/1/01")
            
            _ = regex.isMatch("29/02/2000")
            _ = regex.isMatch("28/02/2001")
            _ = regex.isMatch("29/02/2001")
            
            _ = regex.isMatch("30/04/2000")
            _ = regex.isMatch("31/04/2000")
            
            _ = regex.isMatch("31/07/2000")
            _ = regex.isMatch("31/08/2000")
            _ = regex.isMatch("31/09/2000")
            _ = regex.isMatch("01/12/2000")
            _ = regex.isMatch("01/15/2000")
        }
    }
    
    // https://regexr.com/39tr1
    func _testValidateDateFormat3() throws {
        let regex = try Regex(#"^(?:(?:31(\/|-|\.)(?:0?[13578]|1[02]|(?:Jan|Mar|May|Jul|Aug|Oct|Dec))\1|(?:(?:29|30)(\/|-|\.)(?:0?[1,3-9]|1[0-2]|(?:Jan|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\2)(?:(?:1[6-9]|[2-9]\d)?\d{2})$|^(?:29(\/|-|\.)(?:0?2|(?:Feb)\3(?:(?:(?:1[6-9]|[2-9]\d)?(?:0[48]|[2468][048]|[13579][26])|(?:(?:16|[2468][048]|[3579][26])00))$|^(?:0?[1-9]|1\d|2[0-8])(\/|-|\.)(?:(?:0?[1-9]|(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep)|(?:1[0-2]|(?:Oct|Nov|Dec))\4(?:(?:1[6-9]|[2-9]\d)?\d{2})$"#)
        
        measure {
            _ = regex.isMatch("01/01/2000")
            _ = regex.isMatch("01/Jan/2000")
            _ = regex.isMatch("31/01/2000")
            _ = regex.isMatch("31/Jan/2000")
            _ = regex.isMatch("31.Jan.2000")
            _ = regex.isMatch("31-Jan-2000")
            _ = regex.isMatch("32/01/2000")
            _ = regex.isMatch("32/Jan/2000")
            _ = regex.isMatch("01/1/2000")
            _ = regex.isMatch("01/Jan/2000")
            _ = regex.isMatch("01/1/01")
            _ = regex.isMatch("01/Jan/01")
            
            _ = regex.isMatch("29/02/2000")
            _ = regex.isMatch("29/Feb/2000")
            _ = regex.isMatch("28/02/2001")
            _ = regex.isMatch("28/Feb/2001")
            _ = regex.isMatch("29/02/2001")
            _ = regex.isMatch("29/Feb/2001")
            
            _ = regex.isMatch("30/04/2000")
            _ = regex.isMatch("30/Apr/2000")
            _ = regex.isMatch("31/04/2000")
            _ = regex.isMatch("31/Apr/2000")
            
            _ = regex.isMatch("31/07/2000")
            _ = regex.isMatch("31/Jul/2000")
            
            _ = regex.isMatch("31/08/2000")
            _ = regex.isMatch("31/Aug/2000")
            
            _ = regex.isMatch("31/09/2000")
            _ = regex.isMatch("31/Sep/2000")
            
            _ = regex.isMatch("01/12/2000")
            _ = regex.isMatch("01/Dec/2000")
            
            _ = regex.isMatch("01/15/2000")
        }
    }
    
    // MARK: - Time Format
    
    // https://www.regexpal.com/?fam=104040
    func testTimeFormat() throws {
        let regex = try Regex(#"^(0?[1-9]|1[0-2]):[0-5][0-9]$"#)
        
        measure {
            for _ in 0...1500 {
                _ = regex.isMatch("12:00")
                _ = regex.isMatch("13:00")
                _ = regex.isMatch("1:00")
                _ = regex.isMatch("5:5")
                _ = regex.isMatch("5:05")
                _ = regex.isMatch("55:55")
                _ = regex.isMatch("09:59")
                _ = regex.isMatch(":01")
                _ = regex.isMatch("0:59")
                _ = regex.isMatch("00:59")
                _ = regex.isMatch("01:59")
            }
        }
    }
    
    // https://www.regexpal.com/?fam=104041
    func _testTimeFormat2() throws {
        let regex = try Regex("^((1[0-2]|0?[1-9]):([0-5][0-9]) ?([AaPp][Mm])$")
        
        measure {
            for _ in 0...100 {
                _ = regex.isMatch("12:00 pm")
                _ = regex.isMatch("13:00")
                _ = regex.isMatch("1:00 am")
                _ = regex.isMatch("5:5 am")
                _ = regex.isMatch("5:05 PM")
                _ = regex.isMatch("55:55")
                _ = regex.isMatch("09:59")    // valid time, but meridiem is missing
                _ = regex.isMatch(":01")
                _ = regex.isMatch("0:59")
                _ = regex.isMatch("00:59 PM")
                _ = regex.isMatch("01:59 AM")
            }
        }
    }
    
    // https://www.regexpal.com/?fam=104042
    func testTimeFormat3() throws {
        let regex = try Regex(#"^(0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]$"#)
        
        measure {
            for _ in 0...1500 {
                _ = regex.isMatch("12:00")
                _ = regex.isMatch("13:00")
                _ = regex.isMatch("1:00")
                _ = regex.isMatch("5:5")
                _ = regex.isMatch("5:05")
                _ = regex.isMatch("55:55")
                _ = regex.isMatch("09:59")
                _ = regex.isMatch(":01")
                _ = regex.isMatch("0:59")
                _ = regex.isMatch("00:59")
                _ = regex.isMatch("01:59")
                _ = regex.isMatch("24:00")
                _ = regex.isMatch("24:59")
                _ = regex.isMatch("23:59")
            }
        }
    }
    
    // https://www.regexpal.com/?fam=104043
    func testTimeFormat4() throws {
        let regex = try Regex(#"^(0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]$"#)
        
        measure {
            for _ in 0...1500 {
                _ = regex.isMatch("12:00")
                _ = regex.isMatch("13:00")
                _ = regex.isMatch("1:00")
                _ = regex.isMatch("5:5")
                _ = regex.isMatch("5:05")
                _ = regex.isMatch("55:55")
                _ = regex.isMatch("09:59")
                _ = regex.isMatch(":01")
                _ = regex.isMatch("0:59")
                _ = regex.isMatch("00:59")
                _ = regex.isMatch("01:59")
                _ = regex.isMatch("24:00")
                _ = regex.isMatch("24:59")
                _ = regex.isMatch("23:59")
            }
        }
    }
    
    // https://www.regexpal.com/?fam=104044
    func testTimeFormat5() throws {
        let regex = try Regex(#"(?:[01]\d|2[0123]):(?:[012345]\d):(?:[012345]\d)"#)
        
        measure {
            for _ in 0...1000 {
                _ = regex.isMatch("12:00")
                _ = regex.isMatch("13:00:00")
                _ = regex.isMatch("1:00:59")
                _ = regex.isMatch("5:5:59")
                _ = regex.isMatch("5:05:20")
                _ = regex.isMatch("09:59:23")
                _ = regex.isMatch(":01:01")
                _ = regex.isMatch("0:59:23")
                _ = regex.isMatch("00:59:61")
                _ = regex.isMatch("01:59:22")
                _ = regex.isMatch("24:00:00")
                _ = regex.isMatch("24:59:")
                _ = regex.isMatch("23:59:9")
                _ = regex.isMatch("23:59:19")
            }
        }
    }
    
    // MARK: HTML
    
    // https://www.regexpal.com/95941
    func testHTMLTags() throws {
        let pattern = #"<\/?[\w\s]*>|<.+[\W]>"#
        let string = """
        <h2 class="offscreen">Webontwikkeling leren</h2>
        <h1>Regular Expressions</h1>
        <p>"Alle onderdelen van MDN (documenten en de website zelf) worden gemaakt door een open gemeenschap."</p>
        <a href="/nl/docs/MDN/Getting_started">Aan de slag</a>
        <bed el = ekf"eee>
        """
        
        let regex = try Regex(pattern)
        measure {
            for _ in 0...150 {
                _ = regex.matches(in: string)
            }
        }
    }
    
    // MARK: JavaScript
    
    // https://www.regexpal.com/?fam=104055
    func _testJavaScriptHandler() throws {
        let pattern = #"\bon\w+=\S+(?=.*>)"#
        let string = """
        <img src="foo.jpg" onload=function_xyz />
        <img onmessage="javascript:execute()">
            <a notonmessage="nomatch-here" onfocus="alert('hey')" onclick=foo() disabled>
        <p>
            Things that are just onfoo="something" shouldn't match either, since they are outside of a tag
        </p>
        """
        
        let regex = try Regex(pattern)
        measure {
            _ = regex.matches(in: string)
        }
    }
    
    // https://www.regexpal.com/94641
    func _testJavaScriptHandlerWithElement() throws {
        let pattern = #"(?:<[^>]+\s)(on\S+)=["']?((?:.(?!["']?\s+(?:\S+)=|[>"'])+.)["']?"#
        let string = """
        <img src="foo.jpg" onload="something" />
            <img onmessage="javascript:foo()">
        <a notonmessage="nomatch-here">
        <p>
        things that are just onfoo="bar" shouldn't match either, outside of a tag
        </p>
        """
        
        let regex = try Regex(pattern)
        
        measure {
            _ = regex.matches(in: string).map { $0.fullMatch }
        }
    }
    
    // MARK: Slug
    
    // https://www.regexpal.com/?fam=104056
    func testSlug() throws {
        let pattern = "^[a-z0-9]+(?:-[a-z0-9]+)*$"
        
        let regex = try Regex(pattern, [.caseInsensitive])
        
        measure {
            for _ in 0...400 {
                _ = regex.isMatch("hello")
                _ = regex.isMatch("Hello")
                _ = regex.isMatch("-")
                _ = regex.isMatch("hello-")
                _ = regex.isMatch("-hello")
                _ = regex.isMatch("-hello-")
                _ = regex.isMatch("hello-world")
                _ = regex.isMatch("hello---")
                _ = regex.isMatch("hello-$-world")
                _ = regex.isMatch("hello-456-world")
                _ = regex.isMatch("456-hello")
                _ = regex.isMatch("456-World")
                _ = regex.isMatch("456")
            }
        }
    }
}
