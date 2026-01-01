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
    
    init(name: String, projectPath: String, agentType: AgentType = .opencode) {
        self.id = UUID()
        self.name = name
        self.projectPath = projectPath
        self.agentType = agentType
        self.lastActive = Date()
        self.isPinned = false
    }
    
    var tmuxSessionName: String {
        name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
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
