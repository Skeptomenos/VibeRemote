# VibeRemote - Implementation Plan

## Overview

This document outlines the implementation plan for transforming VibeRemote from a terminal-based SSH app into a **native iOS chat experience** that uses the OpenCode HTTP API as its backend.

**Key Principle:** OpenCode becomes a pure backend. The iOS app renders ALL UI elements natively - input fields, message display, model selection, tool calls, settings, and status panels.

---

## Table of Contents

1. [Architecture Comparison](#architecture-comparison)
2. [What the API Provides](#what-the-api-provides)
3. [iOS App Feature Mapping](#ios-app-feature-mapping)
4. [Parallel Implementation Strategy](#parallel-implementation-strategy)
5. [Phase 1: Foundation](#phase-1-foundation)
6. [Phase 2: Core Chat Experience](#phase-2-core-chat-experience)
7. [Phase 3: Advanced Controls](#phase-3-advanced-controls)
8. [Phase 4: Status Panels](#phase-4-status-panels)
9. [Phase 5: Polish & Integration](#phase-5-polish--integration)
10. [File Structure](#file-structure)
11. [API Reference](#api-reference)

---

## Architecture Comparison

### Current: SSH + Terminal Emulation

```
┌─────────────────┐         SSH          ┌─────────────────┐
│   iOS Device    │◄──────────────────►  │  Linux Server   │
│                 │                       │                 │
│  ┌───────────┐  │   PTY over SSH        │  ┌───────────┐  │
│  │ SwiftTerm │◄─┼───────────────────────┼─►│   tmux    │  │
│  │ (renders  │  │                       │  │           │  │
│  │  TUI)     │  │                       │  │ opencode  │  │
│  └───────────┘  │                       │  │   TUI     │  │
└─────────────────┘                       └─────────────────┘

Problems:
- Terminal escape codes are complex to parse
- No native iOS scrolling
- Limited touch interaction
- Can't extract structured data (models, tokens, etc.)
```

### New: HTTP API + Native UI

```
┌─────────────────┐        HTTP/SSE       ┌─────────────────┐
│   iOS Device    │◄──────────────────►   │  Linux Server   │
│                 │                       │                 │
│  ┌───────────┐  │   JSON + Events       │  ┌───────────┐  │
│  │ SwiftUI   │◄─┼───────────────────────┼─►│ opencode  │  │
│  │ Native UI │  │                       │  │  serve    │  │
│  │           │  │                       │  │ (headless)│  │
│  │ - Chat    │  │                       │  └───────────┘  │
│  │ - Models  │  │                       │                 │
│  │ - Tools   │  │                       │                 │
│  │ - Status  │  │                       │                 │
│  └───────────┘  │                       │                 │
└─────────────────┘                       └─────────────────┘

Benefits:
- Native iOS scrolling, animations, gestures
- Structured data (JSON) for all UI elements
- Full control over presentation
- Real-time updates via SSE
- Offline message viewing
```

---

## What the API Provides

### Complete API Endpoint Reference

| Category | Endpoint | Method | Description | iOS Feature |
|----------|----------|--------|-------------|-------------|
| **Sessions** | `/session` | GET | List all sessions | Session list sidebar |
| | `/session` | POST | Create session | New chat button |
| | `/session/:id` | GET | Get session details + stats | Session info panel |
| | `/session/:id` | DELETE | Delete session | Swipe to delete |
| | `/session/:id/message` | GET | Get all messages | Chat history |
| | `/session/:id/message` | POST | Send message (streaming) | Send button |
| | `/session/:id/prompt_async` | POST | Send message (background) | Background processing |
| | `/session/:id/abort` | POST | Stop generation | Stop button |
| | `/session/:id/todo` | GET | Get todo list | Todo panel |
| | `/session/:id/diff` | GET | Get file diffs | Diff viewer |
| | `/session/:id/fork` | POST | Fork session | Duplicate chat |
| | `/session/:id/revert` | POST | Revert changes | Undo button |
| | `/session/:id/share` | POST | Share session | Share sheet |
| | `/session/:id/summarize` | POST | Summarize session | Summary view |
| **Messages** | `/session/:id/message/:msgId` | DELETE | Delete message | Long-press delete |
| | `/session/:id/command` | POST | Execute slash command | Command palette |
| **Providers** | `/config/providers` | GET | List providers + models | Model picker |
| | `/provider/auth` | GET | Get auth methods | Settings |
| | `/provider/auth` | POST | Authenticate provider | Login flow |
| **Commands** | `/command` | GET | List slash commands | Command autocomplete |
| **MCP** | `/mcp` | GET | Get MCP server status | MCP status panel |
| | `/mcp` | POST | Add MCP server | Add MCP sheet |
| | `/mcp/:name/connect` | POST | Connect to MCP | Connect button |
| **LSP** | `/lsp` | GET | Get LSP status | LSP status panel |
| **Files** | `/file` | GET | List files | File browser |
| | `/file/content` | GET | Read file content | File viewer |
| | `/file/status` | GET | Get file status | Modified files list |
| | `/find/file` | GET | Fuzzy file search | File search |
| | `/find/symbol` | GET | Symbol search | Symbol search |
| **Agents** | `/agent` | GET | List available agents | Agent picker |
| **Events** | `/event` | GET | SSE event stream | Real-time updates |
| | `/global/event` | GET | Global events | App-wide notifications |
| **System** | `/global/health` | GET | Health check | Connection status |
| | `/config` | GET | Get configuration | Settings |
| | `/log` | GET | Get logs | Debug panel |
| | `/vcs` | GET | Version control status | Git status |
| | `/pty` | GET | PTY sessions | Terminal fallback |

### Message Structure (What We Render)

```json
{
  "info": {
    "id": "msg_xxx",
    "sessionID": "ses_xxx",
    "role": "assistant",
    "time": {
      "created": 1234567890,
      "completed": 1234567891
    },
    "modelID": "claude-sonnet-4",
    "providerID": "anthropic",
    "cost": 0.0023,
    "tokens": {
      "input": 1500,
      "output": 500,
      "reasoning": 0,
      "cache": { "read": 100, "write": 50 }
    }
  },
  "parts": [
    { "type": "text", "text": "I'll help you fix that bug..." },
    { 
      "type": "tool-invocation",
      "toolInvocation": {
        "toolName": "read",
        "args": { "filePath": "/src/auth.ts" },
        "state": "result"
      }
    },
    {
      "type": "tool-result",
      "toolResult": {
        "result": "file contents...",
        "isError": false
      }
    }
  ]
}
```

### SSE Event Types

| Event | Description | iOS Handling |
|-------|-------------|--------------|
| `message.updated` | Message content changed | Update message bubble |
| `part.updated` | Part content streaming | Animate text appearance |
| `session.updated` | Session state changed | Update session list |
| `message.removed` | Message deleted | Remove from list |
| `lsp.client.diagnostics` | LSP diagnostics | Update LSP panel |
| `installation.update-available` | Update available | Show badge |

---

## iOS App Feature Mapping

### OpenCode TUI → iOS Native UI

| TUI Element | API Source | iOS Implementation |
|-------------|------------|-------------------|
| **Chat messages** | `GET /session/:id/message` | `ScrollView` + `LazyVStack` of `MessageBubble` |
| **Input field** | `POST /session/:id/message` | `TextField` + Send button |
| **Model selector** | `GET /config/providers` | `Picker` or custom sheet |
| **Provider selector** | `GET /config/providers` | Segmented control or menu |
| **Slash commands** | `GET /command` | Autocomplete popup |
| **Token usage** | Message `info.tokens` | Badge on message |
| **Cost display** | Message `info.cost` | Cumulative in header |
| **Modified files** | `GET /session/:id/diff` | Collapsible list |
| **Todo list** | `GET /session/:id/todo` | Checklist view |
| **MCP servers** | `GET /mcp` | Status cards |
| **LSP status** | `GET /lsp` | Status indicators |
| **Tool calls** | Message `parts[type=tool-*]` | Collapsible cards |
| **Stop button** | `POST /session/:id/abort` | Floating button |
| **Session list** | `GET /session` | Sidebar / swipe drawer |

### Native Controls We Can Build

```
┌─────────────────────────────────────────────────────────────┐
│  ← Sessions    Personal-OS    ⚙️ Settings                   │
├─────────────────────────────────────────────────────────────┤
│  Model: [claude-sonnet-4 ▼]  Provider: [anthropic ▼]       │
│  Tokens: 2,450 in / 1,230 out  Cost: $0.15                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ You: Fix the authentication bug in auth.ts          │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 🤖 Assistant                          $0.02 • 1.2k  │   │
│  │                                                      │   │
│  │ I'll analyze the authentication module...            │   │
│  │                                                      │   │
│  │ ▼ Read: src/auth.ts                    [Collapse]   │   │
│  │   ┌──────────────────────────────────────────────┐  │   │
│  │   │ 1  import { hash } from 'bcrypt';            │  │   │
│  │   │ 2  export async function login() {           │  │   │
│  │   │ ...                                          │  │   │
│  │   └──────────────────────────────────────────────┘  │   │
│  │                                                      │   │
│  │ ▼ Edit: src/auth.ts                                 │   │
│  │   - const token = jwt.sign(user)                    │   │
│  │   + const token = jwt.sign(user, { expiresIn: '1h'})│   │
│  │                                                      │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  [/] Type a message...                           [Send]    │
│  ────────────────────────────────────────────────────────  │
│  Suggestions: /compact  /clear  /undo  /share              │
└─────────────────────────────────────────────────────────────┘
```

### Status Panel (Slide-up Sheet)

```
┌─────────────────────────────────────────────────────────────┐
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                             │
│  SESSION STATUS                                             │
│  ─────────────────────────────────────────────────────────  │
│  📊 Tokens: 2,450 input / 1,230 output                     │
│  💰 Cost: $0.15                                            │
│  ⏱️ Duration: 45.2s                                        │
│                                                             │
│  MODIFIED FILES (3)                                         │
│  ─────────────────────────────────────────────────────────  │
│  📄 src/auth.ts                              [View Diff]   │
│  📄 src/middleware.ts                        [View Diff]   │
│  📄 tests/auth.test.ts                       [View Diff]   │
│                                                             │
│  TODO LIST                                                  │
│  ─────────────────────────────────────────────────────────  │
│  ☑️ Analyze authentication flow                            │
│  ☑️ Fix token expiration                                   │
│  ⬜ Add unit tests                                          │
│  ⬜ Update documentation                                    │
│                                                             │
│  MCP SERVERS                                                │
│  ─────────────────────────────────────────────────────────  │
│  🟢 filesystem    Connected                                │
│  🟢 github        Connected                                │
│  🔴 slack         Disconnected              [Connect]      │
│                                                             │
│  LSP STATUS                                                 │
│  ─────────────────────────────────────────────────────────  │
│  🟢 typescript    Running (v5.3.2)                         │
│  🟢 rust-analyzer Running (v0.3.1)                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Parallel Implementation Strategy

### Keep SSH, Add API

We maintain **both connection modes** for maximum flexibility:

```swift
enum ConnectionMode: String, Codable {
    case api = "api"      // OpenCode HTTP API (preferred)
    case ssh = "ssh"      // SSH + Terminal (fallback)
}
```

| Scenario | Connection Mode | Reason |
|----------|-----------------|--------|
| OpenCode with API server | **API** | Full native experience |
| OpenCode without API | **SSH** | Fallback to terminal |
| Claude Code | **SSH** | No HTTP API available |
| Plain shell | **SSH** | Terminal required |
| Server without Gateway | **SSH** | Direct connection |

### Migration Path

```
Phase 1: Add API client alongside SSH
         ├── SSHConnectionManager (existing)
         └── OpenCodeClient (new)

Phase 2: Add ChatView alongside TerminalView
         ├── TerminalContainerView (existing)
         └── ChatContainerView (new)

Phase 3: Route based on connection mode
         └── ContentView decides which view to show

Phase 4: Add advanced features (model picker, status panels)

Phase 5: Polish and optimize
```

---

## Phase 1: Foundation

### 1.1 Extend Data Model

**File:** `ios-app/VibeRemote/Sources/Models/AgentSession.swift`

```swift
@Model
final class AgentSession {
    // Existing fields...
    var id: UUID
    var name: String
    var projectPath: String
    var agentType: AgentType
    var lastActive: Date
    var isPinned: Bool
    var opencodeSessionId: String?
    var opencodeSessionTitle: String?
    
    // NEW: Connection mode
    var connectionMode: ConnectionMode = .api
    
    // NEW: API-specific fields
    var apiBaseURL: String?              // e.g., "http://192.168.178.2:4096"
    var opencodeProjectID: String?       // SHA1 hash of directory
    var lastKnownModel: String?          // e.g., "anthropic/claude-sonnet-4"
    var lastKnownProvider: String?       // e.g., "anthropic"
    
    // Computed properties
    var connectionIcon: String {
        switch connectionMode {
        case .api: return "bubble.left.and.bubble.right"
        case .ssh: return "terminal"
        }
    }
    
    var effectiveBaseURL: URL? {
        guard let urlString = apiBaseURL else { return nil }
        return URL(string: urlString)
    }
}

enum ConnectionMode: String, Codable {
    case api = "api"
    case ssh = "ssh"
}
```

### 1.2 Create API Models

**File:** `ios-app/VibeRemote/Sources/Models/OpenCodeModels.swift`

```swift
import Foundation

// MARK: - Session

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
    let title: String?
    let description: String?
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
    let info: MessageInfo
    let parts: [MessagePart]
    
    var id: String { info.id }
}

struct MessageInfo: Codable {
    let id: String
    let sessionID: String
    let role: MessageRole
    let time: MessageTime
    let modelID: String?
    let providerID: String?
    let cost: Double?
    let tokens: TokenUsage?
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
}

struct CacheUsage: Codable {
    let read: Int
    let write: Int
}

// MARK: - Message Parts

enum MessagePart: Codable {
    case text(TextPart)
    case toolInvocation(ToolInvocationPart)
    case toolResult(ToolResultPart)
    case file(FilePart)
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
        case "tool-result":
            self = .toolResult(try ToolResultPart(from: decoder))
        case "file":
            self = .file(try FilePart(from: decoder))
        default:
            self = .unknown
        }
    }
    
    func encode(to encoder: Encoder) throws {
        // Implementation for encoding
    }
}

struct TextPart: Codable {
    let type: String
    let text: String
}

struct ToolInvocationPart: Codable {
    let type: String
    let toolInvocation: ToolInvocation
}

struct ToolInvocation: Codable {
    let toolName: String
    let args: [String: AnyCodable]
    let state: String
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

// MARK: - Providers

struct ProvidersResponse: Codable {
    let providers: [Provider]
    let `default`: [String: String]
}

struct Provider: Codable, Identifiable {
    let id: String
    let name: String
    let models: [Model]
}

struct Model: Codable, Identifiable {
    let id: String
    let name: String
    let contextWindow: Int?
    let maxOutput: Int?
}

// MARK: - Commands

struct Command: Codable, Identifiable {
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
    case partUpdated(String, MessagePart)  // messageId, part
    case sessionUpdated(OpenCodeSession)
    case messageRemoved(String)  // messageId
    case lspDiagnostics([Diagnostic])
    case updateAvailable(String)  // version
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

// MARK: - Helper

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
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
        } else if let bool = value as? Bool {
            try container.encode(bool)
        }
    }
}
```

### 1.3 Create API Client

**File:** `ios-app/VibeRemote/Sources/Services/OpenCodeClient.swift`

```swift
import Foundation
import os.log

private let logger = Logger(subsystem: "com.vibeRemote.app", category: "OpenCodeClient")

actor OpenCodeClient {
    private let baseURL: URL
    private let session: URLSession
    private var eventTask: Task<Void, Never>?
    
    init(baseURL: URL) {
        self.baseURL = baseURL
        self.session = URLSession(configuration: .default)
    }
    
    // MARK: - Health
    
    func healthCheck() async throws -> Bool {
        let url = baseURL.appendingPathComponent("global/health")
        let (_, response) = try await session.data(from: url)
        return (response as? HTTPURLResponse)?.statusCode == 200
    }
    
    // MARK: - Sessions
    
    func listSessions() async throws -> [OpenCodeSession] {
        let url = baseURL.appendingPathComponent("session")
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([OpenCodeSession].self, from: data)
    }
    
    func getSession(id: String) async throws -> OpenCodeSession {
        let url = baseURL.appendingPathComponent("session/\(id)")
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(OpenCodeSession.self, from: data)
    }
    
    func createSession(title: String) async throws -> OpenCodeSession {
        let url = baseURL.appendingPathComponent("session")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["title": title])
        
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(OpenCodeSession.self, from: data)
    }
    
    func deleteSession(id: String) async throws {
        let url = baseURL.appendingPathComponent("session/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try await session.data(for: request)
    }
    
    // MARK: - Messages
    
    func getMessages(sessionId: String) async throws -> [OpenCodeMessage] {
        let url = baseURL.appendingPathComponent("session/\(sessionId)/message")
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([OpenCodeMessage].self, from: data)
    }
    
    func sendMessage(
        sessionId: String,
        text: String,
        model: String? = nil,
        agent: String? = nil
    ) async throws -> OpenCodeMessage {
        let url = baseURL.appendingPathComponent("session/\(sessionId)/message")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "parts": [["type": "text", "text": text]]
        ]
        if let model = model { body["model"] = model }
        if let agent = agent { body["agent"] = agent }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(OpenCodeMessage.self, from: data)
    }
    
    func sendMessageAsync(
        sessionId: String,
        text: String,
        model: String? = nil
    ) async throws {
        let url = baseURL.appendingPathComponent("session/\(sessionId)/prompt_async")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "parts": [["type": "text", "text": text]]
        ]
        if let model = model { body["model"] = model }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await session.data(for: request)
    }
    
    func deleteMessage(sessionId: String, messageId: String) async throws {
        let url = baseURL.appendingPathComponent("session/\(sessionId)/message/\(messageId)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try await session.data(for: request)
    }
    
    func abort(sessionId: String) async throws {
        let url = baseURL.appendingPathComponent("session/\(sessionId)/abort")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        _ = try await session.data(for: request)
    }
    
    // MARK: - Commands
    
    func listCommands() async throws -> [Command] {
        let url = baseURL.appendingPathComponent("command")
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([Command].self, from: data)
    }
    
    func executeCommand(
        sessionId: String,
        command: String,
        arguments: [String: Any] = [:]
    ) async throws -> OpenCodeMessage {
        let url = baseURL.appendingPathComponent("session/\(sessionId)/command")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "command": command,
            "arguments": arguments
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(OpenCodeMessage.self, from: data)
    }
    
    // MARK: - Providers & Models
    
    func getProviders() async throws -> ProvidersResponse {
        let url = baseURL.appendingPathComponent("config/providers")
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(ProvidersResponse.self, from: data)
    }
    
    // MARK: - Session Extras
    
    func getTodos(sessionId: String) async throws -> [TodoItem] {
        let url = baseURL.appendingPathComponent("session/\(sessionId)/todo")
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([TodoItem].self, from: data)
    }
    
    func getDiffs(sessionId: String) async throws -> [FileDiff] {
        let url = baseURL.appendingPathComponent("session/\(sessionId)/diff")
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([FileDiff].self, from: data)
    }
    
    func revert(sessionId: String) async throws {
        let url = baseURL.appendingPathComponent("session/\(sessionId)/revert")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        _ = try await session.data(for: request)
    }
    
    // MARK: - MCP
    
    func getMCPStatus() async throws -> [String: MCPStatus] {
        let url = baseURL.appendingPathComponent("mcp")
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([String: MCPStatus].self, from: data)
    }
    
    func connectMCP(name: String) async throws {
        let url = baseURL.appendingPathComponent("mcp/\(name)/connect")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        _ = try await session.data(for: request)
    }
    
    // MARK: - LSP
    
    func getLSPStatus() async throws -> [LSPStatus] {
        let url = baseURL.appendingPathComponent("lsp")
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([LSPStatus].self, from: data)
    }
    
    // MARK: - Agents
    
    func getAgents() async throws -> [Agent] {
        let url = baseURL.appendingPathComponent("agent")
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([Agent].self, from: data)
    }
    
    // MARK: - SSE Events
    
    func subscribeToEvents() -> AsyncStream<ServerEvent> {
        AsyncStream { continuation in
            eventTask = Task {
                let url = baseURL.appendingPathComponent("event")
                
                do {
                    let (bytes, _) = try await session.bytes(from: url)
                    
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonString = String(line.dropFirst(6))
                        
                        if let event = parseSSEEvent(jsonString) {
                            continuation.yield(event)
                        }
                    }
                } catch {
                    if !Task.isCancelled {
                        continuation.yield(.error(error))
                    }
                }
                
                continuation.finish()
            }
            
            continuation.onTermination = { @Sendable _ in
                self.eventTask?.cancel()
            }
        }
    }
    
    private nonisolated func parseSSEEvent(_ json: String) -> ServerEvent? {
        guard let data = json.data(using: .utf8) else { return nil }
        
        do {
            let decoder = JSONDecoder()
            
            // Try to parse as different event types
            if let wrapper = try? decoder.decode(EventWrapper.self, from: data) {
                switch wrapper.type {
                case "message.updated":
                    if let message = try? decoder.decode(OpenCodeMessage.self, from: data) {
                        return .messageUpdated(message)
                    }
                case "session.updated":
                    if let session = try? decoder.decode(OpenCodeSession.self, from: data) {
                        return .sessionUpdated(session)
                    }
                case "server.connected":
                    return .connected
                default:
                    break
                }
            }
        } catch {
            logger.error("Failed to parse SSE event: \(error)")
        }
        
        return nil
    }
    
    func disconnect() {
        eventTask?.cancel()
        eventTask = nil
    }
}

private struct EventWrapper: Codable {
    let type: String
}
```

---

## Phase 2: Core Chat Experience

### 2.1 Chat View Model

**File:** `ios-app/VibeRemote/Sources/ViewModels/ChatViewModel.swift`

```swift
import Foundation
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.vibeRemote.app", category: "ChatViewModel")

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [OpenCodeMessage] = []
    @Published var isLoading = false
    @Published var isStreaming = false
    @Published var error: Error?
    @Published var connectionState: ConnectionState = .disconnected
    
    // Model selection
    @Published var providers: [Provider] = []
    @Published var selectedProvider: String?
    @Published var selectedModel: String?
    
    // Commands
    @Published var commands: [Command] = []
    @Published var showCommandPalette = false
    
    // Status
    @Published var todos: [TodoItem] = []
    @Published var diffs: [FileDiff] = []
    @Published var mcpServers: [String: MCPStatus] = [:]
    @Published var lspStatus: [LSPStatus] = []
    
    private let session: AgentSession
    private var client: OpenCodeClient?
    private var eventTask: Task<Void, Never>?
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case error(String)
    }
    
    init(session: AgentSession) {
        self.session = session
    }
    
    func connect() async {
        guard let baseURL = session.effectiveBaseURL else {
            connectionState = .error("No API URL configured")
            return
        }
        
        connectionState = .connecting
        client = OpenCodeClient(baseURL: baseURL)
        
        do {
            // Health check
            guard try await client?.healthCheck() == true else {
                connectionState = .error("Server not responding")
                return
            }
            
            // Load initial data in parallel
            async let messagesTask = client?.getMessages(sessionId: session.opencodeSessionId ?? "")
            async let providersTask = client?.getProviders()
            async let commandsTask = client?.listCommands()
            
            messages = try await messagesTask ?? []
            if let providersResponse = try await providersTask {
                providers = providersResponse.providers
                // Set defaults
                if selectedProvider == nil, let first = providers.first {
                    selectedProvider = first.id
                    selectedModel = providersResponse.default[first.id]
                }
            }
            commands = try await commandsTask ?? []
            
            connectionState = .connected
            
            // Start SSE subscription
            subscribeToEvents()
            
            // Load status data
            await refreshStatus()
            
        } catch {
            logger.error("Connection failed: \(error)")
            connectionState = .error(error.localizedDescription)
        }
    }
    
    func disconnect() {
        eventTask?.cancel()
        eventTask = nil
        client?.disconnect()
        connectionState = .disconnected
    }
    
    func sendMessage(_ text: String) async {
        guard let client = client,
              let sessionId = session.opencodeSessionId else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let model = selectedModel.map { "\(selectedProvider ?? "")/\($0)" }
            let response = try await client.sendMessage(
                sessionId: sessionId,
                text: text,
                model: model
            )
            
            // Message will be added via SSE, but add optimistically
            if !messages.contains(where: { $0.id == response.id }) {
                messages.append(response)
            }
        } catch {
            self.error = error
        }
    }
    
    func abort() async {
        guard let client = client,
              let sessionId = session.opencodeSessionId else { return }
        
        do {
            try await client.abort(sessionId: sessionId)
        } catch {
            self.error = error
        }
    }
    
    func executeCommand(_ command: String, arguments: [String: Any] = [:]) async {
        guard let client = client,
              let sessionId = session.opencodeSessionId else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await client.executeCommand(
                sessionId: sessionId,
                command: command,
                arguments: arguments
            )
            
            if !messages.contains(where: { $0.id == response.id }) {
                messages.append(response)
            }
        } catch {
            self.error = error
        }
    }
    
    func deleteMessage(_ messageId: String) async {
        guard let client = client,
              let sessionId = session.opencodeSessionId else { return }
        
        do {
            try await client.deleteMessage(sessionId: sessionId, messageId: messageId)
            messages.removeAll { $0.id == messageId }
        } catch {
            self.error = error
        }
    }
    
    func refreshStatus() async {
        guard let client = client,
              let sessionId = session.opencodeSessionId else { return }
        
        async let todosTask = client.getTodos(sessionId: sessionId)
        async let diffsTask = client.getDiffs(sessionId: sessionId)
        async let mcpTask = client.getMCPStatus()
        async let lspTask = client.getLSPStatus()
        
        todos = (try? await todosTask) ?? []
        diffs = (try? await diffsTask) ?? []
        mcpServers = (try? await mcpTask) ?? [:]
        lspStatus = (try? await lspTask) ?? []
    }
    
    private func subscribeToEvents() {
        guard let client = client else { return }
        
        eventTask = Task {
            for await event in await client.subscribeToEvents() {
                await handleEvent(event)
            }
        }
    }
    
    private func handleEvent(_ event: ServerEvent) async {
        switch event {
        case .messageUpdated(let message):
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index] = message
            } else {
                messages.append(message)
            }
            
        case .sessionUpdated:
            // Refresh session data
            await refreshStatus()
            
        case .messageRemoved(let messageId):
            messages.removeAll { $0.id == messageId }
            
        case .connected:
            connectionState = .connected
            
        case .error(let error):
            self.error = error
            
        default:
            break
        }
    }
}
```

### 2.2 Chat View

**File:** `ios-app/VibeRemote/Sources/Views/ChatView.swift`

```swift
import SwiftUI

