import SwiftUI
import SwiftData
import os.log

struct EditSessionView: View {
    private let logger = Logger(subsystem: "com.vibeRemote.app", category: "EditSessionView")
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var configs: [ServerConfig]
    
    @Bindable var session: AgentSession
    
    @State private var sessionName: String
    @State private var projectPath: String
    @State private var selectedAgent: AgentType
    @State private var selectedOpencodeSession: OpencodeSessionInfo?
    @State private var selectedDefaultProvider: String?
    @State private var selectedDefaultModel: String?
    @State private var availableProviders: [Provider] = []
    @State private var isLoadingProviders = false
    
    init(session: AgentSession, onDelete: @escaping () -> Void) {
        self._session = Bindable(wrappedValue: session)
        self.onDelete = onDelete
        self._sessionName = State(initialValue: session.name)
        self._projectPath = State(initialValue: session.projectPath)
        self._selectedAgent = State(initialValue: session.agentType)
        self._selectedDefaultProvider = State(initialValue: session.defaultProviderID)
        self._selectedDefaultModel = State(initialValue: session.defaultModelID)
        if let id = session.opencodeSessionId, let title = session.opencodeSessionTitle {
            self._selectedOpencodeSession = State(initialValue: OpencodeSessionInfo(id: id, title: title, updated: session.lastActive))
        } else {
            self._selectedOpencodeSession = State(initialValue: nil)
        }
    }
    
    @State private var showFolderPicker = false
    @State private var showOpencodeSessionPicker = false
    @State private var showDeleteConfirmation = false
    @State private var isRefreshingSession = false
    
    @StateObject private var connectionManager = SSHConnectionManager()
    
    let onDelete: () -> Void
    
    private var serverConfig: ServerConfig? { configs.first }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Session Details") {
                    TextField("Session Name", text: $sessionName)
                        .textInputAutocapitalization(.words)
                    
