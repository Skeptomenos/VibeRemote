import SwiftUI
import SwiftData
import SwiftTerm

struct TerminalContainerView: View {
    let session: AgentSession
    @StateObject private var connectionManager = SSHConnectionManager()
    @Query private var configs: [ServerConfig]
    @State private var terminalSize: (cols: Int, rows: Int) = (80, 24)
    @State private var coordinator: SwiftTermView.Coordinator?
    
    private var serverConfig: ServerConfig? {
        configs.first
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ConnectionStatusBar(state: connectionManager.connectionState, error: connectionManager.lastError)
                
                SwiftTermView(
                    connectionManager: connectionManager,
                    session: session,
                    size: geometry.size,
                    onCoordinatorCreated: { coord in
                        self.coordinator = coord
                    },
                    onSizeChanged: { cols, rows in
                        self.terminalSize = (cols, rows)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Restart Agent", systemImage: "arrow.clockwise") {
                        Task { await restartSession() }
                    }
                    Button("Disconnect", systemImage: "xmark.circle") {
                        Task { await connectionManager.disconnect() }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            await connectToSession()
        }
    }
    
    private func connectToSession() async {
        guard let config = serverConfig else { return }
        do {
            try await connectionManager.connect(config: config, session: session)
            _ = try await connectionManager.ensureSession(session: session, config: config)
            
            if #available(iOS 18.0, *) {
                try await connectionManager.attachToSession(
                    session: session,
                    cols: terminalSize.cols,
                    rows: terminalSize.rows
                ) { [weak coordinator] data in
                    DispatchQueue.main.async {
                        coordinator?.feedData(data)
                    }
                }
            }
        } catch {
            print("Connection error: \(error)")
        }
    }
    
    private func restartSession() async {
        guard let config = serverConfig else { return }
        await connectionManager.disconnect()
        do {
            try await connectionManager.connect(config: config, session: session)
            let launchCommand = "~/AgentOS/launch-agent.sh '\(session.tmuxSessionName)' '\(session.projectPath)' '\(session.agentType.rawValue)' 'restart'"
            _ = try await connectionManager.ensureSession(session: session, config: config)
        } catch {
            print("Restart error: \(error)")
        }
    }
}

struct ConnectionStatusBar: View {
    let state: SSHConnectionManager.ConnectionState
    let error: String?
    
    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
    }
    
    private var statusColor: SwiftUI.Color {
        switch state {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .gray
        case .error: return .red
        }
    }
    
    private var statusText: String {
        switch state {
        case .connected: return "Connected"
        case .connecting: return "Connecting..."
        case .disconnected: return "Disconnected"
        case .error: return error ?? "Error"
        }
    }
}

struct SwiftTermView: UIViewRepresentable {
    @ObservedObject var connectionManager: SSHConnectionManager
    let session: AgentSession
    let size: CGSize
    var onCoordinatorCreated: ((Coordinator) -> Void)?
    var onSizeChanged: ((Int, Int) -> Void)?
    
    func makeUIView(context: Context) -> TerminalView {
        let terminal = TerminalView()
        terminal.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
        terminal.font = UIFont(name: "Menlo", size: 14) ?? UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        terminal.terminalDelegate = context.coordinator
        
        context.coordinator.terminalView = terminal
        onCoordinatorCreated?(context.coordinator)
        
        return terminal
    }
    
    func updateUIView(_ uiView: TerminalView, context: Context) {
        let cols = Int(size.width / 8)
        let rows = Int(size.height / 16)
        if cols > 0 && rows > 0 {
            uiView.resize(cols: cols, rows: rows)
            onSizeChanged?(cols, rows)
            Task {
                try? await connectionManager.sendResize(cols: cols, rows: rows)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(connectionManager: connectionManager)
    }
    
    class Coordinator: NSObject, TerminalViewDelegate {
        var terminalView: TerminalView?
        let connectionManager: SSHConnectionManager
        
        init(connectionManager: SSHConnectionManager) {
            self.connectionManager = connectionManager
        }
        
        func feedData(_ data: Data) {
            let bytes = ArraySlice([UInt8](data))
            terminalView?.feed(byteArray: bytes)
        }
        
        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            Task {
                try? await connectionManager.send(data: Data(data))
            }
        }
        
        func scrolled(source: TerminalView, position: Double) {}
        func setTerminalTitle(source: TerminalView, title: String) {}
        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            Task {
                try? await connectionManager.sendResize(cols: newCols, rows: newRows)
            }
        }
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func requestOpenLink(source: TerminalView, link: String, params: [String : String]) {}
        func bell(source: TerminalView) {}
        func clipboardCopy(source: TerminalView, content: Data) {
            if let text = String(data: content, encoding: .utf8) {
                UIPasteboard.general.string = text
            }
        }
        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
    }
}
