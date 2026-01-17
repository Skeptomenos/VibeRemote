import SwiftData
import Foundation

@Model
final class ServerConfig {
    var id: UUID
    var host: String
    var port: Int
    var username: String
    var sshKeyLabel: String
    var apiURL: String = ""
    
    init(
        host: String = "",
        port: Int = 22,
        username: String = "",
        sshKeyLabel: String = "viberemote-key",
        apiURL: String = ""
    ) {
        self.id = UUID()
        self.host = host
        self.port = port
        self.username = username
        self.sshKeyLabel = sshKeyLabel
        self.apiURL = apiURL
    }
    
    init(gatewayURL: URL) {
        self.id = UUID()
        self.host = ""
        self.port = 22
        self.username = ""
        self.sshKeyLabel = "viberemote-key"
        self.apiURL = gatewayURL.absoluteString
    }
    
    var isConfigured: Bool {
        !host.isEmpty && !username.isEmpty
    }
    
    var isAPIConfigured: Bool {
        !apiURL.isEmpty && KeychainManager.shared.hasAPIKey()
    }
    
    var gatewayURL: URL? {
        URL(string: apiURL)
    }
}
