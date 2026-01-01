import SwiftData
import Foundation

@Model
final class SessionSnapshot {
    var id: UUID
    var sessionId: UUID
    var content: Data
    var timestamp: Date
    
    init(sessionId: UUID, content: Data) {
        self.id = UUID()
        self.sessionId = sessionId
        self.content = content
        self.timestamp = Date()
    }
    
    var textContent: String? {
        String(data: content, encoding: .utf8)
    }
}
