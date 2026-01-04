import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AgentSession.lastActive, order: .reverse) private var sessions: [AgentSession]
    @Query private var configs: [ServerConfig]
    @State private var selectedSession: AgentSession?
    @State private var showingNewSessionSheet = false
    @State private var showingSettings = false
    @State private var sessionToEdit: AgentSession?
    
    private var config: ServerConfig? {
        configs.first
    }
    
    var body: some View {
        NavigationSplitView {
            SessionSidebarView(
                sessions: sessions,
                selectedSession: $selectedSession,
                onNewSession: { showingNewSessionSheet = true },
                onSettings: { showingSettings = true },
                onEditSession: { session in
                    sessionToEdit = session
                }
            )
        } detail: {
            if let session = selectedSession {
                sessionDetailView(for: session)
            } else {
                EmptyStateView()
            }
        }
        .sheet(isPresented: $showingNewSessionSheet) {
            NewSessionWizard { newSession in
                modelContext.insert(newSession)
                selectedSession = newSession
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(item: $sessionToEdit) { session in
            EditSessionView(session: session, onDelete: {
                if selectedSession?.id == session.id {
                    selectedSession = nil
                }
                sessionToEdit = nil
            })
        }
    }
    
    @ViewBuilder
    private func sessionDetailView(for session: AgentSession) -> some View {
        switch session.connectionMode {
        case .api:
            if let gatewayURL = config?.gatewayURL,
               let apiKey = KeychainManager.shared.getAPIKey() {
                ChatContainerView(
                    session: session,
                    gatewayURL: gatewayURL,
                    apiKey: apiKey
                )
            } else {
                APINotConfiguredView(onOpenSettings: { showingSettings = true })
            }
        case .ssh:
            TerminalContainerView(session: session, onSessionKilled: {
                selectedSession = nil
            })
        }
    }
}

struct APINotConfiguredView: View {
    let onOpenSettings: () -> Void
    
    var body: some View {
        ContentUnavailableView {
            Label("API Not Configured", systemImage: "gear.badge.xmark")
        } description: {
            Text("Configure your Gateway URL and API Key in Settings to use the native chat interface.")
        } actions: {
            Button("Open Settings", action: onOpenSettings)
                .buttonStyle(.borderedProminent)
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        ContentUnavailableView(
            "No Session Selected",
            systemImage: "terminal",
            description: Text("Select a session from the sidebar or create a new one.")
        )
    }
}
