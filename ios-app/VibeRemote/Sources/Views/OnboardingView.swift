import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var configs: [ServerConfig]
    
    @State private var currentStep = 0
    @State private var host = ""
    @State private var username = ""
    @State private var password = ""
    @State private var publicKey = ""
    @State private var connectionTested = false
    @State private var testError: String?
    @State private var keyPushState: AsyncOperationState = .idle
    @State private var isConnecting = false
    @State private var keyPushTask: Task<Void, Never>?
    
    private var hasExistingConfig: Bool {
        configs.first?.isConfigured ?? false
    }
    
    var body: some View {
        NavigationStack {
            TabView(selection: $currentStep) {
                WelcomeStep(onContinue: { currentStep = 1 })
                    .tag(0)
                
                ServerConfigStep(
                    host: $host,
                    username: $username,
                    onContinue: { currentStep = 2 }
                )
                .tag(1)
                
                KeySetupStep(
                    host: host,
                    username: username,
                    password: $password,
                    publicKey: $publicKey,
                    keyPushState: $keyPushState,
                    isConnecting: $isConnecting,
                    onGenerateAndPush: generateAndPushKey,
                    onContinue: { currentStep = 3 }
                )
                .tag(2)
                
                TestConnectionStep(
                    connectionTested: connectionTested,
                    testError: testError,
                    onTest: testConnection,
                    onFinish: finishOnboarding
                )
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if hasExistingConfig {
                        Button("Skip") { dismiss() }
                    }
                }
            }
        }
        .interactiveDismissDisabled(!hasExistingConfig)
        .onDisappear {
            keyPushTask?.cancel()
        }
    }
    
    private func generateAndPushKey() {
        keyPushTask?.cancel()
        
        keyPushTask = Task {
            isConnecting = true
            keyPushState = .inProgress
            
            do {
                if publicKey.isEmpty {
                    publicKey = try KeychainManager.shared.generateKeyPair(label: "viberemote-key")
                }
                
                let manager = SSHConnectionManager()
                try await manager.connectWithPassword(
                    host: host,
                    port: 22,
                    username: username,
                    password: password
                )
                
                guard !Task.isCancelled else {
                    await manager.disconnect()
                    password = "" // Clear password on cancellation
                    return
                }
                
                try await manager.pushSSHKey(publicKey: publicKey)
                await manager.disconnect()
                
                guard !Task.isCancelled else {
                    password = "" // Clear password on cancellation
                    return
                }
                
                keyPushState = .success
                password = ""
            } catch {
                if !Task.isCancelled {
                    keyPushState = .failed(error.localizedDescription)
                }
                // Always clear password on failure for security
                password = ""
            }
            
            if !Task.isCancelled {
                isConnecting = false
            }
        }
    }
    
    private func testConnection() {
        Task {
            do {
                let config = ServerConfig(host: host, port: 22, username: username)
                let manager = SSHConnectionManager()
                let dummySession = AgentSession(name: "test", projectPath: "~")
                try await manager.connect(config: config, session: dummySession)
                await manager.disconnect()
                connectionTested = true
                testError = nil
            } catch {
                testError = error.localizedDescription
                connectionTested = false
            }
        }
    }
    
    private func finishOnboarding() {
        let config = ServerConfig(host: host, port: 22, username: username)
        modelContext.insert(config)
        try? modelContext.save()
        dismiss()
    }
}

struct WelcomeStep: View {
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "terminal.fill")
                .font(.system(size: 80))
                .foregroundStyle(.tint)
            
            Text("Welcome to VibeRemote")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Access your OpenCode sessions from anywhere.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Button(action: onContinue) {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

struct ServerConfigStep: View {
    @Binding var host: String
    @Binding var username: String
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Connect to Your Server")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Enter your Mac mini's Tailscale IP or hostname.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                TextField("Host (e.g., 100.64.0.1)", text: $host)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            Button(action: onContinue) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .disabled(host.isEmpty || username.isEmpty)
        }
        .padding()
    }
}

struct KeySetupStep: View {
    let host: String
    let username: String
    @Binding var password: String
    @Binding var publicKey: String
    @Binding var keyPushState: AsyncOperationState
    @Binding var isConnecting: Bool
    let onGenerateAndPush: () -> Void
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Text("SSH Key Setup")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Enter your server password to automatically set up SSH key authentication.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                SecureField("Server Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                
                switch keyPushState {
                case .idle:
                    EmptyView()
                case .inProgress:
                    HStack {
                        ProgressView()
                        Text("Connecting and setting up key...")
                            .foregroundStyle(.secondary)
                    }
                case .success:
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("SSH key installed successfully!")
                            .foregroundStyle(.green)
                    }
                case .failed(let error):
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text("Setup failed")
                                .foregroundStyle(.red)
                        }
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.horizontal, 40)
            
            if !publicKey.isEmpty {
                VStack(spacing: 8) {
                    Text("Public Key:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(publicKey)
                        .font(.system(.caption2, design: .monospaced))
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                if case .success = keyPushState {
                    Button(action: onContinue) {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button(action: onGenerateAndPush) {
                        Label(
                            publicKey.isEmpty ? "Generate Key & Connect" : "Connect & Install Key",
                            systemImage: "key.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(password.isEmpty || isConnecting)
                }
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

struct TestConnectionStep: View {
    let connectionTested: Bool
    let testError: String?
    let onTest: () -> Void
    let onFinish: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Test Connection")
                .font(.title2)
                .fontWeight(.semibold)
            
            if connectionTested {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                
                Text("Connection Successful!")
                    .font(.title3)
                    .foregroundStyle(.green)
            } else if let error = testError {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.red)
                
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            } else {
                Text("Verify that your server is reachable and the SSH key is configured.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Button(action: onTest) {
                    Label("Test Connection", systemImage: "network")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button(action: onFinish) {
                    Text("Finish Setup")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!connectionTested)
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
}
