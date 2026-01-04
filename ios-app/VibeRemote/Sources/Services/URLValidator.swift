import Foundation

/// Validates gateway URLs for the VibeRemote app
enum URLValidator {
    
    /// Validates if a URL string is a valid gateway URL
    /// - Parameter urlString: The URL string to validate
    /// - Returns: true if the URL is valid (empty strings are considered valid but incomplete)
    static func isValid(_ urlString: String) -> Bool {
        guard !urlString.isEmpty else { return true } // Empty is valid (just not complete)
        guard let url = URL(string: urlString) else { return false }
        guard let scheme = url.scheme?.lowercased() else { return false }
        return (scheme == "http" || scheme == "https") && url.host != nil
    }
    
    /// Returns a validation error message for an invalid URL, or nil if valid
    /// - Parameter urlString: The URL string to validate
    /// - Returns: An error message string, or nil if the URL is valid
    static func validationMessage(for urlString: String) -> String? {
        guard !urlString.isEmpty else { return nil }
        
        guard let url = URL(string: urlString) else {
            return "Invalid URL format"
        }
        
        if url.scheme == nil {
            return "URL must start with http:// or https://"
        }
        
        if let scheme = url.scheme?.lowercased(), scheme != "http" && scheme != "https" {
            return "URL must use http:// or https://"
        }
        
        if url.host == nil {
            return "URL must include a host"
        }
        
        return nil
    }
}
