import Foundation
import Citadel
import Crypto
import NIO
import NIOSSH

@MainActor
class SSHConnectionManager: ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var lastError: String?
    
    private var sshClient: SSHClient?
    private var stdinWriter: TTYStdinWriter?
    private var outputTask: Task<Void, Never>?
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case error
    }
    
    func connect(config: ServerConfig, session: AgentSession) async throws {
        guard config.isConfigured else {
            throw ConnectionError.notConfigured
        }
        
        connectionState = .connecting
        lastError = nil
        
        do {
            let privateKeyData = try KeychainManager.shared.getPrivateKey(label: config.sshKeyLabel)
            let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData)
            
            sshClient = try await SSHClient.connect(
                host: config.host,
                port: config.port,
                authenticationMethod: .ed25519(
                    username: config.username,
                    privateKey: privateKey
                ),
                hostKeyValidator: .acceptAnything(),
                reconnect: .never
            )
            
            connectionState = .connected
        } catch {
            connectionState = .error
            lastError = error.localizedDescription
            throw error
        }
    }
    
    func ensureSession(session: AgentSession, config: ServerConfig) async throws -> String {
        guard let client = sshClient else {
            throw ConnectionError.notConnected
        }
        
        let launchCommand = "~/AgentOS/launch-agent.sh '\(session.tmuxSessionName)' '\(session.projectPath)' '\(session.agentType.rawValue)' 'start'"
        
        let result = try await client.executeCommand(launchCommand)
        return String(buffer: result)
    }
    
    @available(iOS 18.0, macOS 15.0, *)
    func attachToSession(session: AgentSession, cols: Int, rows: Int, onData: @escaping @Sendable (Data) -> Void) async throws {
        guard let client = sshClient else {
            throw ConnectionError.notConnected
        }
        
        let attachCommand = "tmux attach -t '\(session.tmuxSessionName)'"
        
        // Create PTY request with terminal size
        let ptyRequest = SSHChannelRequestEvent.PseudoTerminalRequest(
            wantReply: true,
            term: "xterm-256color",
            terminalCharacterWidth: cols,
            terminalRowHeight: rows,
            terminalPixelWidth: 0,
            terminalPixelHeight: 0,
            terminalModes: SSHTerminalModes([:])
        )
        
        // Start PTY session in background task
        outputTask = Task { [weak self] in
            do {
                try await client.withPTY(ptyRequest) { inbound, outbound in
                    // Store writer for sending data
                    await MainActor.run {
                        self?.stdinWriter = outbound
                    }
                    
                    // Send the attach command
                    var commandBuffer = ByteBuffer()
                    commandBuffer.writeString(attachCommand + "\n")
                    try await outbound.write(commandBuffer)
                    
                    // Read output and forward to callback
                    for try await output in inbound {
                        switch output {
                        case .stdout(let buffer), .stderr(let buffer):
                            if let data = buffer.getData(at: buffer.readerIndex, length: buffer.readableBytes) {
                                onData(data)
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self?.connectionState = .error
                    self?.lastError = error.localizedDescription
                }
            }
        }
    }
    
    func send(data: Data) async throws {
        guard let writer = stdinWriter else {
            throw ConnectionError.notConnected
        }
        
        var buffer = ByteBuffer()
        buffer.writeBytes(data)
        try await writer.write(buffer)
    }
    
    func sendResize(cols: Int, rows: Int) async throws {
        guard let writer = stdinWriter else { return }
        
        try await writer.changeSize(
            cols: cols,
            rows: rows,
            pixelWidth: 0,
            pixelHeight: 0
        )
    }
    
    func disconnect() async {
        outputTask?.cancel()
        outputTask = nil
        stdinWriter = nil
        try? await sshClient?.close()
        sshClient = nil
        connectionState = .disconnected
    }
}

enum ConnectionError: LocalizedError {
    case notConfigured
    case notConnected
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Server not configured. Please add your Mac mini details in Settings."
        case .notConnected: return "Not connected to server."
        case .authenticationFailed: return "SSH authentication failed. Check your key configuration."
        }
    }
}
