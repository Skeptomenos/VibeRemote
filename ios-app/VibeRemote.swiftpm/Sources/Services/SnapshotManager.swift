import Foundation
import SwiftData

@MainActor
class SnapshotManager {
    static let shared = SnapshotManager()
    private init() {}
    
    func saveSnapshot(sessionId: UUID, content: String, context: ModelContext) {
        guard let data = content.data(using: .utf8) else { return }
        
        let descriptor = FetchDescriptor<SessionSnapshot>(
            predicate: #Predicate { $0.sessionId == sessionId }
        )
        
        do {
            let existing = try context.fetch(descriptor)
            if let snapshot = existing.first {
                snapshot.content = data
                snapshot.timestamp = Date()
            } else {
                let snapshot = SessionSnapshot(sessionId: sessionId, content: data)
                context.insert(snapshot)
            }
            try context.save()
        } catch {
            print("Failed to save snapshot: \(error)")
        }
    }
    
    func loadSnapshot(sessionId: UUID, context: ModelContext) -> String? {
        let descriptor = FetchDescriptor<SessionSnapshot>(
            predicate: #Predicate { $0.sessionId == sessionId }
        )
        
        do {
            let snapshots = try context.fetch(descriptor)
            return snapshots.first?.textContent
        } catch {
            print("Failed to load snapshot: \(error)")
            return nil
        }
    }
    
    func deleteSnapshot(sessionId: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<SessionSnapshot>(
            predicate: #Predicate { $0.sessionId == sessionId }
        )
        
        do {
            let snapshots = try context.fetch(descriptor)
            for snapshot in snapshots {
                context.delete(snapshot)
            }
            try context.save()
        } catch {
            print("Failed to delete snapshot: \(error)")
        }
    }
}
