import Citadel
import Crypto
import Foundation

@main
struct SSHTest {
    static func main() async throws {
        print("Testing SSH connection with Citadel...")
        print("")
        
        // Create a fresh key and show it
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        
        let keyBlob = formatOpenSSHPublicKey(publicKey: publicKey)
        print("Add this key to ~/.ssh/authorized_keys:")
        print(keyBlob)
        print("")
        
        // Auto-add the key
        let authKeysPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh/authorized_keys")
        if let handle = try? FileHandle(forWritingTo: authKeysPath) {
            handle.seekToEndOfFile()
            handle.write("\n\(keyBlob)\n".data(using: .utf8)!)
            handle.closeFile()
            print("Key auto-added to authorized_keys")
        } else {
            print("Could not auto-add key. Add it manually and press Enter...")
            _ = readLine()
        }
        
        print("")
        print("Connecting to 127.0.0.1:22 as davidhelmus...")
        
        do {
            let client = try await SSHClient.connect(
                host: "127.0.0.1",
                port: 22,
                authenticationMethod: .ed25519(
                    username: "davidhelmus",
                    privateKey: privateKey
                ),
                hostKeyValidator: .acceptAnything(),
                reconnect: .never
            )
            print("SUCCESS! Connected!")
            
            let result = try await client.executeCommand("echo 'Hello from Citadel SSH!'")
            print("Command output: \(String(buffer: result))")
            
            try await client.close()
            print("Disconnected.")
        } catch {
            print("")
            print("CONNECTION FAILED!")
            print("Error type: \(type(of: error))")
            print("Error: \(error)")
            print("")
            print("Debug info:")
            print("- Key type: Ed25519")
            print("- Key size: \(privateKey.rawRepresentation.count) bytes")
            print("- Public key size: \(publicKey.rawRepresentation.count) bytes")
        }
    }
    
    static func formatOpenSSHPublicKey(publicKey: Curve25519.Signing.PublicKey) -> String {
        let keyType = "ssh-ed25519"
        let keyTypeData = keyType.data(using: .utf8)!
        let publicKeyRaw = publicKey.rawRepresentation
        
        var blob = Data()
        var keyTypeLength = UInt32(keyTypeData.count).bigEndian
        blob.append(Data(bytes: &keyTypeLength, count: 4))
        blob.append(keyTypeData)
        
        var publicKeyLength = UInt32(publicKeyRaw.count).bigEndian
        blob.append(Data(bytes: &publicKeyLength, count: 4))
        blob.append(publicKeyRaw)
        
        return "\(keyType) \(blob.base64EncodedString()) sshtest@mac"
    }
}
