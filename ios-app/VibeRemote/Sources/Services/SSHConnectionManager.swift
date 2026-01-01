import Foundation
import Citadel
import Crypto
import NIO
import NIOSSH
import os.log

private let logger = Logger(subsystem: "com.vibeRemote.app", category: "SSH")

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
            logger.info("Connecting to \(config.host):\(config.port) as \(config.username)")
            
            let privateKeyData = try KeychainManager.shared.getPrivateKey(label: config.sshKeyLabel)
            logger.info("Private key loaded: \(privateKeyData.count) bytes")
            
            let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData)
            logger.info("Private key parsed successfully")
            
            logger.info("Attempting connection...")
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
            
            logger.info("Connected successfully!")
            connectionState = .connected
        } catch {
            let fullError = """
            Type: \(type(of: error))
            Description: \(error.localizedDescription)
            Debug: \(String(describing: error))
            """
            logger.error("Connection failed: \(fullError)")
            connectionState = .error
            lastError = fullError
            throw error
        }
    }
    
    func executeCommand(_ command: String) async throws -> String {
        guard let client = sshClient else {
            throw ConnectionError.notConnected
        }
        let result = try await client.executeCommand(command)
        return String(buffer: result)
    }
    
    func listDirectories(path: String = "~/") async throws -> [String] {
        let sanitizedPath = path.replacingOccurrences(of: "'", with: "'\\''")
        let command = "ls -1d '\(sanitizedPath)'*/ 2>/dev/null | xargs -n1 basename"
        let output = try await executeCommand(command)
        return output.components(separatedBy: "\n").filter { !$0.isEmpty }
    }
    
    func listOpencodeSessions(forDirectory directory: String) async throws -> [[String: Any]] {
        let homeDir = try await executeCommand("echo $HOME").trimmingCharacters(in: .whitespacesAndNewlines)
        let command = "~/.opencode/bin/opencode session list --format json 2>/dev/null"
        let output = try await executeCommand(command)
        
        guard let data = output.data(using: .utf8),
              let sessions = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        
        let expandedDir = directory.replacingOccurrences(of: "~/", with: "\(homeDir)/")
        return sessions.filter { session in
            guard let dir = session["directory"] as? String else { return false }
            return dir == expandedDir || dir.hasPrefix(expandedDir)
        }
    }
    
    func getOpencodeSession(id: String) async throws -> (title: String, updated: Date)? {
        let command = "~/.opencode/bin/opencode session list --format json 2>/dev/null"
        let output = try await executeCommand(command)
        
        guard let data = output.data(using: .utf8),
              let sessions = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }
        
        guard let session = sessions.first(where: { ($0["id"] as? String) == id }),
              let title = session["title"] as? String,
              let updated = session["updated"] as? Double else {
            return nil
        }
        
        return (title: title, updated: Date(timeIntervalSince1970: updated / 1000))
    }
    
    func listTmuxSessions() async throws -> [String] {
        let command = "tmux list-sessions -F '#{session_name}' 2>/dev/null || echo ''"
        let output = try await executeCommand(command)
        return output.components(separatedBy: "\n").filter { !$0.isEmpty }
    }
    
    func killTmuxSession(name: String) async throws {
        let sanitizedName = name.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        _ = try await executeCommand("tmux kill-session -t '\(sanitizedName)' 2>/dev/null || true")
    }
    
    func ensureSession(session: AgentSession, config: ServerConfig, action: String = "start") async throws -> String {
        let sanitizedPath = session.projectPath.replacingOccurrences(of: "'", with: "'\\''")
        let opencodeSessionArg = session.opencodeSessionId ?? ""
        let launchCommand = "~/AgentOS/launch-agent.sh '\(session.tmuxSessionName)' '\(sanitizedPath)' '\(session.agentType.rawValue)' '\(action)' '\(opencodeSessionArg)'"
        
        return try await executeCommand(launchCommand)
    }
    
    @available(iOS 18.0, macOS 15.0, *)
    func attachToSession(session: AgentSession, cols: Int, rows: Int, onData: @escaping @Sendable (Data) -> Void) async throws {
        guard let client = sshClient else {
            throw ConnectionError.notConnected
        }
        
        let attachCommand = "tmux attach -t '\(session.tmuxSessionName)'"
        
        let ptyRequest = SSHChannelRequestEvent.PseudoTerminalRequest(
            wantReply: true,
            term: "xterm-256color",
            terminalCharacterWidth: cols,
            terminalRowHeight: rows,
            terminalPixelWidth: 0,
            terminalPixelHeight: 0,
            terminalModes: SSHTerminalModes([:])
        )
        
        outputTask = Task { [weak self] in
            do {
                try await client.withPTY(ptyRequest) { inbound, outbound in
                    await MainActor.run {
                        self?.stdinWriter = outbound
                    }
                    
                    var commandBuffer = ByteBuffer()
                    commandBuffer.writeString(attachCommand + "\n")
                    try await outbound.write(commandBuffer)
                    
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
