import SwiftData
import Foundation

@Model
final class UserPreferences {
    var id: UUID
    var launchBehaviorRaw: String = "lastSession"
    var sidebarPinned: Bool
    var hasCompletedOnboarding: Bool
    var defaultProjectPath: String?
    
    init() {
        self.id = UUID()
        self.launchBehaviorRaw = LaunchBehavior.lastSession.rawValue
        self.sidebarPinned = false
        self.hasCompletedOnboarding = false
        self.defaultProjectPath = nil
    }
    
    var launchBehavior: LaunchBehavior {
        get { LaunchBehavior(rawValue: launchBehaviorRaw) ?? .lastSession }
        set { launchBehaviorRaw = newValue.rawValue }
    }
}

enum LaunchBehavior: String, Codable, CaseIterable {
    case masterFavorite
    case lastSession
    case newTemporary
    
    var displayName: String {
        switch self {
        case .masterFavorite: return "Favorite Session"
        case .lastSession: return "Last Session"
        case .newTemporary: return "New Session"
        }
    }
}
