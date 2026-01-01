import SwiftUI
import SwiftData

struct UpdateOpenCodeView: View {
    @Query private var sessions: [AgentSession]
    @Query private var configs: [ServerConfig]
    @Environment(OpenCodeVersionManager.self) private var versionManager
    @StateObject private var connectionManager = SSHConnectionManager()
    
    @State private var currentVersion: String = "..."
    @State private var latestVersion: String = "..."
    @State private var isLoading = false
    @State private var isUpdating = false
    @State private var updateProgress: UpdateProgress = .idle
    @State private var activeSessions: [String] = []
    @State private var stoppedSessions: [(name: String, projectPath: String, sessionId: String?)] = []
    @State private var errorMessage: String?
    @State private var updateOutput: String = ""
    @State private var newVersion: String?
    
    private var serverConfig: ServerConfig? { configs.first }
    
    private var openCodeSessions: [AgentSession] {
        sessions.filter { $0.agentType == .opencode }
    }
    
    private var isUpdateAvailable: Bool {
        guard currentVersion != "..." && currentVersion != "unknown",
              latestVersion != "..." && latestVersion != "unknown" else {
            return false
        }
        return currentVersion != latestVersion
    }
    
    enum UpdateProgress: Equatable {
        case idle
        case connecting
        case checkingVersion
        case stoppingSessions(completed: Int, total: Int)
        case upgrading
        case restartingSessions(completed: Int, total: Int)
        case completed
        case failed
    }
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Installed")
                    Spacer()
                    if isLoading {
                        ProgressView()
                    } else {
                        Text(currentVersion)
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack {
                    Text("Latest")
                    Spacer()
                    if isLoading {
                        ProgressView()
                    } else {
                        Text(latestVersion)
                            .foregroundStyle(isUpdateAvailable ? .green : .secondary)
                    }
                }
                
                if !isLoading && !isUpdateAvailable && currentVersion != "..." && latestVersion != "..." {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("You're up to date")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Version")
            }
            
            Section {
                if activeSessions.isEmpty {
                    Text("No active OpenCode sessions")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(activeSessions, id: \.self) { sessionName in
                        HStack {
                            Image(systemName: "terminal")
                                .foregroundStyle(.green)
                            Text(sessionName)
                            Spacer()
                            if case .stoppingSessions = updateProgress {
                                if stoppedSessions.contains(where: { $0.name == sessionName }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else {
                                    ProgressView()
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Active Sessions (\(activeSessions.count))")
            } footer: {
                if !activeSessions.isEmpty {
                    Text("These sessions will be stopped during update and restarted automatically.")
                }
            }
            
            if isUpdating {
                Section {
                    progressView
                } header: {
                    Text("Progress")
                }
            }
            
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                } header: {
                    Text("Error")
                }
            }
            
            Section {
                Button(action: performUpdate) {
                    HStack {
                        Spacer()
                        if isUpdating {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Updating...")
                        } else if isUpdateAvailable {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Update to \(latestVersion)")
                        } else {
                            Image(systemName: "arrow.clockwise")
                            Text("Check & Reinstall")
                        }
                        Spacer()
                    }
                }
                .disabled(isUpdating || serverConfig == nil || isLoading)
            } footer: {
                if !isUpdateAvailable && !isLoading && currentVersion != "..." {
                    Text("No update available. You can reinstall the current version if needed.")
                }
            }
        }
        .navigationTitle("Update OpenCode")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadInitialData()
        }
        .refreshable {
            await loadInitialData()
        }
        .onDisappear {
            Task {
                await connectionManager.disconnect()
            }
        }
    }
    
    @ViewBuilder
    private var progressView: some View {
        VStack(alignment: .leading, spacing: 12) {
            progressRow(
                title: "Connect to server",
                isComplete: updateProgress != .connecting && updateProgress != .idle,
                isActive: updateProgress == .connecting
            )
            
            progressRow(
                title: "Stop active sessions",
                isComplete: {
                    switch updateProgress {
                    case .upgrading, .restartingSessions, .completed: return true
                    default: return false
                    }
                }(),
                isActive: {
                    if case .stoppingSessions = updateProgress { return true }
                    return false
                }()
            )
            
            progressRow(
                title: "Download & install update",
                isComplete: {
                    switch updateProgress {
                    case .restartingSessions, .completed: return true
                    default: return false
                    }
                }(),
                isActive: updateProgress == .upgrading
            )
            
            progressRow(
                title: "Restart sessions",
                isComplete: updateProgress == .completed,
                isActive: {
                    if case .restartingSessions = updateProgress { return true }
                    return false
                }()
            )
        }
        .padding(.vertical, 8)
    }
    
    private func progressRow(title: String, isComplete: Bool, isActive: Bool) -> some View {
        HStack {
            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if isActive {
                ProgressView()
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
            }
            
            Text(title)
                .foregroundStyle(isComplete ? .primary : (isActive ? .primary : .secondary))
        }
    }
    
    private func loadInitialData() async {
        guard let config = serverConfig else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await connectionManager.connect(config: config, session: openCodeSessions.first ?? AgentSession(name: "temp", projectPath: "~", agentType: .shell))
            
            async let versionTask = connectionManager.getOpenCodeVersion()
            async let latestTask = connectionManager.getLatestOpenCodeVersion()
            async let sessionsTask = connectionManager.listActiveVibeTmuxSessions()
            
            let (version, latest, sessions) = try await (versionTask, latestTask, sessionsTask)
            
            await MainActor.run {
                self.currentVersion = version
                self.latestVersion = latest
                self.activeSessions = sessions
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func performUpdate() {
        guard let config = serverConfig else { return }
        
        isUpdating = true
        errorMessage = nil
        stoppedSessions = []
        
        Task {
            do {
                await MainActor.run { updateProgress = .connecting }
                
                if connectionManager.connectionState != .connected {
                    try await connectionManager.connect(config: config, session: openCodeSessions.first ?? AgentSession(name: "temp", projectPath: "~", agentType: .shell))
                }
                
                let sessionsToRestart = buildSessionRestartList()
                
                await MainActor.run {
                    updateProgress = .stoppingSessions(completed: 0, total: sessionsToRestart.count)
                }
                
                try await stopAllSessions(sessionsToRestart)
                
                await MainActor.run { updateProgress = .upgrading }
                let output = try await connectionManager.upgradeOpenCode()
                await MainActor.run { updateOutput = output }
                
                await MainActor.run {
                    updateProgress = .restartingSessions(completed: 0, total: sessionsToRestart.count)
                }
                
                try await restartAllSessions()
                
                let newVer = try await connectionManager.getOpenCodeVersion()
                
                await MainActor.run {
                    self.newVersion = newVer
                    self.currentVersion = newVer
                    self.latestVersion = newVer
                    self.updateProgress = .completed
                    self.isUpdating = false
                    versionManager.updateVersions(installed: newVer, latest: newVer)
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.updateProgress = .failed
                    self.isUpdating = false
                }
            }
        }
    }
    
    private func buildSessionRestartList() -> [(name: String, projectPath: String, sessionId: String?)] {
        activeSessions.compactMap { tmuxName in
            if let session = openCodeSessions.first(where: { $0.tmuxSessionName == tmuxName }) {
                return (name: tmuxName, projectPath: session.projectPath, sessionId: session.opencodeSessionId)
            }
            return nil
        }
    }
    
    private func stopAllSessions(_ sessions: [(name: String, projectPath: String, sessionId: String?)]) async throws {
        var failedToStop: [String] = []
        
        for (index, session) in sessions.enumerated() {
            let stopped = try await connectionManager.sendCtrlCToTmuxSession(name: session.name)
            
            if stopped {
                await MainActor.run {
                    stoppedSessions.append(session)
                }
            } else {
                failedToStop.append(session.name)
            }
            
            await MainActor.run {
                updateProgress = .stoppingSessions(completed: index + 1, total: sessions.count)
            }
        }
        
        if !failedToStop.isEmpty {
            throw ConnectionError.upgradeFailed("Failed to stop sessions: \(failedToStop.joined(separator: ", "))")
        }
    }
    
    private func restartAllSessions() async throws {
        for (index, session) in stoppedSessions.enumerated() {
            try await connectionManager.restartOpenCodeInTmuxSession(
                name: session.name,
                projectPath: session.projectPath,
                opencodeSessionId: session.sessionId
            )
            
            await MainActor.run {
                updateProgress = .restartingSessions(completed: index + 1, total: stoppedSessions.count)
            }
        }
    }
}
