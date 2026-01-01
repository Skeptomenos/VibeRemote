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
    
    init(name: String, projectPath: String, agentType: AgentType = .opencode, opencodeSessionId: String? = nil, opencodeSessionTitle: String? = nil) {
        self.id = UUID()
        self.name = name
        self.projectPath = projectPath
        self.agentType = agentType
        self.lastActive = Date()
        self.isPinned = false
        self.opencodeSessionId = opencodeSessionId
        self.opencodeSessionTitle = opencodeSessionTitle
    }
    
    var tmuxSessionName: String {
        "vibe-\(id.uuidString.prefix(8).lowercased())"
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
