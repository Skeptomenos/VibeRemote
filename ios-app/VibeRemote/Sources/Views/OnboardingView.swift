import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var configs: [ServerConfig]
    
    @State private var currentStep = 0
    @State private var host = ""
    @State private var username = ""
    @State private var publicKey = ""
    @State private var connectionTested = false
    @State private var testError: String?
    
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
                
                KeyGenerationStep(
                    publicKey: $publicKey,
                    onGenerate: generateKey,
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
    }
    
    private func generateKey() {
        do {
            publicKey = try KeychainManager.shared.generateKeyPair(label: "viberemote-key")
        } catch {
            print("Key generation failed: \(error)")
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

struct KeyGenerationStep: View {
    @Binding var publicKey: String
    let onGenerate: () -> Void
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Generate SSH Key")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("We'll create a secure key pair. Add the public key to your server's ~/.ssh/authorized_keys file.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            if publicKey.isEmpty {
                Button(action: onGenerate) {
                    Label("Generate Key", systemImage: "key.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.horizontal, 40)
            } else {
                VStack(spacing: 12) {
                    Text(publicKey)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .textSelection(.enabled)
                    
                    Button("Copy to Clipboard") {
                        UIPasteboard.general.string = publicKey
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            Button(action: onContinue) {
                Text("I've Added the Key")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .disabled(publicKey.isEmpty)
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
