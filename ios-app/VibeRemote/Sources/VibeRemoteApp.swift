import SwiftUI
import SwiftData

@main
struct VibeRemoteApp: App {
    @State private var versionManager = OpenCodeVersionManager()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            AgentSession.self,
            ServerConfig.self,
            SessionSnapshot.self,
            UserPreferences.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(versionManager)
                .preferredColorScheme(.dark)
                .tint(OpenCodeTheme.primary)
                .task {
                    SessionCleanupManager.shared.configure(with: sharedModelContainer.mainContext)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
