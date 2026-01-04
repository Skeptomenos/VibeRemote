import XCTest
@testable import VibeRemote

final class AsyncOperationStateTests: XCTestCase {
    
    // MARK: - isInProgress
    
    func testIsInProgress_whenIdle_returnsFalse() {
        let state = AsyncOperationState.idle
        XCTAssertFalse(state.isInProgress)
    }
    
    func testIsInProgress_whenInProgress_returnsTrue() {
        let state = AsyncOperationState.inProgress
        XCTAssertTrue(state.isInProgress)
    }
    
    func testIsInProgress_whenSuccess_returnsFalse() {
        let state = AsyncOperationState.success
        XCTAssertFalse(state.isInProgress)
    }
    
    func testIsInProgress_whenFailed_returnsFalse() {
        let state = AsyncOperationState.failed("error")
        XCTAssertFalse(state.isInProgress)
    }
    
    // MARK: - isSuccess
    
    func testIsSuccess_whenIdle_returnsFalse() {
        let state = AsyncOperationState.idle
        XCTAssertFalse(state.isSuccess)
    }
    
    func testIsSuccess_whenInProgress_returnsFalse() {
        let state = AsyncOperationState.inProgress
        XCTAssertFalse(state.isSuccess)
    }
    
    func testIsSuccess_whenSuccess_returnsTrue() {
        let state = AsyncOperationState.success
        XCTAssertTrue(state.isSuccess)
    }
    
    func testIsSuccess_whenFailed_returnsFalse() {
        let state = AsyncOperationState.failed("error")
        XCTAssertFalse(state.isSuccess)
    }
    
    // MARK: - errorMessage
    
    func testErrorMessage_whenIdle_returnsNil() {
        let state = AsyncOperationState.idle
        XCTAssertNil(state.errorMessage)
    }
    
    func testErrorMessage_whenInProgress_returnsNil() {
        let state = AsyncOperationState.inProgress
        XCTAssertNil(state.errorMessage)
    }
    
    func testErrorMessage_whenSuccess_returnsNil() {
        let state = AsyncOperationState.success
        XCTAssertNil(state.errorMessage)
    }
    
    func testErrorMessage_whenFailed_returnsMessage() {
        let state = AsyncOperationState.failed("Connection timeout")
        XCTAssertEqual(state.errorMessage, "Connection timeout")
    }
    
    func testErrorMessage_whenFailedWithEmptyString_returnsEmptyString() {
        let state = AsyncOperationState.failed("")
        XCTAssertEqual(state.errorMessage, "")
    }
    
    // MARK: - Equatable
    
    func testEquatable_sameStates_areEqual() {
        XCTAssertEqual(AsyncOperationState.idle, AsyncOperationState.idle)
        XCTAssertEqual(AsyncOperationState.inProgress, AsyncOperationState.inProgress)
        XCTAssertEqual(AsyncOperationState.success, AsyncOperationState.success)
        XCTAssertEqual(AsyncOperationState.failed("error"), AsyncOperationState.failed("error"))
    }
    
    func testEquatable_differentStates_areNotEqual() {
        XCTAssertNotEqual(AsyncOperationState.idle, AsyncOperationState.inProgress)
        XCTAssertNotEqual(AsyncOperationState.success, AsyncOperationState.failed("error"))
    }
    
    func testEquatable_failedWithDifferentMessages_areNotEqual() {
        XCTAssertNotEqual(AsyncOperationState.failed("error1"), AsyncOperationState.failed("error2"))
    }
}
