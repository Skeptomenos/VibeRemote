import Foundation

enum AsyncOperationState: Equatable {
    case idle
    case inProgress
    case success
    case failed(String)
    
    var isInProgress: Bool {
        if case .inProgress = self { return true }
        return false
    }
    
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
    
    var errorMessage: String? {
        if case .failed(let message) = self { return message }
        return nil
    }
}
