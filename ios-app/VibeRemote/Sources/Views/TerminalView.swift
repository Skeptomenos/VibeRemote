import SwiftUI
import SwiftData
import SwiftTerm
import os.log

private let logger = Logger(subsystem: "com.vibeRemote.app", category: "Terminal")

struct TerminalContainerView: View {
    let session: AgentSession
    let onSessionKilled: () -> Void
    @StateObject private var connectionManager = SSHConnectionManager()
    @Query private var configs: [ServerConfig]
    @State private var terminalSize: (cols: Int, rows: Int) = (80, 24)
    @State private var coordinator: SwiftTermView.Coordinator?
    @State private var shouldConnect = false
    
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
                        logger.info("[TerminalView] Coordinator created: \(String(describing: coord))")
                        self.coordinator = coord
                        self.shouldConnect = true
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
                    
                    Divider()
                    
                    Button("Disconnect", systemImage: "xmark.circle") {
                        Task { await connectionManager.disconnect() }
                    }
                    
                    Button("Kill Session", systemImage: "trash", role: .destructive) {
                        Task { await killSession() }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onChange(of: shouldConnect) { _, newValue in
            if newValue {
                Task {
                    await connectToSession()
                }
            }
        }
    }
    
    private func connectToSession() async {
        guard let config = serverConfig else {
            logger.error("[TerminalView] No server config found")
            return
        }
        guard let coord = coordinator else {
            logger.error("[TerminalView] No coordinator available")
            return
        }
        
        do {
            logger.info("[TerminalView] Connecting...")
            try await connectionManager.connect(config: config, session: session)
            
            logger.info("[TerminalView] Ensuring session exists...")
            let result = try await connectionManager.ensureSession(session: session, config: config)
            logger.info("[TerminalView] ensureSession result: \(result)")
            
            logger.info("[TerminalView] Attaching to PTY with coordinator: \(String(describing: coord))")
            if #available(iOS 18.0, *) {
                try await connectionManager.attachToSession(
                    session: session,
                    cols: max(terminalSize.cols, 80),
                    rows: max(terminalSize.rows, 24)
                ) { data in
                    logger.info("[TerminalView] Received \(data.count) bytes")
                    DispatchQueue.main.async {
                        coord.feedData(data)
                    }
                }
            } else {
                logger.warning("[TerminalView] iOS 18+ required for PTY")
            }
        } catch {
            logger.error("[TerminalView] Connection error: \(error)")
        }
    }
    
    private func restartSession() async {
        guard let config = serverConfig else { return }
        await connectionManager.disconnect()
        do {
            try await connectionManager.connect(config: config, session: session)
            _ = try await connectionManager.ensureSession(session: session, config: config, action: "restart")
            
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
            logger.error("[TerminalView] Restart error: \(error)")
        }
    }
    
    private func killSession() async {
        guard let config = serverConfig else { return }
        do {
            if connectionManager.connectionState != .connected {
                try await connectionManager.connect(config: config, session: session)
            }
            let result = try await connectionManager.ensureSession(session: session, config: config, action: "stop")
            logger.info("[TerminalView] Kill session result: \(result)")
            await connectionManager.disconnect()
            await MainActor.run {
                onSessionKilled()
            }
        } catch {
            logger.error("[TerminalView] Kill session error: \(error)")
            await connectionManager.disconnect()
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
            logger.info("[Coordinator] feedData called with \(data.count) bytes, terminalView: \(String(describing: self.terminalView))")
            let bytes = ArraySlice([UInt8](data))
            terminalView?.feed(byteArray: bytes)
            if let text = String(data: data, encoding: .utf8) {
                logger.debug("[Coordinator] Data content: \(text.prefix(200))")
            }
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
