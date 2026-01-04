import Foundation
import os.log

private let logger = Logger(subsystem: "com.vibeRemote.app", category: "OpenCodeClient")

actor OpenCodeClient {
    private let baseURL: URL
    private let apiKey: String
    private let session: URLSession
    private var eventTask: Task<Void, Never>?
    
    init(baseURL: URL, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120 
        config.timeoutIntervalForResource = 86400
        self.session = URLSession(configuration: config)
    }
    
    private func authorizedRequest(for url: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
    
    func healthCheck() async throws -> Bool {
        let url = baseURL.appendingPathComponent("global/health")
        let request = authorizedRequest(for: url)
        let (_, response) = try await session.data(for: request)
        return (response as? HTTPURLResponse)?.statusCode == 200
    }
    
    func listSessions() async throws -> [OpenCodeSession] {
        let url = baseURL.appendingPathComponent("session")
        let request = authorizedRequest(for: url)
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode([OpenCodeSession].self, from: data)
    }
    
    func getSession(id: String) async throws -> OpenCodeSession {
        let url = baseURL.appendingPathComponent("session/\(id)")
        let request = authorizedRequest(for: url)
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(OpenCodeSession.self, from: data)
    }
    
    func createSession(title: String) async throws -> OpenCodeSession {
        let url = baseURL.appendingPathComponent("session")
        var request = authorizedRequest(for: url, method: "POST")
        request.httpBody = try JSONEncoder().encode(["title": title])
        
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(OpenCodeSession.self, from: data)
    }
    
    func deleteSession(id: String) async throws {
        let url = baseURL.appendingPathComponent("session/\(id)")
        let request = authorizedRequest(for: url, method: "DELETE")
        _ = try await session.data(for: request)
    }
    
    func getMessages(sessionId: String) async throws -> [OpenCodeMessage] {
        let messages = try await fetchMessages(sessionId: sessionId)
        
        print("[OpenCodeClient] getMessages: Loaded \(messages.count) messages")
        for msg in messages {
            let partCount = msg.parts?.count ?? 0
            let textLen = msg.textContent.count
            print("[OpenCodeClient]   - \(msg.role.rawValue): id=\(msg.id), parts=\(partCount), textLen=\(textLen)")
        }
        
        return messages
    }
    
    private func fetchMessages(sessionId: String) async throws -> [OpenCodeMessage] {
        let url = baseURL.appendingPathComponent("session/\(sessionId)/message")
        let request = authorizedRequest(for: url)
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            logger.info("fetchMessages: HTTP \(httpResponse.statusCode), \(data.count) bytes")
        }
        
        do {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("[OpenCodeClient] fetchMessages: Raw JSON: \(jsonString)")
            }
            
            let responses = try JSONDecoder().decode([MessageResponse].self, from: data)
            let messages = responses.map { $0.toOpenCodeMessage() }
            print("[OpenCodeClient] fetchMessages: Decoded \(messages.count) messages")
            for (i, resp) in responses.enumerated() {
                let partCount = resp.parts?.count ?? 0
                let errorName = resp.info.error?.name ?? "none"
                let errorMsg = resp.info.error?.data?.message ?? ""
                print("[OpenCodeClient] fetchMessages:   [\(i)] role=\(resp.info.role.rawValue), parts=\(partCount), error=\(errorName) \(errorMsg)")
            }
            return messages
        } catch {
            print("[OpenCodeClient] fetchMessages: Decode FAILED - \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("[OpenCodeClient] fetchMessages: Raw JSON (first 2000 chars): \(String(jsonString.prefix(2000)))")
            }
            throw error
        }
    }
    
    private func fetchParts(sessionId: String) async throws -> [PartResponse] {
        let url = baseURL.appendingPathComponent("session/\(sessionId)/part")
        let request = authorizedRequest(for: url)
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("[OpenCodeClient] fetchParts: HTTP \(httpResponse.statusCode), \(data.count) bytes")
        }
        
        do {
            let parts = try JSONDecoder().decode([PartResponse].self, from: data)
            print("[OpenCodeClient] fetchParts: Decoded \(parts.count) parts")
            return parts
        } catch {
            print("[OpenCodeClient] fetchParts: Decode FAILED - \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("[OpenCodeClient] fetchParts: Raw JSON (first 1000 chars): \(String(jsonString.prefix(1000)))")
            }
            throw error
        }
    }
    
    func sendMessage(
        sessionId: String,
        text: String,
        providerID: String? = nil,
        modelID: String? = nil
    ) async throws -> OpenCodeMessage {
        let url = baseURL.appendingPathComponent("session/\(sessionId)/message")
        var request = authorizedRequest(for: url, method: "POST")
        
        var body: [String: Any] = [
            "parts": [["type": "text", "text": text]]
        ]
        
        if let providerID = providerID, let modelID = modelID {
            body["model"] = [
                "providerID": providerID,
                "modelID": modelID
            ]
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(OpenCodeMessage.self, from: data)
    }
    
    func sendMessageAsync(
        sessionId: String,
        text: String,
        providerID: String? = nil,
        modelID: String? = nil
    ) async throws {
        let url = baseURL.appendingPathComponent("session/\(sessionId)/prompt_async")
        var request = authorizedRequest(for: url, method: "POST")
        
        var body: [String: Any] = [
            "parts": [["type": "text", "text": text]]
        ]
        
        if let providerID = providerID, let modelID = modelID {
            body["model"] = [
                "providerID": providerID,
                "modelID": modelID
            ]
        }
        
        print("[OpenCodeClient] sendMessageAsync: providerID=\(providerID ?? "nil"), modelID=\(modelID ?? "nil")")
        print("[OpenCodeClient] sendMessageAsync: body=\(body)")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await session.data(for: request)
    }
    
    func deleteMessage(sessionId: String, messageId: String) async throws {
        let url = baseURL.appendingPathComponent("session/\(sessionId)/message/\(messageId)")
        let request = authorizedRequest(for: url, method: "DELETE")
        _ = try await session.data(for: request)
    }
    
    func abort(sessionId: String) async throws {
        let url = baseURL.appendingPathComponent("session/\(sessionId)/abort")
        let request = authorizedRequest(for: url, method: "POST")
        _ = try await session.data(for: request)
    }
    
    func listCommands() async throws -> [SlashCommand] {
        let url = baseURL.appendingPathComponent("command")
        let request = authorizedRequest(for: url)
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode([SlashCommand].self, from: data)
    }
    
    func getProviders() async throws -> ProvidersResponse {
        let url = baseURL.appendingPathComponent("config/providers")
        let request = authorizedRequest(for: url)
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(ProvidersResponse.self, from: data)
    }
    
    func getTodos(sessionId: String) async throws -> [TodoItem] {
        let url = baseURL.appendingPathComponent("session/\(sessionId)/todo")
        let request = authorizedRequest(for: url)
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode([TodoItem].self, from: data)
    }
    
    func getDiffs(sessionId: String) async throws -> [FileDiff] {
        let url = baseURL.appendingPathComponent("session/\(sessionId)/diff")
        let request = authorizedRequest(for: url)
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode([FileDiff].self, from: data)
    }
    
    func revert(sessionId: String) async throws {
        let url = baseURL.appendingPathComponent("session/\(sessionId)/revert")
        let request = authorizedRequest(for: url, method: "POST")
        _ = try await session.data(for: request)
    }
    
    func getMCPStatus() async throws -> [String: MCPStatus] {
        let url = baseURL.appendingPathComponent("mcp")
        let request = authorizedRequest(for: url)
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode([String: MCPStatus].self, from: data)
    }
    
    func connectMCP(name: String) async throws {
        let url = baseURL.appendingPathComponent("mcp/\(name)/connect")
        let request = authorizedRequest(for: url, method: "POST")
        _ = try await session.data(for: request)
    }
    
    func getLSPStatus() async throws -> [LSPStatus] {
        let url = baseURL.appendingPathComponent("lsp")
        let request = authorizedRequest(for: url)
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode([LSPStatus].self, from: data)
    }
    
    func getAgents() async throws -> [Agent] {
        let url = baseURL.appendingPathComponent("agent")
        let request = authorizedRequest(for: url)
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode([Agent].self, from: data)
    }
    
    func subscribeToEvents() -> AsyncStream<ServerEvent> {
        AsyncStream { continuation in
            eventTask = Task {
                let url = baseURL.appendingPathComponent("event")
                var request = authorizedRequest(for: url)
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                
                logger.info("SSE: Connecting to \(url.absoluteString)")
                
                do {
                    let (bytes, response) = try await session.bytes(for: request)
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        logger.info("SSE: Connected with HTTP \(httpResponse.statusCode)")
                    }
                    
                    for try await line in bytes.lines {
                        if Task.isCancelled {
                            logger.info("SSE: Task cancelled")
                            break
                        }
                        
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonString = String(line.dropFirst(6))
                        
                        // Log full JSON for non-heartbeat events to debug parsing issues
                        if !jsonString.contains("server.heartbeat") {
                            print("[SSE RAW] \(jsonString)")
                        }
                        if let event = parseSSEEvent(jsonString) {
                            if !jsonString.contains("server.heartbeat") {
                                print("[SSE OK] Yielding event for type in JSON")
                            }
                            continuation.yield(event)
                        } else {
                            if !jsonString.contains("server.heartbeat") {
                                print("[SSE DROPPED] parseSSEEvent returned nil for: \(String(jsonString.prefix(300)))")
                            }
                        }
                    }
                    logger.info("SSE: Stream ended normally")
                } catch {
                    logger.error("SSE: Error - \(error.localizedDescription)")
                    if !Task.isCancelled {
                        continuation.yield(.error(error))
                    }
                }
                
                continuation.finish()
            }
            
            continuation.onTermination = { @Sendable _ in
                Task { await self.cancelEventTask() }
            }
        }
    }
    
    private func cancelEventTask() {
        eventTask?.cancel()
        eventTask = nil
    }
    
    private nonisolated func parseSSEEvent(_ json: String) -> ServerEvent? {
        guard let data = json.data(using: .utf8) else { 
            logger.error("SSE: Failed to convert JSON string to data")
            return nil 
        }
        
        let decoder = JSONDecoder()
        
        do {
            let wrapper = try decoder.decode(SSEEventWrapper.self, from: data)
            logger.info("SSE: Parsed wrapper with type: \(wrapper.type)")
            
            switch wrapper.type {
            case "message.updated":
                if let info = wrapper.properties?.messageInfo {
                    let message = OpenCodeMessage(info: info, parts: nil)
                    logger.info("SSE: message.updated for message \(info.id)")
                    return .messageUpdated(message)
                } else {
                    if let propError = wrapper.propertiesError {
                        print("[SSE FAIL] message.updated - properties decode error: \(propError)")
                    } else {
                        print("[SSE FAIL] message.updated - properties decoded but messageInfo is nil")
                    }
                    print("[SSE FAIL] Raw JSON was: \(String(json.prefix(500)))")
                }
            case "message.part.updated":
                let messageID = wrapper.properties?.partMessageID ?? ""
                let part = wrapper.properties?.part ?? .unknown
                if messageID.isEmpty {
                    print("[SSE WARN] message.part.updated with empty messageID, raw: \(String(json.prefix(300)))")
                }
                print("[SSE PART] message.part.updated for \(messageID), part type: \(String(describing: part))")
                return .partUpdated(messageID, part)
            case "session.updated":
                if let session = wrapper.properties?.sessionInfo {
                    logger.info("SSE: session.updated for session \(session.id)")
                    return .sessionUpdated(session)
                } else {
                    logger.warning("SSE: session.updated but no sessionInfo found")
                }
            case "message.removed":
                if let messageId = wrapper.properties?.messageId {
                    return .messageRemoved(messageId)
                }
            case "session.error":
                let errorMessage = wrapper.properties?.errorMessage ?? "Session error occurred"
                print("[SSE ERROR EVENT] session.error: \(errorMessage)")
                return .error(NSError(domain: "OpenCode", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
            case "session.status", "session.idle", "session.diff":
                logger.info("SSE: Ignoring event type: \(wrapper.type)")
                return nil
            case "server.heartbeat":
                return nil
            case "server.connected":
                logger.info("SSE: server.connected")
                return .connected
            default:
                logger.info("SSE: Unknown event type: \(wrapper.type)")
                return nil
            }
        } catch let decodingError as DecodingError {
            switch decodingError {
            case .keyNotFound(let key, let context):
                logger.error("SSE: Missing key '\(key.stringValue)' - \(context.debugDescription)")
            case .typeMismatch(let type, let context):
                logger.error("SSE: Type mismatch for \(type) - \(context.debugDescription)")
            case .valueNotFound(let type, let context):
                logger.error("SSE: Value not found for \(type) - \(context.debugDescription)")
            case .dataCorrupted(let context):
                logger.error("SSE: Data corrupted - \(context.debugDescription)")
            @unknown default:
                logger.error("SSE: Unknown decoding error - \(decodingError.localizedDescription)")
            }
            logger.error("SSE: Raw JSON: \(String(json.prefix(500)))")
        } catch {
            logger.error("SSE: JSON decode error: \(error.localizedDescription)")
            logger.error("SSE: Raw JSON: \(String(json.prefix(500)))")
        }
        
        return nil
    }
    
    func disconnect() {
        eventTask?.cancel()
        eventTask = nil
    }
}

private struct SSEEventWrapper: Decodable {
    let type: String
    let properties: SSEEventProperties?
    let propertiesError: String?
    
    enum CodingKeys: String, CodingKey {
        case type, properties
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        
        do {
            properties = try container.decodeIfPresent(SSEEventProperties.self, forKey: .properties)
            propertiesError = nil
        } catch {
            print("[SSE DECODE ERROR] Failed to decode properties for '\(type)': \(error)")
            properties = nil
            propertiesError = error.localizedDescription
        }
    }
}

private struct SSEPartWrapper: Decodable {
    let id: String?
    let sessionID: String?
    let messageID: String
    let type: String
    let text: String?
    let callID: String?
    let tool: String?
    let state: ToolState?
    let reasoning: String?
    
    func toMessagePart() -> MessagePart {
        switch type {
        case "text":
            return .text(TextPart(type: type, text: text ?? ""))
        case "tool":
            return .tool(ToolPart(type: type, callID: callID, tool: tool ?? "", state: state))
        case "reasoning":
            return .reasoning(ReasoningPart(type: type, text: text, reasoning: reasoning, reasoningContent: nil))
        default:
            return .unknown
        }
    }
}

/// Wrapper for the nested "error" object in session.error events
/// Structure: { "error": { "name": "...", "data": { "message": "..." } } }
private struct SSEErrorWrapper: Decodable {
    let name: String?
    let data: SSEErrorData?
    
    struct SSEErrorData: Decodable {
        let message: String?
        let statusCode: Int?
        let isRetryable: Bool?
    }
    
    var errorMessage: String {
        data?.message ?? name ?? "Unknown error"
    }
}

private struct SSEEventProperties: Decodable {
    let info: MessageOrSessionInfo?
    let messageId: String?
    let sessionID: String?
    let partWrapper: SSEPartWrapper?
    let errorWrapper: SSEErrorWrapper?
    
    var messageInfo: MessageInfo? {
        if case .message(let info) = info { return info }
        return nil
    }
    
    var sessionInfo: OpenCodeSession? {
        if case .session(let session) = info { return session }
        return nil
    }
    
    /// The decoded MessagePart from the nested "part" object
    var part: MessagePart? {
        partWrapper?.toMessagePart()
    }
    
    /// The messageID from the nested "part" object (for message.part.updated events)
    var partMessageID: String? {
        partWrapper?.messageID
    }
    
    /// The error message from the nested "error" object (for session.error events)
    var errorMessage: String? {
        errorWrapper?.errorMessage
    }
    
    enum CodingKeys: String, CodingKey {
        case info, messageId, sessionID, part, error
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        messageId = try container.decodeIfPresent(String.self, forKey: .messageId)
        sessionID = try container.decodeIfPresent(String.self, forKey: .sessionID)
        
        // Decode the nested "part" object for message.part.updated events
        if container.contains(.part) {
            do {
                partWrapper = try container.decode(SSEPartWrapper.self, forKey: .part)
                print("[SSE PROPS] Decoded part: messageID=\(partWrapper?.messageID ?? "nil"), type=\(partWrapper?.type ?? "nil")")
            } catch {
                print("[SSE PROPS] Failed to decode part: \(error)")
                partWrapper = nil
            }
        } else {
            partWrapper = nil
        }
        
        // Decode the nested "error" object for session.error events
        if container.contains(.error) {
            do {
                errorWrapper = try container.decode(SSEErrorWrapper.self, forKey: .error)
                print("[SSE PROPS] Decoded error: \(errorWrapper?.errorMessage ?? "nil")")
            } catch {
                print("[SSE PROPS] Failed to decode error: \(error)")
                errorWrapper = nil
            }
        } else {
            errorWrapper = nil
        }
        
        // Decode the "info" object for message.updated and session.updated events
        if container.contains(.info) {
            do {
                let messageInfo = try container.decode(MessageInfo.self, forKey: .info)
                info = .message(messageInfo)
            } catch {
                do {
                    let sessionInfo = try container.decode(OpenCodeSession.self, forKey: .info)
                    info = .session(sessionInfo)
                } catch {
                    info = nil
                }
            }
        } else {
            info = nil
        }
    }
}

private enum MessageOrSessionInfo: Codable {
    case message(MessageInfo)
    case session(OpenCodeSession)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let message = try? container.decode(MessageInfo.self) {
            self = .message(message)
        } else if let session = try? container.decode(OpenCodeSession.self) {
            self = .session(session)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown info type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .message(let info):
            try container.encode(info)
        case .session(let session):
            try container.encode(session)
        }
    }
}