struct ChatContainerView: View {
    let session: AgentSession
    @StateObject private var viewModel: ChatViewModel
    @State private var showStatusPanel = false
    @State private var showModelPicker = false
    
    init(session: AgentSession) {
        self.session = session
        self._viewModel = StateObject(wrappedValue: ChatViewModel(session: session))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with model selector
            ChatHeaderView(
                session: session,
                viewModel: viewModel,
                onStatusTap: { showStatusPanel = true },
                onModelTap: { showModelPicker = true }
            )
            
            // Messages
            ChatMessagesView(viewModel: viewModel)
            
            // Input
            ChatInputView(viewModel: viewModel)
        }
        .background(OpenCodeTheme.background)
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
            ModelPickerView(viewModel: viewModel)
        }
    }
}

// MARK: - Header

struct ChatHeaderView: View {
    let session: AgentSession
    @ObservedObject var viewModel: ChatViewModel
    let onStatusTap: () -> Void
    let onModelTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Title bar
            HStack {
                Text(session.name)
                    .font(.headline)
                
                Spacer()
                
                // Connection status
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                Button(action: onStatusTap) {
                    Image(systemName: "info.circle")
                }
            }
            
            // Model selector bar
            HStack {
                Button(action: onModelTap) {
                    HStack {
                        Image(systemName: "cpu")
                        Text(viewModel.selectedModel ?? "Select Model")
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                // Token usage summary
                if let lastMessage = viewModel.messages.last,
                   let tokens = lastMessage.info.tokens {
                    Text("\(tokens.input + tokens.output) tokens")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(OpenCodeTheme.surface)
    }
    
    private var statusColor: Color {
        switch viewModel.connectionState {
        case .connected: return .green
        case .connecting: return .yellow
        case .disconnected: return .gray
        case .error: return .red
        }
    }
}

// MARK: - Messages List

struct ChatMessagesView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                            .contextMenu {
                                Button("Copy", systemImage: "doc.on.doc") {
                                    // Copy message text
                                }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    Task {
                                        await viewModel.deleteMessage(message.id)
                                    }
                                }
                            }
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let lastId = viewModel.messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubbleView: View {
    let message: OpenCodeMessage
    @State private var expandedTools: Set<String> = []
    
    var body: some View {
        HStack(alignment: .top) {
            if message.info.role == .user {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.info.role == .user ? .trailing : .leading, spacing: 8) {
                // Message header
                HStack {
                    if message.info.role == .assistant {
                        Image(systemName: "cpu")
                            .foregroundStyle(.secondary)
                    }
                    
                    if let model = message.info.modelID {
                        Text(model)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if let tokens = message.info.tokens {
                        Text("\(tokens.input + tokens.output)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let cost = message.info.cost, cost > 0 {
                        Text(String(format: "$%.4f", cost))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Message parts
                ForEach(Array(message.parts.enumerated()), id: \.offset) { index, part in
                    MessagePartView(
                        part: part,
                        isExpanded: expandedTools.contains("\(index)"),
                        onToggle: {
                            if expandedTools.contains("\(index)") {
                                expandedTools.remove("\(index)")
                            } else {
                                expandedTools.insert("\(index)")
                            }
                        }
                    )
                }
            }
            .padding()
            .background(bubbleBackground)
            .cornerRadius(16)
            
            if message.info.role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }
    
    private var bubbleBackground: Color {
        switch message.info.role {
        case .user:
            return .blue
        case .assistant:
            return Color(.systemGray5)
        case .system:
            return Color(.systemGray6)
        }
    }
}

// MARK: - Message Part

struct MessagePartView: View {
    let part: MessagePart
    let isExpanded: Bool
    let onToggle: () -> Void
    
    var body: some View {
        switch part {
        case .text(let textPart):
            Text(textPart.text)
                .textSelection(.enabled)
            
        case .toolInvocation(let toolPart):
            ToolCallCardView(
                toolName: toolPart.toolInvocation.toolName,
                args: toolPart.toolInvocation.args,
                isExpanded: isExpanded,
                onToggle: onToggle
            )
            
        case .toolResult(let resultPart):
            if isExpanded {
                ToolResultView(result: resultPart.toolResult)
            }
            
        case .file(let filePart):
            FilePartView(filePath: filePart.filePath)
            
        case .unknown:
            EmptyView()
        }
    }
}

// MARK: - Tool Call Card

struct ToolCallCardView: View {
    let toolName: String
    let args: [String: AnyCodable]
    let isExpanded: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: onToggle) {
                HStack {
                    Image(systemName: toolIcon)
                        .foregroundStyle(.orange)
                    
                    Text(toolName)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    if let path = args["filePath"]?.value as? String {
                        Text(URL(fileURLWithPath: path).lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                // Show args
                ForEach(Array(args.keys.sorted()), id: \.self) { key in
                    HStack {
                        Text(key)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(String(describing: args[key]?.value ?? ""))
                            .font(.caption2)
                            .lineLimit(3)
                    }
                }
            }
        }
        .padding(8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var toolIcon: String {
        switch toolName {
        case "read": return "doc.text"
        case "write", "edit": return "pencil"
        case "bash": return "terminal"
        case "glob", "grep": return "magnifyingglass"
        default: return "wrench"
        }
    }
}

// MARK: - Tool Result

struct ToolResultView: View {
    let result: ToolResult
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(result.result ?? "")
                .font(.system(.caption, design: .monospaced))
                .padding(8)
        }
        .frame(maxHeight: 200)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - File Part

struct FilePartView: View {
    let filePath: String
    
    var body: some View {
        HStack {
            Image(systemName: "doc")
            Text(URL(fileURLWithPath: filePath).lastPathComponent)
                .font(.caption)
        }
        .padding(8)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}
```

### 2.3 Chat Input

**File:** `ios-app/VibeRemote/Sources/Views/ChatInputView.swift`

```swift
import SwiftUI

struct ChatInputView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var inputText = ""
    @State private var showCommands = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Command suggestions
            if showCommands && !viewModel.commands.isEmpty {
                CommandSuggestionsView(
                    commands: filteredCommands,
                    onSelect: { command in
                        inputText = command.name + " "
                        showCommands = false
                    }
                )
            }
            
            Divider()
            
            // Input bar
            HStack(alignment: .bottom, spacing: 12) {
                // Slash command button
                Button(action: { showCommands.toggle() }) {
                    Image(systemName: "slash.circle")
                        .font(.title2)
                        .foregroundStyle(showCommands ? .blue : .secondary)
                }
                
                // Text input
                TextField("Message...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($isFocused)
                    .onChange(of: inputText) { _, newValue in
                        showCommands = newValue.hasPrefix("/")
                    }
                
                // Send / Stop button
                if viewModel.isLoading {
                    Button(action: {
                        Task { await viewModel.abort() }
                    }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                    }
                } else {
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(inputText.isEmpty ? .secondary : .blue)
                    }
                    .disabled(inputText.isEmpty)
                }
            }
            .padding()
            .background(OpenCodeTheme.surface)
        }
    }
    
    private var filteredCommands: [Command] {
        if inputText.isEmpty || inputText == "/" {
            return viewModel.commands
        }
        let query = inputText.lowercased()
        return viewModel.commands.filter { $0.name.lowercased().contains(query) }
    }
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        inputText = ""
        
        Task {
            if text.hasPrefix("/") {
                // Execute as command
                let parts = text.dropFirst().split(separator: " ", maxSplits: 1)
                let command = "/" + String(parts.first ?? "")
                await viewModel.executeCommand(command)
            } else {
                await viewModel.sendMessage(text)
            }
        }
    }
}

// MARK: - Command Suggestions

struct CommandSuggestionsView: View {
    let commands: [Command]
    let onSelect: (Command) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(commands) { command in
                    Button(action: { onSelect(command) }) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(command.name)
                                .font(.caption)
                                .fontWeight(.medium)
                            Text(command.description)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(OpenCodeTheme.surface)
    }
}
```

---

## Phase 3: Advanced Controls

### 3.1 Model Picker

**File:** `ios-app/VibeRemote/Sources/Views/ModelPickerView.swift`

```swift
import SwiftUI

struct ModelPickerView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.providers) { provider in
                    Section(provider.name) {
                        ForEach(provider.models) { model in
                            Button(action: {
                                viewModel.selectedProvider = provider.id
                                viewModel.selectedModel = model.id
                                dismiss()
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(model.name)
                                            .font(.body)
                                        
                                        if let context = model.contextWindow {
                                            Text("\(context / 1000)K context")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if viewModel.selectedProvider == provider.id &&
                                       viewModel.selectedModel == model.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
```

### 3.2 Status Panel

**File:** `ios-app/VibeRemote/Sources/Views/StatusPanelView.swift`

```swift
import SwiftUI

struct StatusPanelView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Session Stats
                Section("Session Statistics") {
                    StatRow(label: "Messages", value: "\(viewModel.messages.count)")
                    StatRow(label: "Total Tokens", value: "\(totalTokens)")
                    StatRow(label: "Estimated Cost", value: String(format: "$%.4f", totalCost))
                }
                
                // Modified Files
                if !viewModel.diffs.isEmpty {
                    Section("Modified Files (\(viewModel.diffs.count))") {
                        ForEach(viewModel.diffs) { diff in
                            NavigationLink {
                                DiffDetailView(diff: diff)
                            } label: {
                                HStack {
                                    Image(systemName: "doc.badge.ellipsis")
                                        .foregroundStyle(.orange)
                                    Text(URL(fileURLWithPath: diff.file).lastPathComponent)
                                }
                            }
                        }
                    }
                }
                
                // Todo List
                if !viewModel.todos.isEmpty {
                    Section("Todo List") {
                        ForEach(viewModel.todos) { todo in
                            HStack {
                                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(todo.isCompleted ? .green : .secondary)
                                Text(todo.content)
                                    .strikethrough(todo.isCompleted)
                            }
                        }
                    }
                }
                
                // MCP Servers
                Section("MCP Servers") {
                    if viewModel.mcpServers.isEmpty {
                        Text("No MCP servers configured")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(viewModel.mcpServers.values)) { server in
                            HStack {
                                Circle()
                                    .fill(server.isConnected ? .green : .red)
                                    .frame(width: 8, height: 8)
                                
                                Text(server.name)
                                
                                Spacer()
                                
                                if !server.isConnected {
                                    Button("Connect") {
                                        Task {
                                            try? await viewModel.client?.connectMCP(name: server.name)
                                            await viewModel.refreshStatus()
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }
                }
                
                // LSP Status
                Section("Language Servers") {
                    if viewModel.lspStatus.isEmpty {
                        Text("No language servers active")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.lspStatus) { lsp in
                            HStack {
                                Circle()
                                    .fill(lsp.isRunning ? .green : .red)
                                    .frame(width: 8, height: 8)
                                
                                Text(lsp.name)
                                
                                Spacer()
                                
                                if let version = lsp.version {
                                    Text(version)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                
                // Actions
                Section("Actions") {
                    Button("Revert All Changes", role: .destructive) {
                        Task {
                            try? await viewModel.client?.revert(sessionId: viewModel.session.opencodeSessionId ?? "")
                            await viewModel.refreshStatus()
                        }
                    }
                }
            }
            .navigationTitle("Session Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        Task { await viewModel.refreshStatus() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable {
                await viewModel.refreshStatus()
            }
        }
    }
    
    private var totalTokens: Int {
        viewModel.messages.compactMap { $0.info.tokens }.reduce(0) { $0 + $1.input + $1.output }
    }
    
    private var totalCost: Double {
        viewModel.messages.compactMap { $0.info.cost }.reduce(0, +)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

struct DiffDetailView: View {
    let diff: FileDiff
    
    var body: some View {
        ScrollView {
            Text(diff.diff)
                .font(.system(.caption, design: .monospaced))
                .padding()
        }
        .navigationTitle(URL(fileURLWithPath: diff.file).lastPathComponent)
    }
}
```

---

## Phase 4: Status Panels

*(Covered in Phase 3.2 StatusPanelView)*

---

## Phase 5: Polish & Integration

### 5.1 Update ContentView for Routing

**File:** `ios-app/VibeRemote/Sources/ContentView.swift` (MODIFY)

```swift
// Add routing logic to detail view:

} detail: {
    if let session = selectedSession {
        switch session.connectionMode {
        case .api:
            ChatContainerView(session: session)
        case .ssh:
            TerminalContainerView(session: session, onSessionKilled: {
                selectedSession = nil
            })
        }
    } else {
        EmptyStateView()
    }
}
```

### 5.2 Update NewSessionWizard

Add connection mode selection to the session creation flow.

### 5.3 Update SessionSidebarView

Show visual indicator for connection mode (chat bubble vs terminal icon).

---

## File Structure

### New Files to Create

```
ios-app/VibeRemote/Sources/
├── Models/
│   └── OpenCodeModels.swift          # API response types
├── Services/
│   └── OpenCodeClient.swift          # HTTP API client
├── ViewModels/
│   └── ChatViewModel.swift           # Chat state management
└── Views/
    ├── ChatView.swift                # Main chat container
    ├── ChatInputView.swift           # Message input + commands
    ├── MessageBubbleView.swift       # Message display
    ├── ToolCallCardView.swift        # Tool call visualization
    ├── ModelPickerView.swift         # Model/provider selection
    └── StatusPanelView.swift         # Status, todos, diffs, MCP, LSP
```

### Files to Modify

```
ios-app/VibeRemote/Sources/
├── Models/
│   └── AgentSession.swift            # Add connectionMode, apiBaseURL
├── Views/
│   ├── ContentView.swift             # Route to Chat or Terminal
│   ├── SessionSidebarView.swift      # Show connection mode icon
│   └── NewSessionWizard.swift        # Add connection mode picker
└── project.yml                       # Add new files
```

### Files to Keep (SSH Fallback)

```
ios-app/VibeRemote/Sources/
├── Services/
│   └── SSHConnectionManager.swift    # Keep for SSH mode
└── Views/
    └── TerminalView.swift            # Keep for SSH mode
```

---

## API Reference

### Quick Reference Card

```
# Sessions
GET    /session                    → List sessions
POST   /session                    → Create session
GET    /session/:id                → Get session + stats
DELETE /session/:id                → Delete session

# Messages
GET    /session/:id/message        → Get messages
POST   /session/:id/message        → Send message (streaming)
POST   /session/:id/prompt_async   → Send message (background)
DELETE /session/:id/message/:msgId → Delete message
POST   /session/:id/abort          → Stop generation
POST   /session/:id/command        → Execute slash command

# Session Extras
GET    /session/:id/todo           → Get todo list
GET    /session/:id/diff           → Get file diffs
POST   /session/:id/revert         → Revert changes
POST   /session/:id/fork           → Fork session
POST   /session/:id/share          → Share session

# Configuration
GET    /config                     → Get config
GET    /config/providers           → List providers + models
GET    /command                    → List slash commands
GET    /agent                      → List agents

# Status
GET    /mcp                        → MCP server status
POST   /mcp/:name/connect          → Connect MCP
GET    /lsp                        → LSP status
GET    /global/health              → Health check

# Real-time
GET    /event                      → SSE event stream
```

---

## Summary

### What Moves to iOS App

| Feature | API Endpoint | iOS Control |
|---------|--------------|-------------|
| Model selection | `GET /config/providers` | Native `Picker` |
| Provider selection | `GET /config/providers` | Segmented control |
| Slash commands | `GET /command` | Autocomplete popup |
| Token display | Message `info.tokens` | Badge on message |
| Cost display | Message `info.cost` | Header summary |
| Modified files | `GET /session/:id/diff` | List with diff viewer |
| Todo list | `GET /session/:id/todo` | Checklist |
| MCP status | `GET /mcp` | Status cards + connect |
| LSP status | `GET /lsp` | Status indicators |
| Tool calls | Message `parts` | Collapsible cards |
| Stop button | `POST /session/:id/abort` | Floating button |
| Message input | `POST /session/:id/message` | Native `TextField` |

### What Stays on Server

- AI inference (obviously)
- File system access
- Git operations
- MCP server processes
- LSP server processes
- Session persistence

### Result

**OpenCode becomes a headless backend.** The iOS app provides a complete, native UI for all interactions - from model selection to tool call visualization to status monitoring. The terminal is preserved only as a fallback for SSH-only scenarios.

---

*Last updated: January 2026*
