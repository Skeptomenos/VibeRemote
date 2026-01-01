import SwiftUI
import SwiftData

struct NewSessionWizard: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var configs: [ServerConfig]
    
    @State private var sessionName = ""
    @State private var projectPath = "~/"
    @State private var selectedAgent: AgentType = .opencode
    @State private var selectedOpencodeSession: OpencodeSessionInfo?
    
    @State private var showFolderPicker = false
    @State private var showOpencodeSessionPicker = false
    @State private var showNewFolderAlert = false
    @State private var newFolderName = ""
    
    @StateObject private var connectionManager = SSHConnectionManager()
    
    let onCreate: (AgentSession) -> Void
    
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
                        if let session = selectedOpencodeSession {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(session.title)
                                        .font(.body)
                                    Text(session.id)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Change") {
                                    showOpencodeSessionPicker = true
                                }
                                .buttonStyle(.bordered)
                            }
                        } else {
                            HStack {
                                Text("New Session")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Pick Existing") {
                                    showOpencodeSessionPicker = true
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: createSession) {
                        HStack {
                            Spacer()
                            Label("Launch Session", systemImage: "play.fill")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!isValid)
                }
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
                    onCreateFolder: { showNewFolderAlert = true }
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
            .alert("New Folder", isPresented: $showNewFolderAlert) {
                TextField("Folder name", text: $newFolderName)
                Button("Cancel", role: .cancel) { newFolderName = "" }
                Button("Create") {
                    Task { await createFolder() }
                }
            } message: {
                Text("Enter name for new folder in ~/")
            }
        }
    }
    
    private var isValid: Bool {
        !sessionName.trimmingCharacters(in: .whitespaces).isEmpty &&
        projectPath != "~/"
    }
    
    private func createSession() {
        let session = AgentSession(
            name: sessionName.trimmingCharacters(in: .whitespaces),
            projectPath: projectPath.trimmingCharacters(in: .whitespaces),
            agentType: selectedAgent,
            opencodeSessionId: selectedOpencodeSession?.id,
            opencodeSessionTitle: selectedOpencodeSession?.title
        )
        onCreate(session)
        dismiss()
    }
    
    private func createFolder() async {
        let sanitizedName = newFolderName.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == "." }
        guard let config = serverConfig, !sanitizedName.isEmpty else { return }
        do {
            try await connectionManager.connect(config: config, session: AgentSession(name: "temp", projectPath: "~/"))
            _ = try await connectionManager.executeCommand("mkdir -p ~/\(sanitizedName)")
            projectPath = "~/\(sanitizedName)"
            newFolderName = ""
        } catch {
            print("Create folder error: \(error)")
        }
        await connectionManager.disconnect()
    }
}

struct OpencodeSessionInfo: Identifiable, Equatable {
    let id: String
    let title: String
    let updated: Date
}

struct FolderPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var connectionManager: SSHConnectionManager
    let serverConfig: ServerConfig?
    @Binding var selectedPath: String
    let onCreateFolder: () -> Void
    
    @State private var folders: [String] = []
    @State private var isLoading = true
    @State private var error: String?
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading folders...")
                } else if let error = error {
                    ContentUnavailableView("Connection Error", systemImage: "wifi.slash", description: Text(error))
                } else if folders.isEmpty {
                    ContentUnavailableView("No Folders", systemImage: "folder", description: Text("No folders found in home directory"))
                } else {
                    List(folders, id: \.self) { folder in
                        Button {
                            selectedPath = "~/\(folder)"
                            dismiss()
                        } label: {
                            Label(folder, systemImage: "folder.fill")
                        }
                    }
                }
            }
            .navigationTitle("Select Project Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New Folder", systemImage: "folder.badge.plus") {
                        dismiss()
                        onCreateFolder()
                    }
                }
            }
            .task {
                await loadFolders()
            }
        }
    }
    
    private func loadFolders() async {
        guard let config = serverConfig else {
            error = "No server configured"
            isLoading = false
            return
        }
        
        do {
            try await connectionManager.connect(config: config, session: AgentSession(name: "temp", projectPath: "~/"))
            folders = try await connectionManager.listDirectories()
            folders = folders.filter { !$0.hasPrefix(".") }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
        await connectionManager.disconnect()
        await MainActor.run { isLoading = false }
    }
}

struct OpencodeSessionPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var connectionManager: SSHConnectionManager
    let serverConfig: ServerConfig?
    let projectPath: String
    @Binding var selectedSession: OpencodeSessionInfo?
    
    @State private var sessions: [OpencodeSessionInfo] = []
    @State private var isLoading = true
    @State private var error: String?
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading sessions...")
                } else if let error = error {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if sessions.isEmpty {
                    ContentUnavailableView("No Sessions", systemImage: "bubble.left.and.bubble.right", description: Text("No OpenCode sessions found for this project. A new session will be created."))
                } else {
                    List {
                        Section {
                            Button {
                                selectedSession = nil
                                dismiss()
                            } label: {
                                Label("Start New Session", systemImage: "plus.circle")
                            }
                        }
                        
                        Section("Existing Sessions") {
                            ForEach(sessions) { session in
                                Button {
                                    selectedSession = session
                                    dismiss()
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(session.title)
                                            .font(.body)
                                        Text("Updated: \(session.updated.formatted())")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("OpenCode Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
        
        do {
            try await connectionManager.connect(config: config, session: AgentSession(name: "temp", projectPath: "~/"))
            let rawSessions = try await connectionManager.listOpencodeSessions(forDirectory: projectPath)
            
            // OpenCode returns timestamps in milliseconds
            sessions = rawSessions.compactMap { dict -> OpencodeSessionInfo? in
                guard let id = dict["id"] as? String,
                      let title = dict["title"] as? String,
                      let updated = dict["updated"] as? Double else { return nil }
                return OpencodeSessionInfo(id: id, title: title, updated: Date(timeIntervalSince1970: updated / 1000))
            }.sorted { $0.updated > $1.updated }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
        await connectionManager.disconnect()
        await MainActor.run { isLoading = false }
    }
}
