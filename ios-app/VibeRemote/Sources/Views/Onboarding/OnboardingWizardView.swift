import SwiftUI
import SwiftData

struct OnboardingWizardView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    
    @State private var currentStep = 0
    @State private var gatewayURL = ""
    @State private var apiKey = ""
    @State private var isTestingConnection = false
    @State private var connectionStatus: ConnectionStatus = .none
    
    enum ConnectionStatus {
        case none
        case success
        case failure(String)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                TabView(selection: $currentStep) {
                    WelcomeStep(onNext: { nextStep() })
                        .tag(0)
                    
                    GatewaySetupStep(
                        url: $gatewayURL,
                        apiKey: $apiKey,
                        onNext: { nextStep() }
                    )
                    .tag(1)
                    
                    ConnectionTestStep(
                        url: gatewayURL,
                        apiKey: apiKey,
                        isTesting: $isTestingConnection,
                        status: $connectionStatus,
                        onTest: testConnection,
                        onNext: { completeOnboarding() }
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
            }
            .background(Color(hex: 0x0A0A0A))
            .preferredColorScheme(.dark)
        }
        .interactiveDismissDisabled()
    }
    
    private func nextStep() {
        withAnimation {
            currentStep += 1
        }
    }
    
    private func testConnection() async {
        isTestingConnection = true
        connectionStatus = .none
        
        guard !gatewayURL.isEmpty else {
            connectionStatus = .failure("Gateway URL is required")
            isTestingConnection = false
            return
        }
        
        guard let url = URL(string: gatewayURL) else {
            connectionStatus = .failure("Invalid Gateway URL format")
            isTestingConnection = false
            return
        }
        
        guard !apiKey.isEmpty else {
            connectionStatus = .failure("API Key is required")
            isTestingConnection = false
            return
        }
        
        do {
            let client = OpenCodeClient(baseURL: url, apiKey: apiKey)
            let isHealthy = try await client.healthCheck()
            
            if isHealthy {
                connectionStatus = .success
            } else {
                connectionStatus = .failure("Gateway returned unhealthy status")
            }
        } catch {
            connectionStatus = .failure(error.localizedDescription)
        }
        
        isTestingConnection = false
    }
    
    private func completeOnboarding() {
        // Fetch existing or create new preferences
        let prefs: UserPreferences
        if let existing = try? modelContext.fetch(FetchDescriptor<UserPreferences>()).first {
            prefs = existing
        } else {
            prefs = UserPreferences()
            modelContext.insert(prefs)
        }
        
        prefs.hasCompletedOnboarding = true
        try? modelContext.save()
        
        if let url = URL(string: gatewayURL) {
            let config = ServerConfig(gatewayURL: url)
            modelContext.insert(config)
            try? KeychainManager.shared.storeAPIKey(apiKey)
        }
        
        isPresented = false
    }
}

struct WelcomeStep: View {
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "rocket")
                .font(.system(size: 64))
                .foregroundStyle(Color(hex: 0xFAB283))
            
            VStack(spacing: 8) {
                Text("Welcome to VibeRemote")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Color(hex: 0xEEEEEE))
                
                Text("Control your AI coding agents from anywhere.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(hex: 0x808080))
                    .padding(.horizontal)
            }
            
            Spacer()
            
            Button(action: onNext) {
                Text("Start Building")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(hex: 0xFAB283))
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
}

struct GatewaySetupStep: View {
    @Binding var url: String
    @Binding var apiKey: String
    let onNext: () -> Void
    
    @State private var isAPIKeyVisible = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(alignment: .leading, spacing: 24) {
                Text("Setup Gateway")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color(hex: 0xEEEEEE))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gateway URL")
                        .font(.caption)
                        .foregroundStyle(Color(hex: 0x808080))
                    
                    TextField("https://...", text: $url)
                        .padding()
                        .background(Color(hex: 0x1E1E1E))
                        .cornerRadius(8)
                        .foregroundStyle(Color(hex: 0xEEEEEE))
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(.caption)
                        .foregroundStyle(Color(hex: 0x808080))
                    
                    HStack {
                        if isAPIKeyVisible {
                            TextField("sk-...", text: $apiKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .foregroundStyle(Color(hex: 0xEEEEEE))
                        } else {
                            SecureField("sk-...", text: $apiKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .foregroundStyle(Color(hex: 0xEEEEEE))
                        }
                        
                        Button(action: { isAPIKeyVisible.toggle() }) {
                            Image(systemName: isAPIKeyVisible ? "eye.slash" : "eye")
                                .foregroundStyle(Color(hex: 0x808080))
                        }
                    }
                    .padding()
                    .background(Color(hex: 0x1E1E1E))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            Button(action: onNext) {
                Text("Continue")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isValid ? Color(hex: 0xFAB283) : Color(hex: 0x3C3C3C))
                    .cornerRadius(12)
            }
            .disabled(!isValid)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
    
    private var isValid: Bool {
        !url.isEmpty && !apiKey.isEmpty
    }
}

struct ConnectionTestStep: View {
    let url: String
    let apiKey: String
    @Binding var isTesting: Bool
    @Binding var status: OnboardingWizardView.ConnectionStatus
    let onTest: () async -> Void
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                statusIcon
                
                Text(statusText)
                    .font(.headline)
                    .foregroundStyle(Color(hex: 0xEEEEEE))
                
                if case .failure(let error) = status {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Color(hex: 0xE06C75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            Spacer()
            
            if case .success = status {
                Button(action: onNext) {
                    Text("Start Using VibeRemote")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(hex: 0x7FD88F))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            } else {
                Button(action: { Task { await onTest() } }) {
                    HStack {
                        if isTesting {
                            ProgressView()
                                .tint(.black)
                                .padding(.trailing, 8)
                        }
                        Text(isTesting ? "Testing..." : "Test Connection")
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(hex: 0xFAB283))
                    .cornerRadius(12)
                }
                .disabled(isTesting)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .task {
            // Auto-start test when appearing
            if case .none = status {
                await onTest()
            }
        }
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        if isTesting {
            Image(systemName: "network")
                .font(.system(size: 48))
                .foregroundStyle(Color(hex: 0x5C9CF5))
                .symbolEffect(.pulse)
        } else {
            switch status {
            case .none:
                Image(systemName: "network")
                    .font(.system(size: 48))
                    .foregroundStyle(Color(hex: 0x808080))
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color(hex: 0x7FD88F))
            case .failure:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color(hex: 0xE06C75))
            }
        }
    }
    
    private var statusText: String {
        if isTesting { return "Connecting to Gateway..." }
        switch status {
        case .none: return "Ready to Connect"
        case .success: return "Connected Successfully"
        case .failure: return "Connection Failed"
        }
    }
}
