import SwiftUI
import SwiftData

struct MainNavigationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AgentSession.lastActive, order: .reverse) private var sessions: [AgentSession]
    @Query private var configs: [ServerConfig]
    
    @Query private var userPreferences: [UserPreferences]
    
    @State private var isSidebarOpen = false
    @State private var selectedSession: AgentSession?
    @State private var showingNewSessionSheet = false
    @State private var showingSettings = false
    @State private var sessionToEdit: AgentSession?
    @State private var emptyStateInputText = ""
    @State private var pendingMessage: String?
    @State private var showingOnboarding = false
    
    private var config: ServerConfig? {
        configs.first
    }
    
    var body: some View {
        SidebarDrawerView(isOpen: $isSidebarOpen) {
            sidebarContent
        } content: {
            mainContent
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
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingWizardView(isPresented: $showingOnboarding)
        }
        .onAppear {
            checkForOnboarding()
            selectInitialSession()
        }
    }
    
    // MARK: - Sidebar Content
    
    private var sidebarContent: some View {
        SidebarContentView(
            sessions: sessions,
            selectedSession: $selectedSession,
            onNewSession: { showingNewSessionSheet = true },
            onSettings: { showingSettings = true },
            onEditSession: { session in sessionToEdit = session },
            onSelectSession: { session in
                selectedSession = session
                pendingMessage = nil
                withAnimation(.easeOut(duration: 0.2)) {
                    isSidebarOpen = false
                }
            }
        )
    }
    
    // MARK: - Main Content
    
    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            Color(hex: 0x0A0A0A)
                .ignoresSafeArea()
            
            if let session = selectedSession {
                sessionDetailView(for: session)
            } else {
                emptyStateView
            }
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
                    apiKey: apiKey,
                    initialMessage: pendingMessage,
                    onMenuTap: { toggleSidebar() }
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
    
    private var emptyStateView: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { toggleSidebar() }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color(hex: 0x808080))
                        .frame(width: 44, height: 44)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            Spacer()
            
            Text("What can I help with?")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(hex: 0xEEEEEE))
            
            Spacer()
            
            EmptyStateInputBar(
                text: $emptyStateInputText,
                onSend: { createTemporarySessionAndSend() }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func checkForOnboarding() {
        if userPreferences.first == nil {
            // First launch, no preferences exist yet
            showingOnboarding = true
        } else if let prefs = userPreferences.first, !prefs.hasCompletedOnboarding {
            // Preferences exist but onboarding not completed
            showingOnboarding = true
        }
    }
    
    private func toggleSidebar() {
        withAnimation(.easeOut(duration: 0.2)) {
            isSidebarOpen.toggle()
        }
    }
    
    private func selectInitialSession() {
        guard selectedSession == nil else { return }
        
        let preferences: UserPreferences
        if let existing = userPreferences.first {
            preferences = existing
        } else {
            let newPrefs = UserPreferences()
            modelContext.insert(newPrefs)
            preferences = newPrefs
        }
        
        switch preferences.launchBehavior {
        case .masterFavorite:
            if let masterFavorite = sessions.first(where: { $0.isMasterFavorite }) {
                selectedSession = masterFavorite
            } else if let lastSession = sessions.first {
                selectedSession = lastSession
            }
            
        case .lastSession:
            if let lastSession = sessions.first {
                selectedSession = lastSession
            }
            
        case .newTemporary:
            // Do nothing, show empty state
            selectedSession = nil
        }
    }
    
    private func createTemporarySessionAndSend() {
        let text = emptyStateInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        let projectPath = resolveDefaultProjectPath()
        
        let newSession = AgentSession(
            name: String(text.prefix(30)),
            projectPath: projectPath,
            agentType: .opencode,
            connectionMode: .api,
            sessionType: .temporary
        )
        
        modelContext.insert(newSession)
        pendingMessage = text
        emptyStateInputText = ""
        selectedSession = newSession
    }
    
    private func resolveDefaultProjectPath() -> String {
        if let defaultPath = userPreferences.first?.defaultProjectPath, !defaultPath.isEmpty {
            return defaultPath
        }
        if let lastSession = sessions.first, !lastSession.projectPath.isEmpty && lastSession.projectPath != "~/" {
            return lastSession.projectPath
        }
        return "~/VibeRemote"
    }
}

struct EmptyStateInputBar: View {
    @Binding var text: String
    let onSend: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message...", text: $text, axis: .vertical)
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: 0xEEEEEE))
                .lineLimit(1...5)
                .focused($isFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            
            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color(hex: 0x606060)
                            : Color(hex: 0xFAB283)
                    )
                    .clipShape(Circle())
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.trailing, 8)
            .padding(.bottom, 8)
        }
        .background(Color(hex: 0x1E1E1E))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    isFocused ? Color(hex: 0xFAB283) : Color(hex: 0x3C3C3C),
                    lineWidth: 1
                )
        )
    }
}


