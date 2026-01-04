import Foundation

// MARK: - Gateway Models

struct GatewayProject: Codable, Identifiable {
    let name: String
    let path: String
    let hasGit: Bool
    let hasPackageJson: Bool
    let isRunning: Bool
    let port: Int?
    
    var id: String { name }
    
    enum CodingKeys: String, CodingKey {
        case name, path, port
        case hasGit = "has_git"
        case hasPackageJson = "has_package_json"
        case isRunning = "is_running"
    }
}

struct GatewayStartResponse: Codable {
    let name: String
    let port: Int
    let status: String
}

struct GatewayStopResponse: Codable {
    let name: String
    let status: String
}

// MARK: - OpenCode Session

struct OpenCodeSession: Codable, Identifiable {
    let id: String
    let version: String
    let projectID: String
    let directory: String
    let title: String
    let time: SessionTime
    let summary: SessionSummary?
    let cost: SessionCost?
    let stats: SessionStats?
}

struct SessionTime: Codable {
    let created: TimeInterval
    let updated: TimeInterval
}

struct SessionSummary: Codable {
    let additions: Int?
    let deletions: Int?
    let files: Int?
}

struct SessionCost: Codable {
    let inputTokens: Int
    let outputTokens: Int
    let estimatedCost: Double
}

struct SessionStats: Codable {
    let messageCount: Int
    let filesModified: Int
    let executionTime: Double
}

// MARK: - Message

struct OpenCodeMessage: Codable, Identifiable {
    let id: String
    let sessionID: String
    let role: MessageRole
    let time: MessageTime
    let model: MessageModel?
    let cost: Double?
    let tokens: TokenUsage?
    let agent: String?
    let parentID: String?
    let modelID: String?
    let providerID: String?
    let mode: String?
    let path: MessagePath?
    let error: MessageError?
    let summary: MessageSummary?
    
    var parts: [MessagePart]?
    
    var effectiveModelID: String? { model?.modelID ?? modelID }
    var effectiveProviderID: String? { model?.providerID ?? providerID }
    
    var textContent: String {
        (parts ?? []).compactMap { part in
            if case .text(let textPart) = part {
                return textPart.text
            }
            return nil
        }.joined(separator: "\n")
    }
    
    var toolCalls: [ToolInvocationPart] {
        (parts ?? []).compactMap { part in
            if case .toolInvocation(let toolPart) = part {
                return toolPart
            }
            return nil
        }
    }
    
    var info: MessageInfo {
        MessageInfo(
            id: id,
            sessionID: sessionID,
            role: role,
            time: time,
            model: model,
            cost: cost,
            tokens: tokens,
            agent: agent,
            parentID: parentID,
            modelID: modelID,
            providerID: providerID,
            mode: mode,
            path: path,
            error: error,
            summary: summary
        )
    }
    
    init(
        id: String,
        sessionID: String,
        role: MessageRole,
        time: MessageTime,
        model: MessageModel? = nil,
        cost: Double? = nil,
        tokens: TokenUsage? = nil,
        agent: String? = nil,
        parentID: String? = nil,
        modelID: String? = nil,
        providerID: String? = nil,
        mode: String? = nil,
        path: MessagePath? = nil,
        error: MessageError? = nil,
        summary: MessageSummary? = nil,
        parts: [MessagePart]? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.role = role
        self.time = time
        self.model = model
        self.cost = cost
        self.tokens = tokens
        self.agent = agent
        self.parentID = parentID
        self.modelID = modelID
        self.providerID = providerID
        self.mode = mode
        self.path = path
        self.error = error
        self.summary = summary
        self.parts = parts
    }
    
    init(info: MessageInfo, parts: [MessagePart]? = nil) {
        self.id = info.id
        self.sessionID = info.sessionID
        self.role = info.role
        self.time = info.time
        self.model = info.model
        self.cost = info.cost
        self.tokens = info.tokens
        self.agent = info.agent
        self.parentID = info.parentID
        self.modelID = info.modelID
        self.providerID = info.providerID
        self.mode = info.mode
        self.path = info.path
        self.error = info.error
        self.summary = info.summary
        self.parts = parts
    }
}

struct MessageInfo: Codable {
    let id: String
    let sessionID: String
    let role: MessageRole
    let time: MessageTime
    let model: MessageModel?
    let cost: Double?
    let tokens: TokenUsage?
    let agent: String?
    let parentID: String?
    let modelID: String?
    let providerID: String?
    let mode: String?
    let path: MessagePath?
    let error: MessageError?
    let summary: MessageSummary?
    
    var effectiveModelID: String? { model?.modelID ?? modelID }
    var effectiveProviderID: String? { model?.providerID ?? providerID }
}

struct MessagePath: Codable {
    let cwd: String?
    let root: String?
}

struct MessageError: Codable {
    let name: String?
    let data: MessageErrorData?
}

struct MessageErrorData: Codable {
    let message: String?
}

struct MessageSummary: Codable {
    let title: String?
    let diffs: [AnyCodableValue]?
}

