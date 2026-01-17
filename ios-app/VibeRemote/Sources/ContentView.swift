import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        MainNavigationView()
    }
}

struct APINotConfiguredView: View {
    let onOpenSettings: () -> Void
    
    var body: some View {
        ContentUnavailableView {
            Label("API Not Configured", systemImage: "gear.badge.xmark")
        } description: {
            Text("Configure your Gateway URL and API Key in Settings to use the native chat interface.")
        } actions: {
            Button("Open Settings", action: onOpenSettings)
                .buttonStyle(.borderedProminent)
        }
    }
}
