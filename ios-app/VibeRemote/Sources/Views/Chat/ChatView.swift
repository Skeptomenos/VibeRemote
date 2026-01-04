import SwiftUI

struct ChatContainerView: View {
    let session: AgentSession
    let gatewayURL: URL
    let apiKey: String
    
    @StateObject private var viewModel: ChatViewModel
    @State private var showStatusPanel = false
    @State private var showModelPicker = false
    
    init(session: AgentSession, gatewayURL: URL, apiKey: String) {
        self.session = session
        self.gatewayURL = gatewayURL
        self.apiKey = apiKey
        self._viewModel = StateObject(wrappedValue: ChatViewModel(
            session: session,
            gatewayURL: gatewayURL,
            apiKey: apiKey
        ))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VibeTheme.Colors.bg
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    chatHeader
                    
                    if viewModel.messages.isEmpty && !viewModel.isLoading {
                        emptyState
                    } else {
                        messageList
                    }
                    
                    ChatInputBar(
                        text: $viewModel.inputText,
                        isStreaming: viewModel.isLoading,
                        commands: viewModel.commands,
                        onSend: { await viewModel.sendMessage() },
                        onStop: { await viewModel.abort() }
                    )
                    .padding(.horizontal, VibeTheme.Spacing.md)
                    .padding(.bottom, VibeTheme.Spacing.md)
                }
                
                if case .error(let message) = viewModel.connectionState {
                    connectionErrorBanner(message)
                }
            }
        }
        .task {
            await viewModel.connect()
        }
        .onDisappear {
            viewModel.disconnect()
        }
        .sheet(isPresented: $showStatusPanel) {
            StatusPanelView(viewModel: viewModel)
        }
        .sheet(isPresented: $showModelPicker) {
            ModelPickerSheet(viewModel: viewModel)
        }
    }
    
    private var chatHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(VibeTheme.Typography.bodySemibold)
                    .foregroundStyle(VibeTheme.Colors.fg)
                
                Text(session.projectName)
                    .font(VibeTheme.Typography.caption)
                    .foregroundStyle(VibeTheme.Colors.fgSecondary)
            }
            
            Spacer()
            
            Button(action: { showModelPicker = true }) {
                HStack(spacing: VibeTheme.Spacing.xxs) {
                    Text(viewModel.selectedModel ?? "Select Model")
                        .font(VibeTheme.Typography.caption)
                        .foregroundStyle(VibeTheme.Colors.fg)
                    
                    Image(systemName: VibeTheme.Icons.chevronDown)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(VibeTheme.Colors.fgSecondary)
                }
                .padding(.horizontal, VibeTheme.Spacing.sm)
                .padding(.vertical, VibeTheme.Spacing.xs)
                .background(VibeTheme.Colors.surfacePrimary)
                .cornerRadius(VibeTheme.Radius.sm)
            }
            
            Menu {
                Button(action: { showStatusPanel = true }) {
                    Label("Session Info", systemImage: "info.circle")
                }
                
                Button(action: {
                    Task { await viewModel.restartOpenCode() }
                }) {
                    Label("Restart OpenCode", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isRestarting)
            } label: {
                if viewModel.isRestarting {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(VibeTheme.Colors.fgSecondary)
                }
            }
            .padding(.leading, VibeTheme.Spacing.xs)
            
            connectionIndicator
        }
        .padding(.horizontal, VibeTheme.Spacing.md)
        .padding(.vertical, VibeTheme.Spacing.sm)
        .background(VibeTheme.Colors.surfacePrimary.opacity(0.5))
    }
    
    private var connectionIndicator: some View {
        Circle()
            .fill(connectionColor)
            .frame(width: 8, height: 8)
            .padding(.leading, VibeTheme.Spacing.xs)
    }
    
    private var connectionColor: Color {
        switch viewModel.connectionState {
        case .connected: return VibeTheme.Colors.Fallback.success
        case .connecting: return VibeTheme.Colors.Fallback.warning
        case .disconnected: return VibeTheme.Colors.fgTertiary
        case .error: return VibeTheme.Colors.Fallback.error
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: VibeTheme.Spacing.lg) {
            Spacer()
            
            Text("What can I help with?")
                .font(VibeTheme.Typography.title2)
                .foregroundStyle(VibeTheme.Colors.fg)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: VibeTheme.Spacing.xl) {
                    ForEach(viewModel.messages) { message in
                        MessageView(message: message)
                            .id(message.id)
                            .contextMenu {
                                Button("Copy", systemImage: "doc.on.doc") {
                                    UIPasteboard.general.string = message.textContent
                                }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    Task {
                                        await viewModel.deleteMessage(message.id)
                                    }
                                }
                            }
                    }
                    
                    if viewModel.isLoading {
                        TypingIndicator()
                            .id("typing")
                    }
                }
                .padding(.horizontal, VibeTheme.Spacing.md)
                .padding(.vertical, VibeTheme.Spacing.lg)
                .frame(maxWidth: VibeTheme.Spacing.maxContentWidth)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(VibeTheme.Animation.smooth) {
                    proxy.scrollTo(viewModel.messages.last?.id ?? "typing", anchor: .bottom)
                }
            }
        }
    }
    
    private func connectionErrorBanner(_ message: String) -> some View {
        VStack {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(VibeTheme.Colors.Fallback.warning)
                
                Text(message)
                    .font(VibeTheme.Typography.caption)
                    .foregroundStyle(VibeTheme.Colors.fg)
                
                Spacer()
                
                Button("Retry") {
                    Task { await viewModel.connect() }
                }
                .font(VibeTheme.Typography.caption)
                .foregroundStyle(VibeTheme.Colors.tint)
            }
            .padding(VibeTheme.Spacing.sm)
            .background(VibeTheme.Colors.surfacePrimary)
            .cornerRadius(VibeTheme.Radius.sm)
            .padding(.horizontal, VibeTheme.Spacing.md)
            .padding(.top, VibeTheme.Spacing.md)
            
            Spacer()
        }
    }
}

