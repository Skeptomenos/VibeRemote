import XCTest
@testable import VibeRemote

final class OpenCodeModelsTests: XCTestCase {
    
    // MARK: - GatewayProject
    
    func testGatewayProject_decodesFromJSON() throws {
        let json = """
        {
            "name": "my-project",
            "path": "/home/user/projects/my-project",
            "has_git": true,
            "has_package_json": false,
            "is_running": true,
            "port": 8080
        }
        """.data(using: .utf8)!
        
        let project = try JSONDecoder().decode(GatewayProject.self, from: json)
        
        XCTAssertEqual(project.name, "my-project")
        XCTAssertEqual(project.path, "/home/user/projects/my-project")
        XCTAssertTrue(project.hasGit)
        XCTAssertFalse(project.hasPackageJson)
        XCTAssertTrue(project.isRunning)
        XCTAssertEqual(project.port, 8080)
        XCTAssertEqual(project.id, "my-project")
    }
    
    func testGatewayProject_decodesWithNullPort() throws {
        let json = """
        {
            "name": "test",
            "path": "/path",
            "has_git": false,
            "has_package_json": true,
            "is_running": false,
            "port": null
        }
        """.data(using: .utf8)!
        
        let project = try JSONDecoder().decode(GatewayProject.self, from: json)
        
        XCTAssertNil(project.port)
        XCTAssertFalse(project.isRunning)
    }
    
    // MARK: - GatewayStartResponse
    
