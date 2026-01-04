import Foundation
import Security
import CryptoKit

class KeychainManager {
    static let shared = KeychainManager()
    private init() {}
    
    func generateKeyPair(label: String) throws -> String {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        
        try storePrivateKey(privateKey.rawRepresentation, label: label)
        
        // Format public key in OpenSSH format
        let publicKeySSH = formatOpenSSHPublicKey(publicKey: publicKey)
        return publicKeySSH
    }
    
    /// Formats a Curve25519 public key in OpenSSH format
    /// Format: "ssh-ed25519 <base64-encoded-key-blob> <comment>"
    /// The key blob is: length(4 bytes) + "ssh-ed25519" + length(4 bytes) + raw-public-key(32 bytes)
    private func formatOpenSSHPublicKey(publicKey: Curve25519.Signing.PublicKey) -> String {
        let keyType = "ssh-ed25519"
        let keyTypeData = keyType.data(using: .utf8)!
        let publicKeyRaw = publicKey.rawRepresentation
        
        var blob = Data()
        
        // Append key type with length prefix (big-endian UInt32)
        var keyTypeLength = UInt32(keyTypeData.count).bigEndian
        blob.append(Data(bytes: &keyTypeLength, count: 4))
        blob.append(keyTypeData)
        
        // Append public key with length prefix (big-endian UInt32)
        var publicKeyLength = UInt32(publicKeyRaw.count).bigEndian
        blob.append(Data(bytes: &publicKeyLength, count: 4))
        blob.append(publicKeyRaw)
        
        let base64Key = blob.base64EncodedString()
        return "\(keyType) \(base64Key) viberemote@ios"
    }
    
    func getPublicKeyString(label: String) throws -> String {
        let privateKeyData = try getPrivateKey(label: label)
        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData)
        return formatOpenSSHPublicKey(publicKey: privateKey.publicKey)
    }
    
    func storePrivateKey(_ keyData: Data, label: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: label,
            kSecAttrService as String: "com.viberemote.sshkey",
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unableToStore
        }
    }
    
    func getPrivateKey(label: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: label,
            kSecAttrService as String: "com.viberemote.sshkey",
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.keyNotFound
        }
        
        return data
    }
    
    func hasKey(label: String) -> Bool {
        do {
            _ = try getPrivateKey(label: label)
            return true
        } catch {
            return false
        }
    }
    
    func deleteKey(label: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: label,
            kSecAttrService as String: "com.viberemote.sshkey"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unableToDelete
        }
    }
    
    private static let apiKeyService = "com.viberemote.apikey"
    private static let apiKeyAccount = "gateway-api-key"
    
    func storeAPIKey(_ key: String) throws {
        guard let keyData = key.data(using: .utf8) else {
            throw KeychainError.unableToStore
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.apiKeyAccount,
            kSecAttrService as String: Self.apiKeyService,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unableToStore
        }
    }
    
    func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.apiKeyAccount,
            kSecAttrService as String: Self.apiKeyService,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    func hasAPIKey() -> Bool {
        getAPIKey() != nil
    }
    
    func deleteAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.apiKeyAccount,
            kSecAttrService as String: Self.apiKeyService
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unableToDelete
        }
    }
}

enum KeychainError: LocalizedError {
    case unableToStore
    case keyNotFound
    case unableToDelete
    
    var errorDescription: String? {
        switch self {
        case .unableToStore: return "Unable to store key in Keychain."
        case .keyNotFound: return "SSH key not found. Please generate a new key."
        case .unableToDelete: return "Unable to delete key from Keychain."
        }
    }
}