struct TypingIndicator: View {
    @State private var animationPhase = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(VibeTheme.Colors.fgTertiary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationPhase == index ? 1.3 : 1.0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4).repeatForever()) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

struct ModelPickerSheet: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationStack {
            List {
                if viewModel.providers.isEmpty {
                    HStack {
                        ProgressView()
                            .padding(.trailing, VibeTheme.Spacing.sm)
                        Text("Loading models...")
                            .foregroundStyle(VibeTheme.Colors.fgSecondary)
                    }
                } else {
                    ForEach(viewModel.providers) { provider in
                        Section(provider.name) {
                            ForEach(provider.models) { model in
                                Button(action: {
                                    viewModel.selectedProvider = provider.id
                                    viewModel.selectedModel = model.id
                                    dismiss()
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(model.name)
                                                .foregroundStyle(VibeTheme.Colors.fg)
                                            
                                            if let context = model.contextWindowFormatted {
                                                Text("\(context) context")
                                                    .font(VibeTheme.Typography.caption)
                                                    .foregroundStyle(VibeTheme.Colors.fgSecondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        if viewModel.selectedProvider == provider.id && viewModel.selectedModel == model.id {
                                            Image(systemName: VibeTheme.Icons.check)
                                                .foregroundStyle(VibeTheme.Colors.tint)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.refreshProviders()
            }
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            isRefreshing = true
                            await viewModel.refreshProviders()
                            isRefreshing = false
                        }
                    } label: {
                        if isRefreshing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isRefreshing)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    ChatContainerView(
        session: AgentSession(name: "Test", projectPath: "/home/linux/TestProject"),
        gatewayURL: URL(string: "https://vibecode.helmes.me")!,
        apiKey: "test-key"
    )
    .preferredColorScheme(.dark)
}
