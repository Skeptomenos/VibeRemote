import SwiftUI
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.vibeRemote.app", category: "SettingsView")

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(OpenCodeVersionManager.self) private var versionManager
    @Query private var configs: [ServerConfig]
    
    @State private var host = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var password = ""
    @State private var publicKey = ""
    @State private var showingKeyGeneration = false
    @State private var showingKeySetup = false
    @State private var keyPushState: AsyncOperationState = .idle
    
    @State private var apiURL = ""
    @State private var apiKey = ""
    @State private var showingAPIKey = false
    @State private var apiKeyTestState: AsyncOperationState = .idle
    

    
    private var config: ServerConfig? {
        configs.first
    }
    
    private var hasValidSSHConfig: Bool {
        !host.isEmpty && !username.isEmpty
    }
    
    private var hasValidAPIConfig: Bool {
        !apiURL.isEmpty && !apiKey.isEmpty && URLValidator.isValid(apiURL)
    }
    
    private var urlValidationMessage: String? {
        URLValidator.validationMessage(for: apiURL)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Server Connection") {
                    TextField("Host (IP or Tailscale name)", text: $host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                    
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                Section("SSH Key") {
                    if KeychainManager.shared.hasKey(label: "viberemote-key") {
                        Label("Key Generated", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        
                        Button("Show Public Key") {
                            loadPublicKey()
                            showingKeyGeneration = true
                        }
                        
                        Button {
                            loadPublicKey()
                            UIPasteboard.general.string = publicKey
                        } label: {
                            Label("Copy Public Key", systemImage: "doc.on.doc")
                        }
                        
                        Button("Regenerate Key", role: .destructive) {
                            generateNewKey()
                        }
                    } else {
                        Button("Generate SSH Key") {
                            generateNewKey()
                        }
                    }
                }
                
                Section("Install Key on Server") {
                    SecureField("Server Password", text: $password)
                        .textContentType(.password)
                    
                    Button {
                        pushKeyToServer()
                    } label: {
                        HStack {
                            switch keyPushState {
                            case .idle:
                                Label("Install Key via Password", systemImage: "key.fill")
                            case .inProgress:
                                ProgressView()
                                    .controlSize(.small)
                                Text("Connecting...")
                            case .success:
                                Label("Key Installed!", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            case .failed:
                                Label("Failed - Tap to Retry", systemImage: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .disabled(host.isEmpty || username.isEmpty || password.isEmpty || keyPushState.isInProgress)
                    
                    if case .failed(let error) = keyPushState {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    
                    Text("Enter your server password to automatically install the SSH key. The password is not stored.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("API Connection (Native Chat)") {
                    TextField("Gateway URL", text: $apiURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    
                    if let validationMessage = urlValidationMessage {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    
                    HStack {
                        if showingAPIKey {
                            TextField("API Key", text: $apiKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("API Key", text: $apiKey)
                        }
                        
                        Button(action: { showingAPIKey.toggle() }) {
                            Image(systemName: showingAPIKey ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button {
                        testAPIConnection()
                    } label: {
                        HStack {
                            switch apiKeyTestState {
                            case .idle:
                                Label("Test Connection", systemImage: "network")
                            case .inProgress:
                                ProgressView()
                                    .controlSize(.small)
                                Text("Testing...")
                            case .success:
                                Label("Connection Successful!", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            case .failed:
                                Label("Failed - Tap to Retry", systemImage: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .disabled(!hasValidAPIConfig || apiKeyTestState.isInProgress)
                    
                    if case .failed(let error) = apiKeyTestState {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    
                    Text("Enter your Gateway URL and API Key to use the native chat interface. Get these from your server setup.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Administration") {
                    NavigationLink {
                        UpdateOpenCodeView()
                    } label: {
                        HStack {
                            Label("Update OpenCode", systemImage: "arrow.down.circle")
                            Spacer()
                            if versionManager.isChecking {
                                ProgressView()
                            } else if versionManager.isUpdateAvailable {
                                Text("Update Available")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(OpenCodeTheme.success)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    
                    NavigationLink {
                        TmuxAdminView()
                    } label: {
                        Label("Tmux Sessions", systemImage: "terminal")
                    }
                }
                
                Section {
                    Button("Save") {
                        saveConfig()
                        dismiss()
                    }
                    .disabled(!hasValidSSHConfig && !hasValidAPIConfig)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if let config = config {
                    host = config.host
                    port = String(config.port)
                    username = config.username
                    apiURL = config.apiURL
                }
                // Load API key from Keychain
                if let storedAPIKey = KeychainManager.shared.getAPIKey() {
                    apiKey = storedAPIKey
                }
            }
            .task {
                if let config = config {
                    await versionManager.checkVersions(config: config)
                }
            }
            .onChange(of: apiURL) { _, _ in
                apiKeyTestState = .idle
            }
            .onChange(of: apiKey) { _, _ in
                apiKeyTestState = .idle
            }
            .sheet(isPresented: $showingKeyGeneration) {
                PublicKeyView(publicKey: publicKey)
            }
        }
    }
    
    private func generateNewKey() {
        do {
            publicKey = try KeychainManager.shared.generateKeyPair(label: "viberemote-key")
            showingKeyGeneration = true
        } catch {
            logger.error("Key generation failed: \(error.localizedDescription)")
        }
    }
    
    private func loadPublicKey() {
        do {
            publicKey = try KeychainManager.shared.getPublicKeyString(label: "viberemote-key")
        } catch {
            logger.error("Failed to load public key: \(error.localizedDescription)")
        }
    }
    
    private func pushKeyToServer() {
        Task {
            keyPushState = .inProgress
            
            do {
                if !KeychainManager.shared.hasKey(label: "viberemote-key") {
                    publicKey = try KeychainManager.shared.generateKeyPair(label: "viberemote-key")
                } else {
                    publicKey = try KeychainManager.shared.getPublicKeyString(label: "viberemote-key")
                }
                
                let manager = SSHConnectionManager()
                try await manager.connectWithPassword(
                    host: host,
                    port: Int(port) ?? 22,
                    username: username,
                    password: password
                )
                
                try await manager.pushSSHKey(publicKey: publicKey)
                await manager.disconnect()
                
                keyPushState = .success
                password = ""
            } catch {
                keyPushState = .failed(error.localizedDescription)
            }
        }
    }
    
    private func saveConfig() {
        // Save SSH config
        if let existingConfig = config {
            existingConfig.host = host
            existingConfig.port = Int(port) ?? 22
            existingConfig.username = username
            existingConfig.apiURL = apiURL
        } else {
            let newConfig = ServerConfig(
                host: host,
                port: Int(port) ?? 22,
                username: username,
                apiURL: apiURL
            )
            modelContext.insert(newConfig)
        }
        
        if !apiKey.isEmpty {
            do {
                try KeychainManager.shared.storeAPIKey(apiKey)
            } catch {
                logger.error("Failed to save API key to Keychain: \(error.localizedDescription)")
            }
        } else {
            // clear key if empty
            try? KeychainManager.shared.deleteAPIKey()
        }
    }
    
    private func testAPIConnection() {
        guard let url = URL(string: apiURL), !apiKey.isEmpty else { return }
        
        Task {
            apiKeyTestState = .inProgress
            
            do {
                let client = GatewayClient(baseURL: url, apiKey: apiKey)
                let healthy = try await client.healthCheck()
                
                if healthy {
                    apiKeyTestState = .success
                } else {
                    apiKeyTestState = .failed("Gateway not responding")
                }
            } catch {
                apiKeyTestState = .failed(error.localizedDescription)
            }
        }
    }
}

struct PublicKeyView: View {
    let publicKey: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Add this key to your Mac mini")
                    .font(.headline)
                
                Text("Copy and paste this into ~/.ssh/authorized_keys on your server:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Text(publicKey)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .background(OpenCodeTheme.backgroundElement)
                    .cornerRadius(8)
                    .textSelection(.enabled)
                
                Button("Copy to Clipboard") {
                    UIPasteboard.general.string = publicKey
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Public Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
