import XCTest
@testable import VibeRemote

final class GatewayErrorTests: XCTestCase {
    
    func testErrorDescription_invalidResponse() {
        let error = GatewayError.invalidResponse
        XCTAssertEqual(error.errorDescription, "Invalid response from gateway")
    }
    
    func testErrorDescription_unauthorized() {
        let error = GatewayError.unauthorized
        XCTAssertEqual(error.errorDescription, "Invalid API key. Check your settings.")
    }
    
    func testErrorDescription_serverError() {
        let error = GatewayError.serverError(500)
        XCTAssertEqual(error.errorDescription, "Server error (HTTP 500)")
        
        let error404 = GatewayError.serverError(404)
        XCTAssertEqual(error404.errorDescription, "Server error (HTTP 404)")
    }
    
    func testErrorDescription_projectNotFound() {
        let error = GatewayError.projectNotFound("my-project")
        XCTAssertEqual(error.errorDescription, "Project 'my-project' not found")
    }
    
    func testErrorDescription_startFailed() {
        let error = GatewayError.startFailed("Port already in use")
        XCTAssertEqual(error.errorDescription, "Failed to start OpenCode: Port already in use")
    }
    
    func testErrorDescription_stopFailed() {
        let error = GatewayError.stopFailed("Process not running")
        XCTAssertEqual(error.errorDescription, "Failed to stop OpenCode: Process not running")
    }
    
    func testErrorDescription_connectionFailed() {
        let error = GatewayError.connectionFailed
        XCTAssertEqual(error.errorDescription, "Cannot connect to gateway")
    }
}
