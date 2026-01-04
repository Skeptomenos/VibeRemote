import XCTest
@testable import VibeRemote

final class URLValidatorTests: XCTestCase {
    
    // MARK: - isValid
    
    func testIsValid_emptyString_returnsTrue() {
        XCTAssertTrue(URLValidator.isValid(""))
    }
    
    func testIsValid_validHttpsURL_returnsTrue() {
        XCTAssertTrue(URLValidator.isValid("https://example.com"))
        XCTAssertTrue(URLValidator.isValid("https://192.168.1.1"))
        XCTAssertTrue(URLValidator.isValid("https://example.com:8080"))
        XCTAssertTrue(URLValidator.isValid("https://example.com/path"))
        XCTAssertTrue(URLValidator.isValid("https://sub.example.com"))
    }
    
    func testIsValid_validHttpURL_returnsTrue() {
        XCTAssertTrue(URLValidator.isValid("http://example.com"))
        XCTAssertTrue(URLValidator.isValid("http://localhost:3000"))
        XCTAssertTrue(URLValidator.isValid("http://192.168.1.1:8080"))
    }
    
    func testIsValid_missingScheme_returnsFalse() {
        XCTAssertFalse(URLValidator.isValid("example.com"))
        XCTAssertFalse(URLValidator.isValid("www.example.com"))
        XCTAssertFalse(URLValidator.isValid("192.168.1.1"))
    }
    
    func testIsValid_invalidScheme_returnsFalse() {
        XCTAssertFalse(URLValidator.isValid("ftp://example.com"))
        XCTAssertFalse(URLValidator.isValid("ssh://example.com"))
        XCTAssertFalse(URLValidator.isValid("file:///path/to/file"))
    }
    
    func testIsValid_schemeOnly_returnsFalse() {
        XCTAssertFalse(URLValidator.isValid("https://"))
        XCTAssertFalse(URLValidator.isValid("http://"))
    }
    
    func testIsValid_invalidURLFormat_returnsFalse() {
        XCTAssertFalse(URLValidator.isValid("not a url"))
        XCTAssertFalse(URLValidator.isValid("://missing-scheme"))
    }
    
    // MARK: - validationMessage
    
    func testValidationMessage_emptyString_returnsNil() {
        XCTAssertNil(URLValidator.validationMessage(for: ""))
    }
    
    func testValidationMessage_validURL_returnsNil() {
        XCTAssertNil(URLValidator.validationMessage(for: "https://example.com"))
        XCTAssertNil(URLValidator.validationMessage(for: "http://localhost:3000"))
    }
    
    func testValidationMessage_missingScheme_returnsSchemeError() {
        let message = URLValidator.validationMessage(for: "example.com")
        XCTAssertEqual(message, "URL must start with http:// or https://")
    }
    
    func testValidationMessage_invalidScheme_returnsSchemeError() {
        let message = URLValidator.validationMessage(for: "ftp://example.com")
        XCTAssertEqual(message, "URL must use http:// or https://")
    }
    
    func testValidationMessage_schemeOnlyNoHost_returnsHostError() {
        let message = URLValidator.validationMessage(for: "https://")
        XCTAssertEqual(message, "URL must include a host")
    }
    
    func testValidationMessage_invalidSchemeFormat_returnsSchemeError() {
        let message = URLValidator.validationMessage(for: "://missing-scheme")
        XCTAssertEqual(message, "URL must use http:// or https://")
    }
    
    // MARK: - Edge Cases
    
    func testIsValid_urlWithQueryParams_returnsTrue() {
        XCTAssertTrue(URLValidator.isValid("https://example.com?key=value"))
        XCTAssertTrue(URLValidator.isValid("https://example.com/path?key=value&other=123"))
    }
    
    func testIsValid_urlWithFragment_returnsTrue() {
        XCTAssertTrue(URLValidator.isValid("https://example.com#section"))
        XCTAssertTrue(URLValidator.isValid("https://example.com/path#section"))
    }
    
    func testIsValid_urlWithAuth_returnsTrue() {
        XCTAssertTrue(URLValidator.isValid("https://user:pass@example.com"))
    }
    
    func testIsValid_mixedCaseScheme_returnsTrue() {
        XCTAssertTrue(URLValidator.isValid("HTTPS://example.com"))
        XCTAssertTrue(URLValidator.isValid("HTTP://example.com"))
        XCTAssertTrue(URLValidator.isValid("HtTpS://example.com"))
    }
}
