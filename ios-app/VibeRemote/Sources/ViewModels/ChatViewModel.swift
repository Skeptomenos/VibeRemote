import SwiftUI
import Combine
import os.log

private let logger = Logger(subsystem: "com.vibeRemote.app", category: "ChatViewModel")

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)
    
    var isError: Bool {
        if case .error = self { return true }
        return false
    }
    
    static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected): return true
        case (.connecting, .connecting): return true
        case (.connected, .connected): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var messages: [OpenCodeMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var connectionState: ConnectionState = .disconnected
    
    @Published var providers: [Provider] = []
    @Published var selectedProvider: String?
    @Published var selectedModel: String?
    
    @Published var commands: [SlashCommand] = []
    @Published var todos: [TodoItem] = []
    @Published var diffs: [FileDiff] = []
    @Published var mcpStatus: [String: MCPStatus] = [:]
    @Published var lspStatus: [LSPStatus] = []
    
    @Published var sessionStats: SessionStats?
    @Published var sessionCost: SessionCost?
    
    // MARK: - Private Properties
    
    private let session: AgentSession
    private let gatewayURL: URL
    private let apiKey: String
    private var openCodeClient: OpenCodeClient?
    private var eventTask: Task<Void, Never>?
    private var openCodeSessionId: String?
    
    // MARK: - Initialization
    
    init(session: AgentSession, gatewayURL: URL, apiKey: String) {
        self.session = session
        self.gatewayURL = gatewayURL
        self.apiKey = apiKey
    }
    
    deinit {
        eventTask?.cancel()
    }
    
    // MARK: - Connection Management
    
    func connect() async {
        guard connectionState == .disconnected || connectionState.isError else { return }
        
        connectionState = .connecting
        
        do {
            // First, ensure OpenCode is running for this project via the gateway
            let gatewayClient = GatewayClient(baseURL: gatewayURL, apiKey: apiKey)
            logger.info("Starting OpenCode for project: \(self.session.projectName)")
            
            do {
                let startResult = try await gatewayClient.startProject(session.projectName)
                logger.info("OpenCode started/running on port \(startResult.port), status: \(startResult.status)")
            } catch GatewayError.projectNotFound(let name) {
                connectionState = .error("Project '\(name)' not found on server")
                return
            } catch {
                logger.warning("Failed to start project, will try connecting anyway: \(error.localizedDescription)")
            }
            
            // Build the OpenCode API URL through the gateway
            let apiURL = gatewayURL.appendingPathComponent("projects/\(session.projectName)/api")
            openCodeClient = OpenCodeClient(baseURL: apiURL, apiKey: apiKey)
            
            guard let client = openCodeClient else {
                connectionState = .error("Failed to create client")
                return
            }
            
            // Health check with retry
            var healthy = false
            for attempt in 1...3 {
                healthy = try await client.healthCheck()
                if healthy { break }
                logger.info("Health check attempt \(attempt) failed, retrying...")
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
            
            guard healthy else {
                connectionState = .error("OpenCode not responding after start")
                return
            }
            
            // Get or create session
            // IMPORTANT: Only use an existing session if the user explicitly selected one.
            // If opencodeSessionId is nil, ALWAYS create a new session - don't fall back to first.
            let sessions = try await client.listSessions()
            
            if let existingId = session.opencodeSessionId,
               let existing = sessions.first(where: { $0.id == existingId }) {
                // User explicitly selected an existing session - use it
                openCodeSessionId = existing.id
                sessionStats = existing.stats
                sessionCost = existing.cost
                logger.info("Using existing OpenCode session: \(existing.id) - \(existing.title)")
            } else {
                logger.info("Creating new OpenCode session for: \(self.session.name)")
                let newSession = try await client.createSession(title: session.name)
                openCodeSessionId = newSession.id
                
                session.opencodeSessionId = newSession.id
                session.opencodeSessionTitle = newSession.title
                logger.info("Created and persisted new OpenCode session: \(newSession.id)")
            }
            
            // Load initial data in parallel
            async let messagesTask: () = loadMessages()
            async let providersTask: () = loadProviders()
            async let commandsTask: () = loadCommands()
            
            _ = await (messagesTask, providersTask, commandsTask)
            
            // Subscribe to SSE events
            print("[ChatVM] About to subscribe to SSE events")
            subscribeToEvents()
            
            connectionState = .connected
            print("[ChatVM] Connected to OpenCode session: \(self.openCodeSessionId ?? "unknown")")
            
        } catch {
            logger.error("Connection failed: \(error.localizedDescription)")
            connectionState = .error(error.localizedDescription)
        }
    }
    
    func disconnect() {
        eventTask?.cancel()
        eventTask = nil
        Task { await openCodeClient?.disconnect() }
        connectionState = .disconnected
    }
    
    // MARK: - Message Operations
    
    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let sessionId = openCodeSessionId, let client = openCodeClient else { return }
        
        inputText = ""
        isLoading = true
        
        let optimisticMessage = OpenCodeMessage(
            info: MessageInfo(
                id: "pending-\(UUID().uuidString)",
                sessionID: sessionId,
                role: .user,
                time: MessageTime(created: Date().timeIntervalSince1970, completed: Date().timeIntervalSince1970),
                model: nil,
                cost: nil,
                tokens: nil,
                agent: nil,
                parentID: nil,
                modelID: nil,
                providerID: nil,
                mode: nil,
                path: nil,
                error: nil,
                summary: nil
            ),
            parts: [.text(TextPart(type: "text", text: text))]
        )
        messages.append(optimisticMessage)
        
        do {
            logger.info("[sendMessage] Sending with provider='\(self.selectedProvider ?? "nil")', model='\(self.selectedModel ?? "nil")'")
            try await client.sendMessageAsync(
                sessionId: sessionId,
                text: text,
                providerID: selectedProvider,
                modelID: selectedModel
            )
        } catch {
            logger.error("Failed to send message: \(error.localizedDescription)")
            messages.removeAll { $0.id == optimisticMessage.id }
            isLoading = false
        }
    }
    
    func deleteMessage(_ messageId: String) async {
        guard let sessionId = openCodeSessionId, let client = openCodeClient else { return }
        
        do {
            try await client.deleteMessage(sessionId: sessionId, messageId: messageId)
            messages.removeAll { $0.id == messageId }
        } catch {
            logger.error("Failed to delete message: \(error.localizedDescription)")
        }
    }
    
    func abort() async {
        guard let sessionId = openCodeSessionId, let client = openCodeClient else { return }
        
        do {
            try await client.abort(sessionId: sessionId)
            isLoading = false
        } catch {
            logger.error("Failed to abort: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Data Loading
    
    private func loadMessages() async {
        guard let sessionId = openCodeSessionId, let client = openCodeClient else { return }
        
        do {
            messages = try await client.getMessages(sessionId: sessionId)
        } catch {
            logger.error("Failed to load messages: \(error.localizedDescription)")
        }
    }
    
    private func loadProviders() async {
        await refreshProviders()
    }
    
    func refreshProviders() async {
        guard let client = openCodeClient else { return }
        
        do {
            let response = try await client.getProviders()
            providers = response.providers
            
            logger.info("[loadProviders] Loaded \(response.providers.count) providers")
            for provider in response.providers {
                logger.info("[loadProviders]   Provider: id='\(provider.id)', name='\(provider.name)', models=\(provider.models.count)")
                for model in provider.models {
                    logger.info("[loadProviders]     Model: id='\(model.id)', name='\(model.name)'")
                }
            }
            
            // Only set defaults if not already selected
            if selectedProvider == nil || selectedModel == nil {
                if let defaultProvider = session.defaultProviderID,
                   let defaultModel = session.defaultModelID,
                   providers.contains(where: { $0.id == defaultProvider && $0.models.contains(where: { $0.id == defaultModel }) }) {
                    self.selectedProvider = defaultProvider
                    self.selectedModel = defaultModel
                    logger.info("[loadProviders] Using session defaults: provider='\(defaultProvider)', model='\(defaultModel)'")
                } else if let defaults = response.default {
                    self.selectedProvider = defaults["provider"]
                    self.selectedModel = defaults["model"]
                    logger.info("[loadProviders] Using API defaults: provider='\(self.selectedProvider ?? "nil")', model='\(self.selectedModel ?? "nil")'")
                } else if let firstProvider = providers.first,
                          let firstModel = firstProvider.models.first {
                    self.selectedProvider = firstProvider.id
                    self.selectedModel = firstModel.id
                    logger.info("[loadProviders] Using first available: provider='\(self.selectedProvider ?? "nil")', model='\(self.selectedModel ?? "nil")'")
                } else {
                    logger.warning("[loadProviders] No providers or models available!")
                }
            }
        } catch {
            logger.error("Failed to load providers: \(error.localizedDescription)")
        }
    }
    
    private func loadCommands() async {
        guard let client = openCodeClient else { return }
        
        do {
            commands = try await client.listCommands()
        } catch {
            logger.error("Failed to load commands: \(error.localizedDescription)")
        }
    }
    
    func refreshStatus() async {
        guard let sessionId = openCodeSessionId, let client = openCodeClient else { return }
        
        do {
            async let todosTask = client.getTodos(sessionId: sessionId)
            async let diffsTask = client.getDiffs(sessionId: sessionId)
            async let mcpTask = client.getMCPStatus()
            async let lspTask = client.getLSPStatus()
            
            todos = try await todosTask
            diffs = try await diffsTask
            mcpStatus = try await mcpTask
            lspStatus = try await lspTask
        } catch {
            logger.error("Failed to refresh status: \(error.localizedDescription)")
        }
    }
    
    // MARK: - SSE Event Handling
    
    private func subscribeToEvents() {
        guard let client = openCodeClient else {
            print("[ChatVM] SSE: No client available for event subscription")
            return
        }
        
        eventTask?.cancel()
        eventTask = Task {
            print("[ChatVM] SSE: Starting event subscription")
            let stream = await client.subscribeToEvents()
            
            for await event in stream {
                if Task.isCancelled {
                    logger.info("SSE: Task cancelled, stopping event loop")
                    break
                }
                await handleEvent(event)
            }
            logger.info("SSE: Event stream ended")
        }
    }
    
    private func handleEvent(_ event: ServerEvent) async {
        switch event {
        case .messageUpdated(let message):
            logger.info("SSE: message.updated - id=\(message.id), role=\(message.info.role.rawValue)")
            
            if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                let existingParts = self.messages[index].parts
                let updatedMessage = OpenCodeMessage(info: message.info, parts: existingParts)
                self.messages[index] = updatedMessage
                logger.info("SSE: Updated existing message in-place")
            } else {
                if message.info.role == .user {
                    self.messages.removeAll { $0.id.hasPrefix("pending-") && $0.info.role == .user }
                    logger.info("SSE: Removed pending user message")
                }
                let newMessage = OpenCodeMessage(info: message.info, parts: nil)
                self.messages.append(newMessage)
                logger.info("SSE: Added new message")
            }
            
            if message.info.role == .assistant && message.info.time.completed != nil {
                self.isLoading = false
            }
            
        case .partUpdated(let messageId, let part):
            logger.info("SSE: part.updated - messageId=\(messageId)")
            
            if messageId.isEmpty {
                logger.info("SSE: part.updated with empty messageId, ignoring (will get full update later)")
                return
            }
            
            if let index = self.messages.firstIndex(where: { $0.id == messageId }) {
                let existingMessage = self.messages[index]
                var existingParts = existingMessage.parts ?? []
                
                switch part {
                case .text(let textPart):
                    if let textIndex = existingParts.firstIndex(where: {
                        if case .text = $0 { return true }
                        return false
                    }) {
                        existingParts[textIndex] = part
                    } else {
                        existingParts.append(part)
                    }
                    logger.info("SSE: Updated text part for message \(messageId), text length: \(textPart.text.count)")
                    
                case .tool(let toolPart):
                    if let toolIndex = existingParts.firstIndex(where: {
                        if case .tool(let existing) = $0 {
                            return existing.callID == toolPart.callID
                        }
                        return false
                    }) {
                        existingParts[toolIndex] = part
                    } else {
                        existingParts.append(part)
                    }
                    logger.info("SSE: Updated tool part for message \(messageId), tool: \(toolPart.tool)")
                    
                case .toolInvocation(let invocationPart):
                    if let invIndex = existingParts.firstIndex(where: {
                        if case .toolInvocation(let existing) = $0 {
                            return existing.toolInvocation.toolCallId == invocationPart.toolInvocation.toolCallId
                        }
                        return false
                    }) {
                        existingParts[invIndex] = part
                    } else {
                        existingParts.append(part)
                    }
                    logger.info("SSE: Updated toolInvocation part for message \(messageId)")
                    
                default:
                    existingParts.append(part)
                    logger.info("SSE: Appended part to message \(messageId)")
                }
                
                let updatedMessage = OpenCodeMessage(info: existingMessage.info, parts: existingParts)
                self.messages[index] = updatedMessage
            } else {
                logger.info("SSE: Message \(messageId) not found, creating placeholder")
                let placeholderInfo = MessageInfo(
                    id: messageId,
                    sessionID: self.openCodeSessionId ?? "",
                    role: .assistant,
                    time: MessageTime(created: Date().timeIntervalSince1970, completed: nil),
                    model: nil,
                    cost: nil,
                    tokens: nil,
                    agent: nil,
                    parentID: nil,
                    modelID: nil,
                    providerID: nil,
                    mode: nil,
                    path: nil,
                    error: nil,
                    summary: nil
                )
                let newMessage = OpenCodeMessage(info: placeholderInfo, parts: [part])
                self.messages.append(newMessage)
            }
            
        case .sessionUpdated(let session):
            await MainActor.run {
                sessionStats = session.stats
                sessionCost = session.cost
            }
            
        case .messageRemoved(let messageId):
            await MainActor.run {
                messages.removeAll { $0.id == messageId }
            }
            
        case .connected:
            await MainActor.run {
                connectionState = .connected
            }
            
        case .lspDiagnostics:
            // Handle LSP diagnostics if needed
            break
            
        case .updateAvailable:
            // Handle update notification if needed
            break
            
        case .error(let error):
            logger.error("SSE error: \(error.localizedDescription)")
            isLoading = false
            
            let errorMessage = error.localizedDescription
            let isConnectionError = errorMessage.contains("Connection") || 
                                    errorMessage.contains("cancelled") ||
                                    errorMessage.contains("timeout")
            
            if isConnectionError {
                connectionState = .error("Connection lost")
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if !Task.isCancelled {
                    await connect()
                }
            }
        }
    }
    
    // MARK: - MCP Operations
    
    func connectMCP(name: String) async {
        guard let client = openCodeClient else { return }
        
        do {
            try await client.connectMCP(name: name)
            mcpStatus = try await client.getMCPStatus()
        } catch {
            logger.error("Failed to connect MCP: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Revert Operations
    
    func revertChanges() async {
        guard let sessionId = openCodeSessionId, let client = openCodeClient else { return }
        
        do {
            try await client.revert(sessionId: sessionId)
            diffs = []
        } catch {
            logger.error("Failed to revert: \(error.localizedDescription)")
        }
    }
    
    // MARK: - OpenCode Instance Management
    
    @Published var isRestarting: Bool = false
    
    func restartOpenCode() async {
        guard !isRestarting else { return }
        
        isRestarting = true
        connectionState = .connecting
        
        eventTask?.cancel()
        eventTask = nil
        
        let gatewayClient = GatewayClient(baseURL: gatewayURL, apiKey: apiKey)
        
        do {
            logger.info("Stopping OpenCode for project: \(self.session.projectName)")
            _ = try await gatewayClient.stopProject(session.projectName)
            
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            logger.info("Starting OpenCode for project: \(self.session.projectName)")
            let startResult = try await gatewayClient.startProject(session.projectName)
            logger.info("OpenCode restarted on port \(startResult.port), status: \(startResult.status)")
            
            try await Task.sleep(nanoseconds: 2_000_000_000)
            
            isRestarting = false
            await connect()
            
        } catch {
            logger.error("Failed to restart OpenCode: \(error.localizedDescription)")
            connectionState = .error("Restart failed: \(error.localizedDescription)")
            isRestarting = false
        }
    }
}
