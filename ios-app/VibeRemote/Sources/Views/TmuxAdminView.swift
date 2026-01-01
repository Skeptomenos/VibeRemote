import SwiftUI
import SwiftData

struct TmuxSessionInfo: Identifiable {
    let id: String
    let name: String
    let isOrphaned: Bool
    let linkedConnectionName: String?
}

struct TmuxAdminView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var configs: [ServerConfig]
    @Query private var sessions: [AgentSession]
    
    @StateObject private var connectionManager = SSHConnectionManager()
    
    @State private var tmuxSessions: [TmuxSessionInfo] = []
    @State private var isLoading = true
    @State private var error: String?
    
    private var serverConfig: ServerConfig? { configs.first }
    
    private var knownTmuxNames: Set<String> {
        Set(sessions.map { $0.tmuxSessionName })
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading tmux sessions...")
                } else if let error = error {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if tmuxSessions.isEmpty {
                    ContentUnavailableView("No Sessions", systemImage: "terminal", description: Text("No tmux sessions running on server"))
                } else {
                    List {
                        let orphaned = tmuxSessions.filter { $0.isOrphaned }
                        let active = tmuxSessions.filter { !$0.isOrphaned }
                        
                        if !orphaned.isEmpty {
                            Section {
                                ForEach(orphaned) { session in
                                    TmuxSessionRow(session: session, onKill: { killSession(session) })
                                }
                            } header: {
                                HStack {
                                    Text("Orphaned Sessions")
                                    Spacer()
                                    Button("Kill All") {
                                        killAllOrphaned()
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                }
                            } footer: {
                                Text("These sessions are not linked to any app connection and can be safely removed.")
                            }
                        }
                        
                        if !active.isEmpty {
                            Section("Active Sessions") {
                                ForEach(active) { session in
                                    TmuxSessionRow(session: session, onKill: { killSession(session) })
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tmux Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await loadSessions() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await loadSessions()
            }
        }
    }
    
    private func loadSessions() async {
        guard let config = serverConfig else {
            error = "No server configured"
            isLoading = false
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            try await connectionManager.connect(config: config, session: AgentSession(name: "admin", projectPath: "~/"))
            let names = try await connectionManager.listTmuxSessions()
            
            tmuxSessions = names.map { name in
                let isOrphaned = !knownTmuxNames.contains(name)
                let linkedConnection = sessions.first { $0.tmuxSessionName == name }
                return TmuxSessionInfo(
                    id: name,
                    name: name,
                    isOrphaned: isOrphaned,
                    linkedConnectionName: linkedConnection?.name
                )
            }.sorted { ($0.isOrphaned ? 0 : 1) < ($1.isOrphaned ? 0 : 1) }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
        
        await connectionManager.disconnect()
        await MainActor.run { isLoading = false }
    }
    
    private func killSession(_ session: TmuxSessionInfo) {
        Task {
            guard let config = serverConfig else { return }
            do {
                try await connectionManager.connect(config: config, session: AgentSession(name: "admin", projectPath: "~/"))
                try await connectionManager.killTmuxSession(name: session.name)
                await connectionManager.disconnect()
                await loadSessions()
            } catch {
                print("Failed to kill session: \(error)")
            }
        }
    }
    
    private func killAllOrphaned() {
        Task {
            guard let config = serverConfig else { return }
            do {
                try await connectionManager.connect(config: config, session: AgentSession(name: "admin", projectPath: "~/"))
                for session in tmuxSessions.filter({ $0.isOrphaned }) {
                    try await connectionManager.killTmuxSession(name: session.name)
                }
                await connectionManager.disconnect()
                await loadSessions()
            } catch {
                print("Failed to kill sessions: \(error)")
            }
        }
    }
}

struct TmuxSessionRow: View {
    let session: TmuxSessionInfo
    let onKill: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .font(.system(.body, design: .monospaced))
                
                if let linked = session.linkedConnectionName {
                    Text("Linked to: \(linked)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not linked to any connection")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            
            Spacer()
            
            Button(role: .destructive) {
                onKill()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }
}
