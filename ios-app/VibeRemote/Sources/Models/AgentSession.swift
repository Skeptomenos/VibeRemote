import SwiftData
import Foundation

@Model
final class AgentSession {
    var id: UUID
    var name: String
    var projectPath: String
    var agentType: AgentType
    var lastActive: Date
    var isPinned: Bool
    var opencodeSessionId: String?
    var opencodeSessionTitle: String?
    var connectionModeRaw: String = "api"
    var defaultProviderID: String?
    var defaultModelID: String?
    
    init(
        name: String,
        projectPath: String,
        agentType: AgentType = .opencode,
        connectionMode: ConnectionMode = .api,
        opencodeSessionId: String? = nil,
        opencodeSessionTitle: String? = nil,
        defaultProviderID: String? = nil,
        defaultModelID: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.projectPath = projectPath
        self.agentType = agentType
        self.connectionModeRaw = connectionMode.rawValue
        self.lastActive = Date()
        self.isPinned = false
        self.opencodeSessionId = opencodeSessionId
        self.opencodeSessionTitle = opencodeSessionTitle
        self.defaultProviderID = defaultProviderID
        self.defaultModelID = defaultModelID
    }
    
    var connectionMode: ConnectionMode {
        get { ConnectionMode(rawValue: connectionModeRaw) ?? .api }
        set { connectionModeRaw = newValue.rawValue }
    }
    
    var tmuxSessionName: String {
        "vibe-\(id.uuidString.prefix(8).lowercased())"
    }
    
    var projectName: String {
        URL(fileURLWithPath: projectPath).lastPathComponent
    }
    
    var connectionIcon: String {
        connectionMode.iconName
    }
}

enum AgentType: String, Codable, CaseIterable {
    case opencode = "opencode"
    case claude = "claude"
    case shell = "shell"
    
    var displayName: String {
        switch self {
        case .opencode: return "OpenCode"
        case .claude: return "Claude"
        case .shell: return "Shell"
        }
    }
    
    var iconName: String {
        switch self {
        case .opencode: return "cpu"
        case .claude: return "brain"
        case .shell: return "terminal"
        }
    }
}
