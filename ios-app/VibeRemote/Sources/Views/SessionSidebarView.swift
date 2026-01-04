import SwiftUI
import SwiftData

struct SessionSidebarView: View {
    let sessions: [AgentSession]
    @Binding var selectedSession: AgentSession?
    let onNewSession: () -> Void
    let onSettings: () -> Void
    let onEditSession: (AgentSession) -> Void
    
    var body: some View {
        List(selection: $selectedSession) {
            Section("Active Sessions") {
                ForEach(sessions) { session in
                    SessionRowView(session: session)
                        .tag(session)
                        .contextMenu {
                            Button("Edit", systemImage: "pencil") {
                                onEditSession(session)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Edit") {
                                onEditSession(session)
                            }
                            .tint(.blue)
                        }
                }
            }
        }
        .navigationTitle("VibeRemote")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onNewSession) {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onSettings) {
                    Image(systemName: "gear")
                }
            }
        }
    }
}

struct SessionRowView: View {
    let session: AgentSession
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.connectionIcon)
                .foregroundStyle(connectionModeColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(session.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(OpenCodeTheme.text)
                    
                    Text(session.agentType.displayName)
                        .font(.caption2)
                        .foregroundStyle(OpenCodeTheme.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(OpenCodeTheme.backgroundElement)
                        .cornerRadius(4)
                }
                
                Text(session.projectPath)
                    .font(.caption)
                    .foregroundStyle(OpenCodeTheme.textMuted)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Circle()
                .fill(OpenCodeTheme.success)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }
    
    private var connectionModeColor: Color {
        switch session.connectionMode {
        case .api:
            return OpenCodeTheme.primary
        case .ssh:
            return OpenCodeTheme.textMuted
        }
    }
}
