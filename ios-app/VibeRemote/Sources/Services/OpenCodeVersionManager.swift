import Foundation
import SwiftUI

@Observable
@MainActor
class OpenCodeVersionManager {
    var installedVersion: String = "..."
    var latestVersion: String = "..."
    var isChecking = false
    var lastChecked: Date?
    
    var isUpdateAvailable: Bool {
        guard installedVersion != "..." && installedVersion != "unknown",
              latestVersion != "..." && latestVersion != "unknown" else {
            return false
        }
        return installedVersion != latestVersion
    }
    
    private var connectionManager: SSHConnectionManager?
    
    func checkVersions(config: ServerConfig) async {
        guard !isChecking else { return }
        
        isChecking = true
        defer { isChecking = false }
        
        do {
            let manager = SSHConnectionManager()
            connectionManager = manager
            
            let tempSession = AgentSession(name: "version-check", projectPath: "~", agentType: .shell)
            try await manager.connect(config: config, session: tempSession)
            
            async let installedTask = manager.getOpenCodeVersion()
            async let latestTask = manager.getLatestOpenCodeVersion()
            
            let (installed, latest) = try await (installedTask, latestTask)
            
            self.installedVersion = installed
            self.latestVersion = latest
            self.lastChecked = Date()
            
            await manager.disconnect()
            connectionManager = nil
        } catch {
            if let manager = connectionManager {
                await manager.disconnect()
            }
            connectionManager = nil
        }
    }
    
    func updateVersions(installed: String, latest: String) {
        self.installedVersion = installed
        self.latestVersion = latest
        self.lastChecked = Date()
    }
}
