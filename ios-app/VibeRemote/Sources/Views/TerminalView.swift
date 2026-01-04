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
    @State private var terminalSize: (cols: Int, rows: Int)? = nil
    @State private var coordinator: SwiftTermView.Coordinator?
    @State private var shouldConnect = false
    @State private var showSessionMenu = false
    @State private var showScrollControls = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var serverConfig: ServerConfig? {
        configs.first
    }
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                SwiftTermView(
                    connectionManager: connectionManager,
                    session: session,
                    onCoordinatorCreated: { coord in
                        logger.info("[TerminalView] Coordinator created")
                        self.coordinator = coord
                        self.shouldConnect = true
                    },
                    onSizeChanged: { cols, rows in
                        self.terminalSize = (cols, rows)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                ImmersiveStatusPill(
                    sessionName: session.name,
                    connectionState: connectionManager.connectionState,
                    onMenu: {
                        showSessionMenu = true
                    },
                    onScrollToggle: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showScrollControls.toggle()
                        }
                    },
                    showScrollControls: showScrollControls
                )
                
                if showScrollControls {
                    ScrollControlsView(
                        onScrollUp: { scrollTerminal(direction: .up, lines: 3) },
                        onScrollDown: { scrollTerminal(direction: .down, lines: 3) },
                        onPageUp: { scrollTerminal(direction: .up, lines: 10) },
                        onPageDown: { scrollTerminal(direction: .down, lines: 10) }
                    )
                }
            }
            .simultaneousGesture(edgeSwipeGesture(geometry: geometry))
        }
        .background(OpenCodeTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .statusBarHidden(!isIPad)
        .confirmationDialog("Session Actions", isPresented: $showSessionMenu, titleVisibility: .visible) {
            Button("Restart Agent") {
                Task { await restartSession() }
            }
            Button("Disconnect") {
                Task { await connectionManager.disconnect() }
            }
            Button("Kill Session", role: .destructive) {
                Task { await killSession() }
            }
            Button("Cancel", role: .cancel) { }
        }
        .onChange(of: shouldConnect) { _, newValue in
            if newValue {
                Task {
                    await connectToSession()
                }
            }
        }
    }
    
    private func scrollTerminal(direction: ScrollDirection, lines: Int) {
        coordinator?.sendScrollEvent(direction: direction, lines: lines)
    }
    
    private func edgeSwipeGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let startX = value.startLocation.x
                let endX = value.location.x
                let threshold: CGFloat = 50
                let edgeWidth: CGFloat = 30
                
                let isRightEdgeSwipe = startX > geometry.size.width - edgeWidth && startX - endX > threshold
                if isRightEdgeSwipe {
                    showSessionMenu = true
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
            
            // Wait for SwiftTerm to calculate actual size, or use defaults
            let cols = terminalSize?.cols ?? 80
            let rows = terminalSize?.rows ?? 24
            
            logger.info("[TerminalView] Attaching to PTY with size \(cols)x\(rows)")
            if #available(iOS 18.0, *) {
                try await connectionManager.attachToSession(
                    session: session,
                    cols: cols,
                    rows: rows
                ) { [coord] data in
                    logger.info("[TerminalView] Received \(data.count) bytes")
                    DispatchQueue.main.async { [coord] in
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
            
            let cols = terminalSize?.cols ?? 80
            let rows = terminalSize?.rows ?? 24
            
            if #available(iOS 18.0, *) {
                try await connectionManager.attachToSession(
                    session: session,
                    cols: cols,
                    rows: rows
                ) { [weak coordinator] data in
                    DispatchQueue.main.async { [weak coordinator] in
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

// MARK: - Immersive Status Pill

struct ImmersiveStatusPill: View {
    let sessionName: String
    let connectionState: SSHConnectionManager.ConnectionState
    let onMenu: () -> Void
    let onScrollToggle: () -> Void
    let showScrollControls: Bool
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OpenCodeTheme.text)
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                
                Text(sessionName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OpenCodeTheme.text)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: onScrollToggle) {
                Image(systemName: showScrollControls ? "arrow.up.arrow.down.circle.fill" : "arrow.up.arrow.down.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(showScrollControls ? OpenCodeTheme.primary : OpenCodeTheme.text)
            }
            
            Button(action: onMenu) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OpenCodeTheme.text)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial.opacity(0.8), in: Capsule())
        .padding(.horizontal, 40)
        .padding(.top, 8)
    }
    
    private var statusColor: SwiftUI.Color {
        switch connectionState {
        case .connected: return OpenCodeTheme.connected
        case .connecting: return OpenCodeTheme.connecting
        case .disconnected: return OpenCodeTheme.disconnected
        case .error: return OpenCodeTheme.connectionError
        }
    }
}

// MARK: - Scroll Controls View

struct ScrollControlsView: View {
    let onScrollUp: () -> Void
    let onScrollDown: () -> Void
    let onPageUp: () -> Void
    let onPageDown: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    Button(action: onPageUp) {
                        Image(systemName: "chevron.up.2")
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: 44, height: 36)
                    }
                    
                    Button(action: onScrollUp) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    
                    Button(action: onScrollDown) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    
                    Button(action: onPageDown) {
                        Image(systemName: "chevron.down.2")
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: 44, height: 36)
                    }
                }
                .foregroundStyle(OpenCodeTheme.text.opacity(0.7))
                .background(.ultraThinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                .padding(.trailing, 8)
            }
            Spacer()
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }
}

