import SwiftUI
import SwiftData

struct SessionSidebarView: View {
    let sessions: [AgentSession]
    @Binding var selectedSession: AgentSession?
    let onNewSession: () -> Void
    let onSettings: () -> Void
    
    var body: some View {
        List(selection: $selectedSession) {
            Section("Active Sessions") {
                ForEach(sessions) { session in
                    SessionRowView(session: session)
                        .tag(session)
                }
                .onDelete(perform: deleteSessions)
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
    
    private func deleteSessions(at offsets: IndexSet) {
    }
}

struct SessionRowView: View {
    let session: AgentSession
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.agentType.iconName)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(session.projectPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }
}