                    HStack {
                        Text(projectPath)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(projectPath == "~/" ? .secondary : .primary)
                        
                        Spacer()
                        
                        Button("Browse") {
                            showFolderPicker = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Section("Agent Type") {
                    Picker("Agent", selection: $selectedAgent) {
                        ForEach(AgentType.allCases, id: \.self) { agent in
                            Label(agent.displayName, systemImage: agent.iconName)
                                .tag(agent)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                
                if selectedAgent == .opencode && projectPath != "~/" {
                    Section("OpenCode Session") {
                        HStack {
                            VStack(alignment: .leading) {
                                if let session = selectedOpencodeSession {
                                    Text(session.title)
                                        .font(.body)
                                    Text(session.id)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("New Session")
                                        .font(.body)
                                    Text("Will create a new OpenCode session")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Change") {
                                showOpencodeSessionPicker = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    Section("Default Model") {
                        if isLoadingProviders {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading models...")
                                    .foregroundStyle(.secondary)
                            }
                        } else if availableProviders.isEmpty {
                            Button("Load Available Models") {
                                Task { await loadProviders() }
                            }
                        } else {
                            Picker("Provider", selection: $selectedDefaultProvider) {
                                Text("Use API Default").tag(nil as String?)
                                ForEach(availableProviders, id: \.id) { provider in
                                    Text(provider.name).tag(provider.id as String?)
                                }
                            }
                            
                            if let providerId = selectedDefaultProvider,
                               let provider = availableProviders.first(where: { $0.id == providerId }) {
                                Picker("Model", selection: $selectedDefaultModel) {
                                    ForEach(provider.models, id: \.id) { model in
                                        Text(model.name).tag(model.id as String?)
                                    }
                                }
                            }
                            
                            if selectedDefaultProvider != nil && selectedDefaultModel != nil {
                                Text("Session will start with this model selected")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: saveChanges) {
                        HStack {
                            Spacer()
                            Label(hasChanges ? "Save Changes" : "Done", systemImage: hasChanges ? "checkmark.circle.fill" : "checkmark")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!isValid)
                }
                
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Delete Connection", systemImage: "trash")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                sessionName = session.name
                projectPath = session.projectPath
                selectedAgent = session.agentType
                if let id = session.opencodeSessionId, let title = session.opencodeSessionTitle {
                    selectedOpencodeSession = OpencodeSessionInfo(id: id, title: title, updated: Date())
                }
            }
            .onChange(of: projectPath) { _, _ in
                selectedOpencodeSession = nil
            }
            .sheet(isPresented: $showFolderPicker) {
                FolderPickerView(
                    connectionManager: connectionManager,
                    serverConfig: serverConfig,
                    selectedPath: $projectPath,
                    onCreateFolder: { }
                )
            }
            .sheet(isPresented: $showOpencodeSessionPicker) {
                OpencodeSessionPickerView(
                    connectionManager: connectionManager,
                    serverConfig: serverConfig,
                    projectPath: projectPath,
                    selectedSession: $selectedOpencodeSession
                )
            }
            .confirmationDialog("Delete Connection?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    deleteSession()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove the connection from the app. The remote tmux session will be stopped if running.")
            }
            .task {
                await refreshOpencodeSessionTitle()
            }
        }
    }
    
    private func refreshOpencodeSessionTitle() async {
        guard let sessionId = session.opencodeSessionId,
              let config = serverConfig else { return }
        
        await MainActor.run { isRefreshingSession = true }
        
        do {
            try await connectionManager.connect(config: config, session: AgentSession(name: "refresh", projectPath: "~/"))
            if let freshSession = try await connectionManager.getOpencodeSession(id: sessionId) {
                await MainActor.run {
                    selectedOpencodeSession = OpencodeSessionInfo(id: sessionId, title: freshSession.title, updated: freshSession.updated)
                    session.opencodeSessionTitle = freshSession.title
                }
            }
        } catch {
            // Silently fail - we still have the cached title
        }
        
        await connectionManager.disconnect()
        await MainActor.run { isRefreshingSession = false }
    }
    
    private var isValid: Bool {
        !sessionName.trimmingCharacters(in: .whitespaces).isEmpty &&
        projectPath != "~/"
    }
    
    private var hasChanges: Bool {
        sessionName != session.name ||
        projectPath != session.projectPath ||
        selectedAgent != session.agentType ||
        selectedOpencodeSession?.id != session.opencodeSessionId ||
        selectedDefaultProvider != session.defaultProviderID ||
        selectedDefaultModel != session.defaultModelID
    }
    
    private func loadProviders() async {
        guard let config = serverConfig,
              let url = URL(string: config.apiURL),
              let apiKey = KeychainManager.shared.getAPIKey() else { return }
        
        isLoadingProviders = true
        defer { isLoadingProviders = false }
        
        do {
            let apiURL = url.appendingPathComponent("projects/\(session.projectName)/api")
            let client = OpenCodeClient(baseURL: apiURL, apiKey: apiKey)
            let response = try await client.getProviders()
            availableProviders = response.providers
            
            if selectedDefaultProvider == nil, let defaults = response.default {
                selectedDefaultProvider = defaults["provider"]
                selectedDefaultModel = defaults["model"]
            }
        } catch {
            logger.error("Failed to load providers: \(error.localizedDescription)")
        }
    }
    
    private func saveChanges() {
        let sessionChanged = selectedOpencodeSession?.id != session.opencodeSessionId
        
        session.name = sessionName.trimmingCharacters(in: .whitespaces)
        session.projectPath = projectPath.trimmingCharacters(in: .whitespaces)
        session.agentType = selectedAgent
        session.opencodeSessionId = selectedOpencodeSession?.id
        session.opencodeSessionTitle = selectedOpencodeSession?.title
        session.defaultProviderID = selectedDefaultProvider
        session.defaultModelID = selectedDefaultModel
        session.lastActive = Date()
        
        if sessionChanged, let config = serverConfig {
            Task {
                do {
                    try await connectionManager.connect(config: config, session: session)
                    _ = try await connectionManager.ensureSession(session: session, config: config, action: "stop")
                    await connectionManager.disconnect()
                } catch {
                    print("Failed to stop old session: \(error)")
                }
                await MainActor.run {
                    dismiss()
                }
            }
        } else {
            dismiss()
        }
    }
    
    private func deleteSession() {
        Task {
            if let config = serverConfig {
                do {
                    try await connectionManager.connect(config: config, session: session)
                    _ = try await connectionManager.ensureSession(session: session, config: config, action: "stop")
                    await connectionManager.disconnect()
                } catch {
                    print("Failed to stop remote session: \(error)")
                }
            }
            await MainActor.run {
                modelContext.delete(session)
                onDelete()
                dismiss()
            }
        }
    }
}