    func testGatewayStartResponse_decodesFromJSON() throws {
        let json = """
        {
            "name": "my-project",
            "port": 3000,
            "status": "started"
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(GatewayStartResponse.self, from: json)
        
        XCTAssertEqual(response.name, "my-project")
        XCTAssertEqual(response.port, 3000)
        XCTAssertEqual(response.status, "started")
    }
    
    // MARK: - GatewayStopResponse
    
    func testGatewayStopResponse_decodesFromJSON() throws {
        let json = """
        {
            "name": "my-project",
            "status": "stopped"
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(GatewayStopResponse.self, from: json)
        
        XCTAssertEqual(response.name, "my-project")
        XCTAssertEqual(response.status, "stopped")
    }
    
    // MARK: - MessagePart
    
    func testMessagePart_decodesTextPart() throws {
        let json = """
        {
            "type": "text",
            "text": "Hello, world!"
        }
        """.data(using: .utf8)!
        
        let part = try JSONDecoder().decode(MessagePart.self, from: json)
        
        if case .text(let textPart) = part {
            XCTAssertEqual(textPart.text, "Hello, world!")
            XCTAssertEqual(textPart.type, "text")
        } else {
            XCTFail("Expected text part")
        }
    }
    
    func testMessagePart_decodesToolInvocationPart() throws {
        let json = """
        {
            "type": "tool-invocation",
            "toolInvocation": {
                "toolName": "read",
                "toolCallId": "call_123",
                "args": {
                    "filePath": "/path/to/file.swift"
                },
                "state": "completed"
            }
        }
        """.data(using: .utf8)!
        
        let part = try JSONDecoder().decode(MessagePart.self, from: json)
        
        if case .toolInvocation(let toolPart) = part {
            XCTAssertEqual(toolPart.toolInvocation.toolName, "read")
            XCTAssertEqual(toolPart.toolInvocation.toolCallId, "call_123")
            XCTAssertEqual(toolPart.toolInvocation.state, "completed")
            XCTAssertEqual(toolPart.toolInvocation.filePath, "/path/to/file.swift")
        } else {
            XCTFail("Expected tool invocation part")
        }
    }
    
    func testMessagePart_decodesUnknownType() throws {
        let json = """
        {
            "type": "future-type",
            "data": "some data"
        }
        """.data(using: .utf8)!
        
        let part = try JSONDecoder().decode(MessagePart.self, from: json)
        
        if case .unknown = part {
            // Expected
        } else {
            XCTFail("Expected unknown part")
        }
    }
    
    // MARK: - ToolInvocation
    
    func testToolInvocation_displayName() {
        let tools: [(String, String)] = [
            ("read", "Read"),
            ("write", "Write"),
            ("edit", "Edit"),
            ("bash", "Bash"),
            ("glob", "Glob"),
            ("grep", "Grep"),
            ("task", "Task"),
            ("custom_tool", "Custom_Tool")
        ]
        
        for (toolName, expectedDisplayName) in tools {
            let invocation = ToolInvocation(
                toolName: toolName,
                toolCallId: nil,
                args: [:],
                state: "completed"
            )
            XCTAssertEqual(invocation.displayName, expectedDisplayName)
        }
    }
    
    func testToolInvocation_iconName() {
        let tools: [(String, String)] = [
            ("read", "doc.text"),
            ("write", "pencil"),
            ("edit", "pencil"),
            ("bash", "terminal"),
            ("glob", "magnifyingglass"),
            ("grep", "magnifyingglass"),
            ("task", "checklist"),
            ("unknown", "wrench.and.screwdriver")
        ]
        
        for (toolName, expectedIcon) in tools {
            let invocation = ToolInvocation(
                toolName: toolName,
                toolCallId: nil,
                args: [:],
                state: "completed"
            )
            XCTAssertEqual(invocation.iconName, expectedIcon)
        }
    }
    
    // MARK: - OpenCodeMessage
    
    func testOpenCodeMessage_textContent_extractsTextParts() {
        let info = MessageInfo(
            id: "msg_1",
            sessionID: "session_1",
            role: .assistant,
            time: MessageTime(created: 0, completed: nil),
            model: nil,
            cost: nil,
            tokens: nil
        )
        
        let parts: [MessagePart] = [
            .text(TextPart(type: "text", text: "Hello")),
            .text(TextPart(type: "text", text: "World"))
        ]
        
        let message = OpenCodeMessage(info: info, parts: parts)
        
        XCTAssertEqual(message.textContent, "Hello\nWorld")
    }
    
    func testOpenCodeMessage_textContent_withNilParts_returnsEmpty() {
        let info = MessageInfo(
            id: "msg_1",
            sessionID: "session_1",
            role: .assistant,
            time: MessageTime(created: 0, completed: nil),
            model: nil,
            cost: nil,
            tokens: nil
        )
        
        let message = OpenCodeMessage(info: info, parts: nil)
        
        XCTAssertEqual(message.textContent, "")
    }
    
    // MARK: - AnyCodableValue
    
    func testAnyCodableValue_decodesString() throws {
        let json = "\"hello\"".data(using: .utf8)!
        let value = try JSONDecoder().decode(AnyCodableValue.self, from: json)
        XCTAssertEqual(value.stringValue, "hello")
    }
    
    func testAnyCodableValue_decodesInt() throws {
        let json = "42".data(using: .utf8)!
        let value = try JSONDecoder().decode(AnyCodableValue.self, from: json)
        XCTAssertEqual(value.intValue, 42)
    }
    
    func testAnyCodableValue_decodesBool() throws {
        let json = "true".data(using: .utf8)!
        let value = try JSONDecoder().decode(AnyCodableValue.self, from: json)
        XCTAssertEqual(value.boolValue, true)
    }
    
    // MARK: - TokenUsage
    
    func testTokenUsage_total() throws {
        let json = """
        {
            "input": 100,
            "output": 50,
            "reasoning": 25
        }
        """.data(using: .utf8)!
        
        let usage = try JSONDecoder().decode(TokenUsage.self, from: json)
        
        XCTAssertEqual(usage.input, 100)
        XCTAssertEqual(usage.output, 50)
        XCTAssertEqual(usage.total, 150)
    }
    
    // MARK: - ConnectionMode
    
    func testConnectionMode_displayName() {
        XCTAssertEqual(ConnectionMode.api.displayName, "API (Native Chat)")
        XCTAssertEqual(ConnectionMode.ssh.displayName, "SSH (Terminal)")
    }
    
    func testConnectionMode_iconName() {
        XCTAssertEqual(ConnectionMode.api.iconName, "bubble.left.and.bubble.right")
        XCTAssertEqual(ConnectionMode.ssh.iconName, "terminal")
    }
    
    // MARK: - MCPStatus
    
    func testMCPStatus_isConnected() throws {
        let connectedJSON = """
        {
            "name": "mcp-server",
            "connectionStatus": "connected",
            "tools": ["tool1", "tool2"]
        }
        """.data(using: .utf8)!
        
        let disconnectedJSON = """
        {
            "name": "mcp-server",
            "connectionStatus": "disconnected",
            "error": "Connection refused"
        }
        """.data(using: .utf8)!
        
        let connected = try JSONDecoder().decode(MCPStatus.self, from: connectedJSON)
        let disconnected = try JSONDecoder().decode(MCPStatus.self, from: disconnectedJSON)
        
        XCTAssertTrue(connected.isConnected)
        XCTAssertFalse(disconnected.isConnected)
    }
    
    // MARK: - LSPStatus
    
    func testLSPStatus_isRunning() throws {
        let runningJSON = """
        {
            "name": "swift-lsp",
            "status": "running",
            "version": "1.0.0"
        }
        """.data(using: .utf8)!
        
        let stoppedJSON = """
        {
            "name": "swift-lsp",
            "status": "stopped"
        }
        """.data(using: .utf8)!
        
        let running = try JSONDecoder().decode(LSPStatus.self, from: runningJSON)
        let stopped = try JSONDecoder().decode(LSPStatus.self, from: stoppedJSON)
        
        XCTAssertTrue(running.isRunning)
        XCTAssertFalse(stopped.isRunning)
    }
    
    // MARK: - TodoItem
    
    func testTodoItem_isCompleted() throws {
        let completedJSON = """
        {
            "id": "todo_1",
            "content": "Fix bug",
            "status": "completed",
            "priority": "high"
        }
        """.data(using: .utf8)!
        
        let pendingJSON = """
        {
            "id": "todo_2",
            "content": "Add feature",
            "status": "pending",
            "priority": "medium"
        }
        """.data(using: .utf8)!
        
        let completed = try JSONDecoder().decode(TodoItem.self, from: completedJSON)
        let pending = try JSONDecoder().decode(TodoItem.self, from: pendingJSON)
        
        XCTAssertTrue(completed.isCompleted)
        XCTAssertFalse(pending.isCompleted)
    }
    
    // MARK: - AIModel
    
    func testAIModel_contextWindowFormatted() {
        let model1M = AIModel(id: "gpt-4", name: "GPT-4", limit: ModelLimit(context: 1_000_000, output: 4096))
        let model128K = AIModel(id: "gpt-4", name: "GPT-4", limit: ModelLimit(context: 128_000, output: 4096))
        let modelNoLimit = AIModel(id: "gpt-4", name: "GPT-4", limit: nil)
        
        XCTAssertEqual(model1M.contextWindowFormatted, "1M")
        XCTAssertEqual(model128K.contextWindowFormatted, "128K")
        XCTAssertNil(modelNoLimit.contextWindowFormatted)
    }
}
