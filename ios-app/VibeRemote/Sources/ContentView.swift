import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AgentSession.lastActive, order: .reverse) private var sessions: [AgentSession]
    @State private var selectedSession: AgentSession?
    @State private var showingNewSessionSheet = false
    @State private var showingSettings = false
    @State private var sessionToEdit: AgentSession?
    
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
                TerminalContainerView(session: session, onSessionKilled: {
                    selectedSession = nil
                })
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
