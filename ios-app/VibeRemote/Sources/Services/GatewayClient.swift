import Foundation
import os.log

private let logger = Logger(subsystem: "com.vibeRemote.app", category: "GatewayClient")

actor GatewayClient {
    private let baseURL: URL
    private let apiKey: String
    private let session: URLSession
    
    init(baseURL: URL, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    private func authorizedRequest(for url: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
    
    func healthCheck() async throws -> Bool {
        let url = baseURL.appendingPathComponent("health")
        let request = authorizedRequest(for: url)
        let (_, response) = try await session.data(for: request)
        return (response as? HTTPURLResponse)?.statusCode == 200
    }
    
    func listProjects() async throws -> [GatewayProject] {
        let url = baseURL.appendingPathComponent("projects")
        let request = authorizedRequest(for: url)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GatewayError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw GatewayError.unauthorized
        }
        
        guard httpResponse.statusCode == 200 else {
            throw GatewayError.serverError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode([GatewayProject].self, from: data)
    }
    
    func startProject(_ name: String) async throws -> GatewayStartResponse {
        let url = baseURL.appendingPathComponent("projects/\(name)/start")
        let request = authorizedRequest(for: url, method: "POST")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GatewayError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw GatewayError.unauthorized
        }
        
        if httpResponse.statusCode == 404 {
            throw GatewayError.projectNotFound(name)
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GatewayError.startFailed(errorMessage)
        }
        
        return try JSONDecoder().decode(GatewayStartResponse.self, from: data)
    }
    
    func stopProject(_ name: String) async throws -> GatewayStopResponse {
        let url = baseURL.appendingPathComponent("projects/\(name)/stop")
        let request = authorizedRequest(for: url, method: "DELETE")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GatewayError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GatewayError.stopFailed(errorMessage)
        }
        
        return try JSONDecoder().decode(GatewayStopResponse.self, from: data)
    }
    
    func projectStatus(_ name: String) async throws -> GatewayProject {
        let url = baseURL.appendingPathComponent("projects/\(name)/status")
        let request = authorizedRequest(for: url)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GatewayError.invalidResponse
        }
        
        if httpResponse.statusCode == 404 {
            throw GatewayError.projectNotFound(name)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw GatewayError.serverError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(GatewayProject.self, from: data)
    }
    
    func openCodeAPIURL(for projectName: String) -> URL {
        baseURL.appendingPathComponent("projects/\(projectName)/api")
    }
}

enum GatewayError: LocalizedError {
    case invalidResponse
    case unauthorized
    case serverError(Int)
    case projectNotFound(String)
    case startFailed(String)
    case stopFailed(String)
    case connectionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from gateway"
        case .unauthorized:
            return "Invalid API key. Check your settings."
        case .serverError(let code):
            return "Server error (HTTP \(code))"
        case .projectNotFound(let name):
            return "Project '\(name)' not found"
        case .startFailed(let message):
            return "Failed to start OpenCode: \(message)"
        case .stopFailed(let message):
            return "Failed to stop OpenCode: \(message)"
        case .connectionFailed:
            return "Cannot connect to gateway"
        }
    }
}
