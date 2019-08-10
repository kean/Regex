// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

// Test some commonly used regular expressions.
class RegexTests: XCTestCase {
    func testColorHexRegex() throws {
        let regex = try Regex("^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$")

        XCTAssertTrue(regex.isMatch("#1f1f1F"))
        XCTAssertTrue(regex.isMatch("#AFAFAF"))
        XCTAssertTrue(regex.isMatch("#1AFFa1"))
        XCTAssertTrue(regex.isMatch("#222fff"))
        XCTAssertTrue(regex.isMatch("#F00"))

        XCTAssertFalse(regex.isMatch("123456")) // must start with a “#” symbol
        XCTAssertFalse(regex.isMatch("#afafah")) // 'h' is not allowed
        XCTAssertFalse(regex.isMatch("#123abce")) // either 6 length or 3 length
        XCTAssertFalse(regex.isMatch("aFaE3f")) // must start with a “#” symbol
        XCTAssertFalse(regex.isMatch("F00")) // must start with a “#” symbol
        XCTAssertFalse(regex.isMatch("#afaf")) // either 6 length or 3 length
    }
}

// From https://digitalfortress.tech/tricks/top-15-commonly-used-regex/
class RegexDiditalFortressCommonlyUsedRegexTests: XCTestCase {

    // MARK: - Numbers

