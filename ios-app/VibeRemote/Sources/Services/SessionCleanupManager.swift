import SwiftUI
import SwiftData
import UIKit

/// Manages cleanup of temporary sessions
/// Temporary sessions are deleted when:
/// 1. The AI has completed its response (no active streaming)
/// 2. The app goes to background or terminates
@MainActor
final class SessionCleanupManager: ObservableObject {
    static let shared = SessionCleanupManager()
    
    private var modelContext: ModelContext?
    private var activeSessions: Set<UUID> = []
    private var cleanupTask: Task<Void, Never>?
    
    /// Debounce delay to allow in-flight state changes to settle
    private let cleanupDebounceDelay: UInt64 = 500_000_000 // 0.5 seconds in nanoseconds
    
    private init() {
        setupNotifications()
    }
    
    // MARK: - Configuration
    
    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        cleanupTemporarySessions()
    }
    
    // MARK: - Session Tracking
    
    /// Mark a session as having active streaming (AI is responding)
    func markSessionActive(_ sessionID: UUID) {
        activeSessions.insert(sessionID)
    }
    
    /// Mark a session as idle (AI has completed response)
    func markSessionIdle(_ sessionID: UUID) {
        activeSessions.remove(sessionID)
    }
    
    /// Check if a session has active streaming
    func isSessionActive(_ sessionID: UUID) -> Bool {
        activeSessions.contains(sessionID)
    }
    
    // MARK: - Cleanup
    
    /// Clean up all temporary sessions that are not actively streaming
    func cleanupTemporarySessions() {
        guard let modelContext = modelContext else { return }
        
        let descriptor = FetchDescriptor<AgentSession>(
            predicate: #Predicate { $0.sessionTypeRaw == "temporary" }
        )
        
        do {
            let temporarySessions = try modelContext.fetch(descriptor)
            
            for session in temporarySessions {
                // Only delete if not actively streaming
                if !activeSessions.contains(session.id) {
                    modelContext.delete(session)
                }
            }
            
            try modelContext.save()
        } catch {
            print("SessionCleanupManager: Failed to cleanup temporary sessions: \(error)")
        }
    }
    
    /// Clean up a specific temporary session if it's idle
    func cleanupSession(_ session: AgentSession) {
        guard session.isTemporary,
              !activeSessions.contains(session.id),
              let modelContext = modelContext else { return }
        
        modelContext.delete(session)
        
        do {
            try modelContext.save()
        } catch {
            print("SessionCleanupManager: Failed to delete session: \(error)")
        }
    }
    
    // MARK: - App Lifecycle
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.scheduleCleanup()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.cleanupTemporarySessions()
            }
        }
    }
    
    private func scheduleCleanup() {
        cleanupTask?.cancel()
        cleanupTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: cleanupDebounceDelay)
            guard !Task.isCancelled else { return }
            cleanupTemporarySessions()
        }
    }
}