struct MessageModel: Codable {
    let providerID: String?
    let modelID: String?
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

struct MessageTime: Codable {
    let created: TimeInterval
    let completed: TimeInterval?
}

struct TokenUsage: Codable {
    let input: Int
    let output: Int
    let reasoning: Int?
    let cache: CacheUsage?
    
    var total: Int { input + output }
}

struct CacheUsage: Codable {
    let read: Int
    let write: Int
}



// MARK: - Message Response (from /session/{id}/message API)

struct MessageResponse: Codable {
    let info: MessageInfo
    let parts: [MessagePart]?
    
    func toOpenCodeMessage() -> OpenCodeMessage {
        OpenCodeMessage(info: info, parts: parts)
    }
}

// MARK: - Part Response (from /session/{id}/part API)

struct PartResponse: Codable {
    let id: String
    let sessionID: String
    let messageID: String
    let type: String
    let part: MessagePart
    
    enum CodingKeys: String, CodingKey {
        case id, sessionID, messageID, type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        sessionID = try container.decode(String.self, forKey: .sessionID)
        messageID = try container.decode(String.self, forKey: .messageID)
        type = try container.decode(String.self, forKey: .type)
        part = try MessagePart(from: decoder)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sessionID, forKey: .sessionID)
        try container.encode(messageID, forKey: .messageID)
        try container.encode(type, forKey: .type)
        try part.encode(to: encoder)
    }
}

// MARK: - Message Parts

enum MessagePart: Codable {
    case text(TextPart)
    case toolInvocation(ToolInvocationPart)
    case tool(ToolPart)  // API sends "tool" type with different structure
    case toolResult(ToolResultPart)
    case file(FilePart)
    case reasoning(ReasoningPart)
    case unknown
    
    enum CodingKeys: String, CodingKey {
        case type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "text":
            self = .text(try TextPart(from: decoder))
        case "tool-invocation":
            self = .toolInvocation(try ToolInvocationPart(from: decoder))
        case "tool":
            // API sends "tool" type with callID, tool, state fields
            self = .tool(try ToolPart(from: decoder))
        case "tool-result":
            self = .toolResult(try ToolResultPart(from: decoder))
        case "file":
            self = .file(try FilePart(from: decoder))
        case "reasoning":
            let reasoningPart = try ReasoningPart(from: decoder)
            print("[MessagePart] Decoded reasoning part with content length: \(reasoningPart.content.count)")
            self = .reasoning(reasoningPart)
        case "step-start", "step-finish":
            // Ignore step markers - they don't contain displayable content
            self = .unknown
        default:
            print("[MessagePart] Unknown part type: \(type)")
            self = .unknown
        }
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let part):
            try part.encode(to: encoder)
        case .toolInvocation(let part):
            try part.encode(to: encoder)
        case .tool(let part):
            try part.encode(to: encoder)
        case .toolResult(let part):
            try part.encode(to: encoder)
        case .file(let part):
            try part.encode(to: encoder)
        case .reasoning(let part):
            try part.encode(to: encoder)
        case .unknown:
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("unknown", forKey: .type)
        }
    }
}

struct TextPart: Codable {
    let type: String
    let text: String
}

struct ToolInvocationPart: Codable, Identifiable {
    let type: String
    let toolInvocation: ToolInvocation
    
    var id: String { toolInvocation.toolCallId ?? UUID().uuidString }
}

struct ToolInvocation: Codable {
    let toolName: String
    let toolCallId: String?
    let args: [String: AnyCodableValue]
    let state: String
    
    var displayName: String {
        switch toolName {
        case "read": return "Read"
        case "write": return "Write"
        case "edit": return "Edit"
        case "bash": return "Bash"
        case "glob": return "Glob"
        case "grep": return "Grep"
        case "task": return "Task"
        default: return toolName.capitalized
        }
    }
    
    var iconName: String {
        switch toolName {
        case "read": return "doc.text"
        case "write", "edit": return "pencil"
        case "bash": return "terminal"
        case "glob", "grep": return "magnifyingglass"
        case "task": return "checklist"
        default: return "wrench.and.screwdriver"
        }
    }
    
    var filePath: String? {
        args["filePath"]?.stringValue
    }
    
    var command: String? {
        args["command"]?.stringValue
    }
}

struct ToolResultPart: Codable {
    let type: String
    let toolResult: ToolResult
}

struct ToolResult: Codable {
    let result: String?
    let isError: Bool
}

struct FilePart: Codable {
    let type: String
    let filePath: String
    let content: String?
}

struct ReasoningPart: Codable {
    let type: String
    let text: String?
    let reasoning: String?
    let reasoningContent: String?
    
    /// The reasoning text content, checking multiple possible field names
    var content: String {
        text ?? reasoning ?? reasoningContent ?? ""
    }
    
    enum CodingKeys: String, CodingKey {
        case type, text, reasoning
        case reasoningContent = "reasoning_content"
    }
}

struct ToolPart: Codable, Identifiable {
    let type: String
    let callID: String?
    let tool: String
    let state: ToolState?
    
    var id: String { callID ?? UUID().uuidString }
    
