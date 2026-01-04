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
        
        let publicKeyBase64 = publicKey.rawRepresentation.base64EncodedString()
        return "ssh-ed25519 \(publicKeyBase64) viberemote@ios"
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
