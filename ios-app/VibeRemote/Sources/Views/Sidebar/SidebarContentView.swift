import SwiftUI

struct SidebarContentView: View {
    @Environment(\.modelContext) private var modelContext
    let sessions: [AgentSession]
    @Binding var selectedSession: AgentSession?
    let onNewSession: () -> Void
    let onSettings: () -> Void
    let onEditSession: (AgentSession) -> Void
    let onSelectSession: (AgentSession) -> Void
    
    @State private var searchText = ""
    
    private var filteredSessions: [AgentSession] {
        if searchText.isEmpty {
            return sessions
        }
        return sessions.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var pinnedSessions: [AgentSession] {
        filteredSessions.filter { $0.isFavorite || $0.isMasterFavorite }
    }
    
    private var unpinnedSessions: [AgentSession] {
        filteredSessions.filter { !$0.isFavorite && !$0.isMasterFavorite }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            searchBar
            sessionList
            Spacer(minLength: 0)
            settingsButton
        }
        .background(Color(hex: 0x141414))
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Text("VibeRemote")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(hex: 0xEEEEEE))
            
            Spacer()
            
            Button(action: onNewSession) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(hex: 0x808080))
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    // MARK: - Search
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: 0x606060))
            
            TextField("Search sessions...", text: $searchText)
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: 0xEEEEEE))
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(hex: 0x1E1E1E))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    // MARK: - Session List
    
    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                if !pinnedSessions.isEmpty {
                    Section {
                        ForEach(pinnedSessions) { session in
                            SidebarSessionRowView(
                                session: session,
                                isSelected: selectedSession?.id == session.id,
                                onTap: { onSelectSession(session) },
                                onEdit: { onEditSession(session) },
                                onToggleFavorite: { toggleFavorite(session) },
                                onDelete: { deleteSession(session) }
                            )
                        }
                    } header: {
                        sectionHeader("PINNED")
                    }
                }
                
                ForEach(groupedByDate, id: \.title) { group in
                    Section {
                        ForEach(group.sessions) { session in
                            SidebarSessionRowView(
                                session: session,
                                isSelected: selectedSession?.id == session.id,
                                onTap: { onSelectSession(session) },
                                onEdit: { onEditSession(session) },
                                onToggleFavorite: { toggleFavorite(session) },
                                onDelete: { deleteSession(session) }
                            )
                        }
                    } header: {
                        sectionHeader(group.title)
                    }
                }
            }
            .padding(.bottom, 16)
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(hex: 0x606060))
                .tracking(0.5)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(hex: 0x141414))
    }
    
    // MARK: - Date Grouping
    
    private var groupedByDate: [SessionGroup] {
        let calendar = Calendar.current
        let now = Date()
        
        var today: [AgentSession] = []
        var yesterday: [AgentSession] = []
        var previousWeek: [AgentSession] = []
        var older: [AgentSession] = []
        
        for session in unpinnedSessions {
            let date = session.lastActive
            
            if calendar.isDateInToday(date) {
                today.append(session)
            } else if calendar.isDateInYesterday(date) {
                yesterday.append(session)
            } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
                      date > weekAgo {
                previousWeek.append(session)
            } else {
                older.append(session)
            }
        }
        
        var groups: [SessionGroup] = []
        if !today.isEmpty { groups.append(SessionGroup(title: "TODAY", sessions: today)) }
        if !yesterday.isEmpty { groups.append(SessionGroup(title: "YESTERDAY", sessions: yesterday)) }
        if !previousWeek.isEmpty { groups.append(SessionGroup(title: "PREVIOUS 7 DAYS", sessions: previousWeek)) }
        if !older.isEmpty { groups.append(SessionGroup(title: "OLDER", sessions: older)) }
        
        return groups
    }
    
    // MARK: - Settings Button
    
    private var settingsButton: some View {
        HStack {
            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundStyle(Color(hex: 0x808080))
                    .frame(width: 44, height: 44)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
    
    // MARK: - Actions
    
    private func toggleFavorite(_ session: AgentSession) {
        session.isFavorite.toggle()
    }
    
    private func deleteSession(_ session: AgentSession) {
        if selectedSession?.id == session.id {
            selectedSession = nil
        }
        modelContext.delete(session)
    }
}

// MARK: - Session Group

private struct SessionGroup {
    let title: String
    let sessions: [AgentSession]
}


