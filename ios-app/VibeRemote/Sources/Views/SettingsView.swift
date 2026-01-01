import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var configs: [ServerConfig]
    
    @State private var host = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var publicKey = ""
    @State private var showingKeyGeneration = false
    
    private var config: ServerConfig? {
        configs.first
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
                        
                        Button("Regenerate Key", role: .destructive) {
                            generateNewKey()
                        }
                    } else {
                        Button("Generate SSH Key") {
                            generateNewKey()
                        }
                    }
                }
                
                Section {
                    Button("Save") {
                        saveConfig()
                        dismiss()
                    }
                    .disabled(host.isEmpty || username.isEmpty)
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
                }
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
            print("Key generation failed: \(error)")
        }
    }
    
    private func loadPublicKey() {
        do {
            publicKey = try KeychainManager.shared.getPublicKeyString(label: "viberemote-key")
        } catch {
            print("Failed to load public key: \(error)")
        }
    }
    
    private func saveConfig() {
        if let existingConfig = config {
            existingConfig.host = host
            existingConfig.port = Int(port) ?? 22
            existingConfig.username = username
        } else {
            let newConfig = ServerConfig(
                host: host,
                port: Int(port) ?? 22,
                username: username
            )
            modelContext.insert(newConfig)
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
                    .background(Color(.systemGray6))
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