    // https://www.regexpal.com/?fam=104020
    func testWholeNumber() throws {
        let regex = try Regex(#"^\d+$"#)

        XCTAssertTrue(regex.isMatch("45"))
        XCTAssertFalse(regex.isMatch("45.5"))
        XCTAssertFalse(regex.isMatch("+99"))
        XCTAssertFalse(regex.isMatch("-100"))
        XCTAssertTrue(regex.isMatch("0"))
    }

    // https://www.regexpal.com/?fam=104021
    func testDecimalNumber() throws {
        let regex = try Regex(#"^\d*\.\d+$"#)

        XCTAssertFalse(regex.isMatch("100"))
        XCTAssertTrue(regex.isMatch("10.2"))
        XCTAssertTrue(regex.isMatch("0.5"))
        XCTAssertFalse(regex.isMatch("0."))
        XCTAssertTrue(regex.isMatch(".5"))
        XCTAssertFalse(regex.isMatch("-0.5"))
        XCTAssertFalse(regex.isMatch("+0.5"))
    }

    // https://www.regexpal.com/?fam=104022
    func testWholePlusDecimalNumber() throws {
        let regex = try Regex(#"^\d*(\.\d+)?$"#)

        XCTAssertTrue(regex.isMatch("5.0"))
        XCTAssertTrue(regex.isMatch("3"))
        XCTAssertTrue(regex.isMatch("0.0"))
        XCTAssertFalse(regex.isMatch("-3.5"))
        XCTAssertFalse(regex.isMatch("+2.5"))
        XCTAssertFalse(regex.isMatch("+2"))
        XCTAssertFalse(regex.isMatch("-3"))
        XCTAssertTrue(regex.isMatch("100"))
    }

    // https://www.regexpal.com/?fam=104023
    func testNegativePositiveWholeAndDecimalNumber() throws {
        let regex = try Regex(#"^-?\d*(\.\d+)?$"#)

        XCTAssertTrue(regex.isMatch("100"))
        XCTAssertTrue(regex.isMatch("10.2"))
        XCTAssertTrue(regex.isMatch("0.5"))
        XCTAssertFalse(regex.isMatch("0."))
        XCTAssertTrue(regex.isMatch(".5"))
        XCTAssertTrue(regex.isMatch("-0.5"))
        XCTAssertTrue(regex.isMatch("-100"))
        XCTAssertFalse(regex.isMatch("abcd"))
    }

    // https://www.regexpal.com/94462
    func testWholePlusDecimalPlusFractionNumber() throws {
        let regex = try Regex(#"^[-]?[0-9]+[,.]?[0-9]*([\/][0-9]+[,.]?[0-9]*)*$"#)

        XCTAssertTrue(regex.isMatch("123.4"))
        XCTAssertTrue(regex.isMatch("123"))
        XCTAssertFalse(regex.isMatch("21cc"))
        XCTAssertTrue(regex.isMatch("3/4"))
        XCTAssertTrue(regex.isMatch("23.4/21"))
        XCTAssertFalse(regex.isMatch("-23/"))
        XCTAssertTrue(regex.isMatch("-3"))
        XCTAssertTrue(regex.isMatch("-4,55/2345.24"))
        XCTAssertFalse(regex.isMatch("4.33/"))
        XCTAssertFalse(regex.isMatch("abcd"))
    }

    // https://www.regexpal.com/?fam=104024
    func testAlphanumericWithoutSpace() throws {
        let regex = try Regex("^[a-zA-Z0-9]*$")

        XCTAssertTrue(regex.isMatch("hello"))
        XCTAssertTrue(regex.isMatch("what"))
        XCTAssertFalse(regex.isMatch("how are you?"))
        XCTAssertTrue(regex.isMatch("hi5"))
        XCTAssertTrue(regex.isMatch("8ask"))
    }

    // https://www.regexpal.com/?fam=104025
    func testAlphanumericWithSpace() throws {
        let regex = try Regex("^[a-zA-Z0-9 ]*$")

        XCTAssertTrue(regex.isMatch("hello"))
        XCTAssertTrue(regex.isMatch("what"))
        XCTAssertTrue(regex.isMatch("how are you"))
        XCTAssertFalse(regex.isMatch("how are you?"))
        XCTAssertTrue(regex.isMatch("hi5"))
        XCTAssertTrue(regex.isMatch("8ask"))
        XCTAssertFalse(regex.isMatch("yyyy."))
        XCTAssertFalse(regex.isMatch("\t! dff"))
        XCTAssertFalse(regex.isMatch("NoSpecialcharacters#"))
        XCTAssertTrue(regex.isMatch("54445566"))
    }

    // MARK: - Email

    // https://www.regexpal.com/?fam=104026
    func testCommonEmail() throws {
        let regex = try Regex(#"^([a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6})*$"#)

        XCTAssertTrue(regex.isMatch("email@example.com"))
        XCTAssertTrue(regex.isMatch("firstname.lastname@example.com"))
        XCTAssertTrue(regex.isMatch("email@subdomain.example.com"))
        XCTAssertFalse(regex.isMatch("firstname+lastname@example.com")) // this is actually valid
        XCTAssertFalse(regex.isMatch("email@123.123.123.123"))          // valid
        XCTAssertFalse(regex.isMatch("email@[123.123.123.123]"))        // valid
        XCTAssertFalse(regex.isMatch("\"email\"@example.com"))          // valid
        XCTAssertTrue(regex.isMatch("1234567890@example.com"))
        XCTAssertTrue(regex.isMatch("email@example-one.com"))
        XCTAssertTrue(regex.isMatch("_______@example.com"))
        XCTAssertTrue(regex.isMatch("email@example.name"))
        XCTAssertTrue(regex.isMatch("email@example.museum"))
        XCTAssertTrue(regex.isMatch("email@example.co.jp"))
        XCTAssertTrue(regex.isMatch("firstname-lastname@example.com"))
    }

    // https://www.regexpal.com/?fam=104027
    func testUncommonEmail() throws {
        let regex = try Regex(#"^([a-z0-9_\.\+-]+)@([\da-z\.-]+)\.([a-z\.]{2,6})$"#)

        XCTAssertTrue(regex.isMatch("email@example.com"))
        XCTAssertTrue(regex.isMatch("firstname.lastname@example.com"))
        XCTAssertTrue(regex.isMatch("email@subdomain.example.com"))
        XCTAssertTrue(regex.isMatch("firstname+lastname@example.com"))
        XCTAssertTrue(regex.isMatch("1234567890@example.com"))
        XCTAssertTrue(regex.isMatch("email@example-one.com"))
        XCTAssertTrue(regex.isMatch("_______@example.com"))
        XCTAssertTrue(regex.isMatch("email@example.name"))
        XCTAssertTrue(regex.isMatch("email@example.museum"))
        XCTAssertTrue(regex.isMatch("email@example.co.jp"))
        XCTAssertTrue(regex.isMatch("firstname-lastname@example.com"))
        XCTAssertTrue(regex.isMatch("_@baz.com"))
    }

    // MARK: - Passwords

    // https://www.regexpal.com/?fam=104028
    func testComplex() throws {
        // TODO: fails because we don't support '?=' (Zero-Width Positive Lookahead Assertions)

        let regex = try Regex(#"(?=(.*[0-9]))(?=.*[\!@#$%^&*()\\[\]{}\-_+=~`|:;"'<>,./?])(?=.*[a-z])(?=(.*[A-Z]))(?=(.*)).{8,}"#)

        XCTAssertFalse(regex.isMatch("hello"))
        XCTAssertFalse(regex.isMatch("helloworld"))
        XCTAssertFalse(regex.isMatch("helloWorld"))
        XCTAssertFalse(regex.isMatch("helloWorld555"))
        XCTAssertTrue(regex.isMatch("helloWorld555@"))
        XCTAssertTrue(regex.isMatch("helloWorld555@!"))
    }

    // https://www.regexpal.com/?fam=104029
    func testModerate() throws {
        // TODO: fails because we don't support '?=' (Zero-Width Positive Lookahead Assertions)

        let regex = try Regex(#"(?=(.*[0-9]))((?=.*[A-Za-z0-9])(?=.*[A-Z])(?=.*[a-z]))^.{8,}$"#)

        XCTAssertFalse(regex.isMatch("hello"))
        XCTAssertFalse(regex.isMatch("hello5"))
        XCTAssertFalse(regex.isMatch("helloworld"))
        XCTAssertFalse(regex.isMatch("helloWorld"))
        XCTAssertTrue(regex.isMatch("helloWorld555"))
        XCTAssertFalse(regex.isMatch("hello555@"))
        XCTAssertTrue(regex.isMatch("Hello555"))
        XCTAssertTrue(regex.isMatch("helloWorld555@!"))
    }

    // https://www.regexpal.com/?fam=104030
    func testUsername() throws {
        let regex = try Regex(#"^[a-z0-9_-]{3,16}$"#, [.caseInsensitive])

        XCTAssertFalse(regex.isMatch("hi"))
        XCTAssertFalse(regex.isMatch("hi!"))
        XCTAssertTrue(regex.isMatch("hie"))
        XCTAssertTrue(regex.isMatch("helloWorld"))
        XCTAssertFalse(regex.isMatch("hello@world"))
        XCTAssertTrue(regex.isMatch("hello_world"))
        XCTAssertFalse(regex.isMatch("hello!world"))
        XCTAssertTrue(regex.isMatch("hello-world"))
    }

    // MARK: - URLs

    // https://www.regexpal.com/?fam=104034
    func testURL() throws {
        let regex = try Regex(#"^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#()?&\/=]*)$"#)

        XCTAssertTrue(regex.isMatch("http://foo.com/blah_blah"))
        XCTAssertTrue(regex.isMatch("http://foo.com/blah_blah/"))
        XCTAssertTrue(regex.isMatch("http://foo.com/blah_blah_(wikipedia)"))
        XCTAssertTrue(regex.isMatch("http://www.example.com/wpstyle/?p=364"))
        XCTAssertTrue(regex.isMatch("https://www.example.com/foo/?bar=baz&inga=42&quux"))
        XCTAssertTrue(regex.isMatch("http://userid:password@example.com:8080"))
        XCTAssertTrue(regex.isMatch("http://foo.com/blah_(wikipedia)#cite-1"))
        XCTAssertFalse(regex.isMatch("www.google.com"))
        XCTAssertFalse(regex.isMatch("http://../"))
        XCTAssertFalse(regex.isMatch("http:// shouldfail.com"))
        XCTAssertFalse(regex.isMatch("http://224.1.1.1"))
        XCTAssertFalse(regex.isMatch("http://142.42.1.1:8080/"))
        XCTAssertFalse(regex.isMatch("ftp://foo.bar/baz"))
        XCTAssertTrue(regex.isMatch("http://1337.net"))
        XCTAssertTrue(regex.isMatch("http://foo.bar/?q=Test%20URL-encoded%20stuff"))
        XCTAssertTrue(regex.isMatch("http://code.google.com/events/#&product=browser"))
        XCTAssertFalse(regex.isMatch("http://-error-.invalid/"))
        XCTAssertFalse(regex.isMatch("http://3628126748"))
        XCTAssertFalse(regex.isMatch("http://उदाहरण.परीक्षा"))
    }

    // https://www.regexpal.com/?fam=104035
    func testURLProtocolOptional() throws {
        let regex = try Regex(#"^(https?:\/\/)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#()?&\/=]*)$"#)

        XCTAssertTrue(regex.isMatch("http://foo.com/blah_blah"))
        XCTAssertTrue(regex.isMatch("http://foo.com/blah_blah/"))
        XCTAssertTrue(regex.isMatch("http://foo.com/blah_blah_(wikipedia)"))
        XCTAssertTrue(regex.isMatch("http://www.example.com/wpstyle/?p=364"))
        XCTAssertTrue(regex.isMatch("https://www.example.com/foo/?bar=baz&inga=42&quux"))
        XCTAssertTrue(regex.isMatch("http://userid:password@example.com:8080"))
        XCTAssertTrue(regex.isMatch("http://foo.com/blah_(wikipedia)#cite-1"))
        XCTAssertTrue(regex.isMatch("google.com"))
        XCTAssertTrue(regex.isMatch("www.google.com"))
        XCTAssertFalse(regex.isMatch("http://../"))
        XCTAssertFalse(regex.isMatch("http://224.1.1.1"))
        XCTAssertFalse(regex.isMatch("http://142.42.1.1:8080/"))
        XCTAssertFalse(regex.isMatch("ftp://foo.bar/baz"))
        XCTAssertTrue(regex.isMatch("http://1337.net"))
        XCTAssertTrue(regex.isMatch("http://foo.bar/?q=Test%20URL-encoded%20stuff"))
        XCTAssertTrue(regex.isMatch("http://code.google.com/events/#&product=browser"))
        XCTAssertFalse(regex.isMatch("http://-error-.invalid/"))
        XCTAssertFalse(regex.isMatch("http://3628126748"))
        XCTAssertFalse(regex.isMatch("http://उदाहरण.परीक्षा"))
    }

    // MARK: - IP Addresses

    // https://www.regexpal.com/?fam=104036
    func testIPv4Address() throws {
        let regex = try Regex(#"^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"#)

        XCTAssertTrue(regex.isMatch("0.0.0.0"))
        XCTAssertTrue(regex.isMatch("9.255.255.255"))
        XCTAssertTrue(regex.isMatch("11.0.0.0"))
        XCTAssertTrue(regex.isMatch("126.255.255.255"))
        XCTAssertTrue(regex.isMatch("129.0.0.0"))
        XCTAssertTrue(regex.isMatch("169.253.255.255"))
        XCTAssertTrue(regex.isMatch("169.255.0.0"))
        XCTAssertTrue(regex.isMatch("172.15.255.255"))
        XCTAssertTrue(regex.isMatch("172.32.0.0"))
        XCTAssertFalse(regex.isMatch("256.0.0.0"))
        XCTAssertTrue(regex.isMatch("191.0.1.255"))
        XCTAssertTrue(regex.isMatch("192.88.98.255"))
        XCTAssertTrue(regex.isMatch("192.88.100.0"))
        XCTAssertTrue(regex.isMatch("192.167.255.255"))
        XCTAssertTrue(regex.isMatch("192.169.0.0"))
        XCTAssertTrue(regex.isMatch("198.17.255.255"))
        XCTAssertTrue(regex.isMatch("223.255.255.255"))
    }

    // https://www.regexpal.com/?fam=104037
    func testIPv6Address() throws {
        let regex = try Regex(#"^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$"#)

        XCTAssertTrue(regex.isMatch("1200:0000:AB00:1234:0000:2552:7777:1313"))
        XCTAssertTrue(regex.isMatch("1200::AB00:1234::2552:7777:1313"))
        XCTAssertTrue(regex.isMatch("21DA:D3:0:2F3B:2AA:FF:FE28:9C5A"))
        XCTAssertFalse(regex.isMatch("1200:0000:AB00:1234:O000:2552:7777:1313"))    // invalid characters present
        XCTAssertTrue(regex.isMatch("FE80:0000:0000:0000:0202:B3FF:FE1E:8329"))
        XCTAssertFalse(regex.isMatch("[2001:db8:0:1]:80"))                          // valid, no support for port numbers
        XCTAssertFalse(regex.isMatch("http://[2001:db8:0:1]:80"))                   // valid, no support for IP address in a URL
    }

    // MARK: - Date Format

    // https://www.regexpal.com/?fam=104039
    func testValidateDateFormat() throws {
        let regex = try Regex(#"^([12]\d{3}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01]))$"#)

        XCTAssertTrue(regex.isMatch("1900-10-23"))
        XCTAssertFalse(regex.isMatch("2002-5-5"))
        XCTAssertFalse(regex.isMatch("2009-23-5"))
        XCTAssertTrue(regex.isMatch("2008-09-31"))
        XCTAssertTrue(regex.isMatch("1600-12-25"))
        XCTAssertFalse(regex.isMatch("1942-11-1"))
        XCTAssertFalse(regex.isMatch("1942-11-0"))
        XCTAssertFalse(regex.isMatch("1942-00-25"))
        XCTAssertFalse(regex.isMatch("2000-10-00"))
        XCTAssertTrue(regex.isMatch("2000-10-10"))
    }

    // https://regexr.com/?346hf
    func testValidateDateFormat2() throws {
        let regex = try Regex(#"^^(?:(?:31(\/|-|\.)(?:0?[13578]|1[02]))\1|(?:(?:29|30)(\/|-|\.)(?:0?[1,3-9]|1[0-2])\2))(?:(?:1[6-9]|[2-9]\d)?\d{2})$|^(?:29(\/|-|\.)0?2\3(?:(?:(?:1[6-9]|[2-9]\d)?(?:0[48]|[2468][048]|[13579][26])|(?:(?:16|[2468][048]|[3579][26])00))))$|^(?:0?[1-9]|1\d|2[0-8])(\/|-|\.)(?:(?:0?[1-9])|(?:1[0-2]))\4(?:(?:1[6-9]|[2-9]\d)?\d{2})$"#)

        XCTAssertTrue(regex.isMatch("01/01/2000"))
        XCTAssertTrue(regex.isMatch("31/01/2000"))
        XCTAssertFalse(regex.isMatch("32/01/2000"))
        XCTAssertTrue(regex.isMatch("01/1/2000"))
        XCTAssertTrue(regex.isMatch("01/1/01"))

        XCTAssertTrue(regex.isMatch("29/02/2000"))
        XCTAssertTrue(regex.isMatch("28/02/2001"))
        XCTAssertFalse(regex.isMatch("29/02/2001"))

        XCTAssertTrue(regex.isMatch("30/04/2000"))
        XCTAssertFalse(regex.isMatch("31/04/2000"))

        XCTAssertTrue(regex.isMatch("31/07/2000"))
        XCTAssertTrue(regex.isMatch("31/08/2000"))
        XCTAssertFalse(regex.isMatch("31/09/2000"))
        XCTAssertTrue(regex.isMatch("01/12/2000"))
        XCTAssertFalse(regex.isMatch("01/15/2000"))
    }

    // https://regexr.com/39tr1
    func testValidateDateFormat3() throws {
        let regex = try Regex(#"^(?:(?:31(\/|-|\.)(?:0?[13578]|1[02]|(?:Jan|Mar|May|Jul|Aug|Oct|Dec)))\1|(?:(?:29|30)(\/|-|\.)(?:0?[1,3-9]|1[0-2]|(?:Jan|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec))\2))(?:(?:1[6-9]|[2-9]\d)?\d{2})$|^(?:29(\/|-|\.)(?:0?2|(?:Feb))\3(?:(?:(?:1[6-9]|[2-9]\d)?(?:0[48]|[2468][048]|[13579][26])|(?:(?:16|[2468][048]|[3579][26])00))))$|^(?:0?[1-9]|1\d|2[0-8])(\/|-|\.)(?:(?:0?[1-9]|(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep))|(?:1[0-2]|(?:Oct|Nov|Dec)))\4(?:(?:1[6-9]|[2-9]\d)?\d{2})$"#)

        XCTAssertTrue(regex.isMatch("01/01/2000"))
        XCTAssertTrue(regex.isMatch("01/Jan/2000"))
        XCTAssertTrue(regex.isMatch("31/01/2000"))
        XCTAssertTrue(regex.isMatch("31/Jan/2000"))
        XCTAssertTrue(regex.isMatch("31.Jan.2000"))
        XCTAssertTrue(regex.isMatch("31-Jan-2000"))
        XCTAssertFalse(regex.isMatch("32/01/2000"))
        XCTAssertFalse(regex.isMatch("32/Jan/2000"))
        XCTAssertTrue(regex.isMatch("01/1/2000"))
        XCTAssertTrue(regex.isMatch("01/Jan/2000"))
        XCTAssertTrue(regex.isMatch("01/1/01"))
        XCTAssertTrue(regex.isMatch("01/Jan/01"))

        XCTAssertTrue(regex.isMatch("29/02/2000"))
        XCTAssertTrue(regex.isMatch("29/Feb/2000"))
        XCTAssertTrue(regex.isMatch("28/02/2001"))
        XCTAssertTrue(regex.isMatch("28/Feb/2001"))
        XCTAssertFalse(regex.isMatch("29/02/2001"))
        XCTAssertFalse(regex.isMatch("29/Feb/2001"))

        XCTAssertTrue(regex.isMatch("30/04/2000"))
        XCTAssertTrue(regex.isMatch("30/Apr/2000"))
        XCTAssertFalse(regex.isMatch("31/04/2000"))
        XCTAssertFalse(regex.isMatch("31/Apr/2000"))

        XCTAssertTrue(regex.isMatch("31/07/2000"))
        XCTAssertTrue(regex.isMatch("31/Jul/2000"))

        XCTAssertTrue(regex.isMatch("31/08/2000"))
        XCTAssertTrue(regex.isMatch("31/Aug/2000"))

        XCTAssertFalse(regex.isMatch("31/09/2000"))
        XCTAssertFalse(regex.isMatch("31/Sep/2000"))

        XCTAssertTrue(regex.isMatch("01/12/2000"))
        XCTAssertTrue(regex.isMatch("01/Dec/2000"))

        XCTAssertFalse(regex.isMatch("01/15/2000"))
    }

    // MARK: - Time Format

    // https://www.regexpal.com/?fam=104040
    func testTimeFormat() throws {
        let regex = try Regex(#"^(0?[1-9]|1[0-2]):[0-5][0-9]$"#)

        XCTAssertTrue(regex.isMatch("12:00"))
        XCTAssertFalse(regex.isMatch("13:00"))
        XCTAssertTrue(regex.isMatch("1:00"))
        XCTAssertFalse(regex.isMatch("5:5"))
        XCTAssertTrue(regex.isMatch("5:05"))
        XCTAssertFalse(regex.isMatch("55:55"))
        XCTAssertTrue(regex.isMatch("09:59"))
        XCTAssertFalse(regex.isMatch(":01"))
        XCTAssertFalse(regex.isMatch("0:59"))
        XCTAssertFalse(regex.isMatch("00:59"))
        XCTAssertTrue(regex.isMatch("01:59"))
    }

    // https://www.regexpal.com/?fam=104041
    func testTimeFormat2() throws {
        let regex = try Regex("^((1[0-2]|0?[1-9]):([0-5][0-9]) ?([AaPp][Mm]))$")

        XCTAssertTrue(regex.isMatch("12:00 pm"))
        XCTAssertFalse(regex.isMatch("13:00"))
        XCTAssertTrue(regex.isMatch("1:00 am"))
        XCTAssertFalse(regex.isMatch("5:5 am"))
        XCTAssertTrue(regex.isMatch("5:05 PM"))
        XCTAssertFalse(regex.isMatch("55:55"))
        XCTAssertFalse(regex.isMatch("09:59"))    // valid time, but meridiem is missing
        XCTAssertFalse(regex.isMatch(":01"))
        XCTAssertFalse(regex.isMatch("0:59"))
        XCTAssertFalse(regex.isMatch("00:59 PM"))
        XCTAssertTrue(regex.isMatch("01:59 AM"))
    }

    // https://www.regexpal.com/?fam=104042
    func testTimeFormat3() throws {
        let regex = try Regex(#"^(0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]$"#)

        XCTAssertTrue(regex.isMatch("12:00"))
        XCTAssertTrue(regex.isMatch("13:00"))
        XCTAssertFalse(regex.isMatch("1:00"))
        XCTAssertFalse(regex.isMatch("5:5"))
        XCTAssertFalse(regex.isMatch("5:05"))
        XCTAssertFalse(regex.isMatch("55:55"))
        XCTAssertTrue(regex.isMatch("09:59"))
        XCTAssertFalse(regex.isMatch(":01"))
        XCTAssertFalse(regex.isMatch("0:59"))
        XCTAssertTrue(regex.isMatch("00:59"))
        XCTAssertTrue(regex.isMatch("01:59"))
        XCTAssertFalse(regex.isMatch("24:00"))
        XCTAssertFalse(regex.isMatch("24:59"))
        XCTAssertTrue(regex.isMatch("23:59"))
    }

    // https://www.regexpal.com/?fam=104043
    func testTimeFormat4() throws {
        let regex = try Regex(#"^(0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]$"#)

        XCTAssertTrue(regex.isMatch("12:00"))
        XCTAssertTrue(regex.isMatch("13:00"))
        XCTAssertTrue(regex.isMatch("1:00"))
        XCTAssertFalse(regex.isMatch("5:5"))
        XCTAssertTrue(regex.isMatch("5:05"))
        XCTAssertFalse(regex.isMatch("55:55"))
        XCTAssertTrue(regex.isMatch("09:59"))
        XCTAssertFalse(regex.isMatch(":01"))
        XCTAssertTrue(regex.isMatch("0:59"))
        XCTAssertTrue(regex.isMatch("00:59"))
        XCTAssertTrue(regex.isMatch("01:59"))
        XCTAssertFalse(regex.isMatch("24:00"))
        XCTAssertFalse(regex.isMatch("24:59"))
        XCTAssertTrue(regex.isMatch("23:59"))
    }

    // https://www.regexpal.com/?fam=104044
    func testTimeFormat5() throws {
        let regex = try Regex(#"(?:[01]\d|2[0123]):(?:[012345]\d):(?:[012345]\d)"#)

        XCTAssertFalse(regex.isMatch("12:00"))
        XCTAssertTrue(regex.isMatch("13:00:00"))
        XCTAssertFalse(regex.isMatch("1:00:59"))
        XCTAssertFalse(regex.isMatch("5:5:59"))
        XCTAssertFalse(regex.isMatch("5:05:20"))
        XCTAssertTrue(regex.isMatch("09:59:23"))
        XCTAssertFalse(regex.isMatch(":01:01"))
        XCTAssertFalse(regex.isMatch("0:59:23"))
        XCTAssertFalse(regex.isMatch("00:59:61"))
        XCTAssertTrue(regex.isMatch("01:59:22"))
        XCTAssertFalse(regex.isMatch("24:00:00"))
        XCTAssertFalse(regex.isMatch("24:59:"))
        XCTAssertFalse(regex.isMatch("23:59:9"))
        XCTAssertTrue(regex.isMatch("23:59:19"))
    }
}