// MARK: - SwiftTerm UIViewRepresentable

struct SwiftTermView: UIViewRepresentable {
    @ObservedObject var connectionManager: SSHConnectionManager
    let session: AgentSession
    var onCoordinatorCreated: ((Coordinator) -> Void)?
    var onSizeChanged: ((Int, Int) -> Void)?
    
    func makeUIView(context: Context) -> ScrollableTerminalContainer {
        let container = ScrollableTerminalContainer()
        container.backgroundColor = OpenCodeTheme.terminalBackground
        
        let terminal = container.terminalView
        terminal.backgroundColor = OpenCodeTheme.terminalBackground
        terminal.font = UIFont(name: "Menlo", size: 14) ?? UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        terminal.terminalDelegate = context.coordinator
        
        context.coordinator.terminalView = terminal
        context.coordinator.onSizeChanged = onSizeChanged
        let coord = context.coordinator
        container.onScroll = { [weak coord] direction, lines in
            coord?.sendScrollEvent(direction: direction, lines: lines)
        }
        onCoordinatorCreated?(context.coordinator)
        
        return container
    }
    
    func updateUIView(_ uiView: ScrollableTerminalContainer, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(connectionManager: connectionManager)
    }
    
    class Coordinator: NSObject, TerminalViewDelegate {
        var terminalView: TerminalView?
        let connectionManager: SSHConnectionManager
        var onSizeChanged: ((Int, Int) -> Void)?
        
        init(connectionManager: SSHConnectionManager) {
            self.connectionManager = connectionManager
        }
        
        func feedData(_ data: Data) {
            logger.info("[Coordinator] feedData called with \(data.count) bytes")
            let bytes = ArraySlice([UInt8](data))
            terminalView?.feed(byteArray: bytes)
            if let text = String(data: data, encoding: .utf8) {
                logger.debug("[Coordinator] Data content: \(text.prefix(200))")
            }
        }
        
        func sendScrollEvent(direction: ScrollDirection, lines: Int) {
            guard terminalView != nil else { return }
            
            let pageKey: [UInt8] = direction == .up
                ? [0x1b, 0x5b, 0x35, 0x7e]  // Page Up: ESC [ 5 ~
                : [0x1b, 0x5b, 0x36, 0x7e]  // Page Down: ESC [ 6 ~
            
            Task {
                try? await connectionManager.send(data: Data(pageKey))
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
            logger.info("[Coordinator] SwiftTerm auto-sized to \(newCols)x\(newRows)")
            onSizeChanged?(newCols, newRows)
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

// MARK: - Scroll Direction

enum ScrollDirection {
    case up
    case down
}

// MARK: - Scrollable Terminal Container

class ScrollableTerminalContainer: UIView {
    let terminalView: TerminalView
    private let scrollOverlay: TwoFingerScrollOverlay
    var onScroll: ((ScrollDirection, Int) -> Void)? {
        didSet { scrollOverlay.onScroll = onScroll }
    }
    
    override init(frame: CGRect) {
        terminalView = TerminalView()
        scrollOverlay = TwoFingerScrollOverlay()
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        terminalView = TerminalView()
        scrollOverlay = TwoFingerScrollOverlay()
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        terminalView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(terminalView)
        
        scrollOverlay.translatesAutoresizingMaskIntoConstraints = false
        scrollOverlay.backgroundColor = .clear
        scrollOverlay.isUserInteractionEnabled = true
        addSubview(scrollOverlay)
        
        NSLayoutConstraint.activate([
            terminalView.topAnchor.constraint(equalTo: topAnchor),
            terminalView.bottomAnchor.constraint(equalTo: bottomAnchor),
            terminalView.leadingAnchor.constraint(equalTo: leadingAnchor),
            terminalView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            scrollOverlay.topAnchor.constraint(equalTo: topAnchor),
            scrollOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollOverlay.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
}

class TwoFingerScrollOverlay: UIView {
    var onScroll: ((ScrollDirection, Int) -> Void)?
    
    private var activeTouches: Set<UITouch> = []
    private var isTracking = false
    private var lastY: CGFloat = 0
    private var accumulatedDelta: CGFloat = 0
    private let scrollThreshold: CGFloat = 40
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let touchCount = event?.allTouches?.filter { $0.phase != .ended && $0.phase != .cancelled }.count ?? 0
        if touchCount >= 2 || isTracking {
            return self
        }
        return nil
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.formUnion(touches)
        
        if activeTouches.count >= 2 && !isTracking {
            isTracking = true
            accumulatedDelta = 0
            if let touch = touches.first {
                lastY = touch.location(in: self).y
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isTracking, let touch = touches.first else { return }
        
        let currentY = touch.location(in: self).y
        let deltaY = currentY - lastY
        lastY = currentY
        
        accumulatedDelta += deltaY
        
        if abs(accumulatedDelta) >= scrollThreshold {
            let direction: ScrollDirection = accumulatedDelta < 0 ? .up : .down
            onScroll?(direction, 1)
            accumulatedDelta = 0
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.subtract(touches)
        
        if activeTouches.count < 2 {
            isTracking = false
            accumulatedDelta = 0
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.subtract(touches)
        isTracking = false
        accumulatedDelta = 0
    }
}
