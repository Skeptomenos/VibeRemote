import SwiftData
import Foundation

@Model
final class ServerConfig {
    var id: UUID
    var host: String
    var port: Int
    var username: String
    var sshKeyLabel: String
    
    init(host: String = "", port: Int = 22, username: String = "", sshKeyLabel: String = "viberemote-key") {
        self.id = UUID()
        self.host = host
        self.port = port
        self.username = username
        self.sshKeyLabel = sshKeyLabel
    }
    
    var isConfigured: Bool {
        !host.isEmpty && !username.isEmpty
    }
}