    var displayName: String {
        switch tool {
        case "read": return "Read"
        case "write": return "Write"
        case "edit": return "Edit"
        case "bash": return "Bash"
        case "glob": return "Glob"
        case "grep": return "Grep"
        case "task": return "Task"
        case "todowrite": return "Todo"
        case "todoread": return "Todo"
        case "lsp_diagnostics": return "LSP Diagnostics"
        case "lsp_hover": return "LSP Hover"
        case "lsp_goto_definition": return "LSP Go To Definition"
        default: return tool.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
    
    var iconName: String {
        switch tool {
        case "read": return "doc.text"
        case "write", "edit": return "pencil"
        case "bash": return "terminal"
        case "glob", "grep": return "magnifyingglass"
        case "task": return "checklist"
        case "todowrite", "todoread": return "checklist"
        default:
            if tool.hasPrefix("lsp_") { return "chevron.left.forwardslash.chevron.right" }
            return "wrench.and.screwdriver"
        }
    }
}

struct ToolState: Codable {
    let status: String?
    let input: AnyCodableValue?
    let output: AnyCodableValue?
    let metadata: AnyCodableValue?
}

// MARK: - Providers

struct ProvidersResponse: Codable {
    let providers: [Provider]
    let `default`: [String: String]?
}

struct Provider: Codable, Identifiable {
    let id: String
    let name: String
    let models: [AIModel]
    
    enum CodingKeys: String, CodingKey {
        case id, name, models
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        
        let modelsDict = try container.decode([String: AIModelRaw].self, forKey: .models)
        models = modelsDict.map { key, raw in
            AIModel(id: key, name: raw.name, limit: raw.limit)
        }.sorted { $0.name < $1.name }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        // Convert array back to dictionary for encoding
        let modelsDict = Dictionary(uniqueKeysWithValues: models.map { ($0.id, $0) })
        try container.encode(modelsDict, forKey: .models)
    }
}

/// Raw model data from API (without id, since id is the dictionary key)
private struct AIModelRaw: Codable {
    let name: String
    let limit: ModelLimit?
}

struct AIModel: Codable, Identifiable {
    let id: String
    let name: String
    let limit: ModelLimit?
    
    var contextWindow: Int? { limit?.context }
    var maxOutput: Int? { limit?.output }
    
    var contextWindowFormatted: String? {
        guard let window = contextWindow else { return nil }
        if window >= 1_000_000 {
            return "\(window / 1_000_000)M"
        }
        return "\(window / 1000)K"
    }
}

struct ModelLimit: Codable {
    let context: Int?
    let output: Int?
}

// MARK: - Commands

struct SlashCommand: Codable, Identifiable {
    let name: String
    let description: String
    
    var id: String { name }
}

// MARK: - MCP

struct MCPStatus: Codable, Identifiable {
    let name: String
    let connectionStatus: String
    let tools: [String]?
    let error: String?
    
    var id: String { name }
    
    var isConnected: Bool {
        connectionStatus == "connected"
    }
}

// MARK: - LSP

struct LSPStatus: Codable, Identifiable {
    let name: String
    let status: String
    let version: String?
    let error: String?
    
    var id: String { name }
    
    var isRunning: Bool {
        status == "running"
    }
}

// MARK: - Todo

struct TodoItem: Codable, Identifiable {
    let id: String
    let content: String
    let status: String
    let priority: String
    
    var isCompleted: Bool {
        status == "completed"
    }
}

// MARK: - Diff

struct FileDiff: Codable, Identifiable {
    let file: String
    let diff: String
    
    var id: String { file }
    
    var fileName: String {
        URL(fileURLWithPath: file).lastPathComponent
    }
}

// MARK: - Agents

struct Agent: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
}

// MARK: - SSE Events

enum ServerEvent {
    case messageUpdated(OpenCodeMessage)
    case partUpdated(String, MessagePart)
    case sessionUpdated(OpenCodeSession)
    case messageRemoved(String)
    case lspDiagnostics([Diagnostic])
    case updateAvailable(String)
    case connected
    case error(Error)
}

struct Diagnostic: Codable {
    let file: String
    let line: Int
    let column: Int
    let severity: String
    let message: String
}

// MARK: - AnyCodableValue

struct AnyCodableValue: Codable {
    let value: Any
    
    var stringValue: String? {
        value as? String
    }
    
    var intValue: Int? {
        value as? Int
    }
    
    var boolValue: Bool? {
        value as? Bool
    }
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let dict = try? container.decode([String: AnyCodableValue].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodableValue].self) {
            value = array.map { $0.value }
        } else {
            value = ""
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else {
            try container.encodeNil()
        }
    }
}

// MARK: - Connection Mode

enum ConnectionMode: String, Codable, CaseIterable {
    case api = "api"
    case ssh = "ssh"
    
    var displayName: String {
        switch self {
        case .api: return "API (Native Chat)"
        case .ssh: return "SSH (Terminal)"
        }
    }
    
    var iconName: String {
        switch self {
        case .api: return "bubble.left.and.bubble.right"
        case .ssh: return "terminal"
        }
    }
}
