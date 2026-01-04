//
//  NetworkManager.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation

// MARK: - Network Configuration

struct NetworkConfiguration: Sendable {
    let baseURL: String
    let timeout: TimeInterval
    let retryAttempts: Int
    let retryDelay: TimeInterval

    static let `default` = NetworkConfiguration(
        baseURL: "https://api.ailacarte.app",
        timeout: 30,
        retryAttempts: 3,
        retryDelay: 1
    )

    static let mock = NetworkConfiguration(
        baseURL: "https://mock.ailacarte.app",
        timeout: 5,
        retryAttempts: 1,
        retryDelay: 0.1
    )
}

// MARK: - Network Manager Protocol

protocol NetworkManagerProtocol: Sendable {
    func request<T: Codable>(
        endpoint: APIEndpoint,
        method: HTTPMethod,
        body: Data?
    ) async throws -> T

    func requestWithoutResponse(
        endpoint: APIEndpoint,
        method: HTTPMethod,
        body: Data?
    ) async throws

    func uploadPhoto(
        endpoint: APIEndpoint,
        imageData: Data,
        fileName: String
    ) async throws -> PhotoUploadResponse
}

// MARK: - Protocol Extensions with Default Values

extension NetworkManagerProtocol {
    func request<T: Codable>(
        endpoint: APIEndpoint,
        method: HTTPMethod = .GET,
        body: Data? = nil
    ) async throws -> T {
        return try await request(endpoint: endpoint, method: method, body: body)
    }

    func requestWithoutResponse(
        endpoint: APIEndpoint,
        method: HTTPMethod = .GET,
        body: Data? = nil
    ) async throws {
        return try await requestWithoutResponse(endpoint: endpoint, method: method, body: body)
    }
}

// MARK: - Network Manager Implementation

final class NetworkManager: NetworkManagerProtocol, Sendable {
    private let configuration: NetworkConfiguration
    private let session: URLSession

    init(configuration: NetworkConfiguration = .default) {
        self.configuration = configuration

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout * 2
        self.session = URLSession(configuration: sessionConfig)
    }

    func request<T: Codable>(
        endpoint: APIEndpoint,
        method: HTTPMethod,
        body: Data?
    ) async throws -> T {
        guard let url = URL(string: "\(configuration.baseURL)\(endpoint.path)") else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add authorization header if token exists
        if let token = KeychainHelper.load(key: AppConstants.Storage.Keychain.authTokenKey) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Add device ID header
        let deviceId = KeychainHelper.getOrCreateDeviceId()
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")

        if let body = body {
            request.httpBody = body
        }

        let (data, response) = try await performRequestWithRetry(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        try handleStatusCode(httpResponse.statusCode, data: data)

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch let decodingError as DecodingError {
            throw NetworkError.decodingError(extractDecodingErrorContext(decodingError))
        } catch {
            throw NetworkError.decodingError(error.localizedDescription)
        }
    }

    func requestWithoutResponse(
        endpoint: APIEndpoint,
        method: HTTPMethod,
        body: Data?
    ) async throws {
        guard let url = URL(string: "\(configuration.baseURL)\(endpoint.path)") else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = KeychainHelper.load(key: AppConstants.Storage.Keychain.authTokenKey) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let deviceId = KeychainHelper.getOrCreateDeviceId()
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")

        if let body = body {
            request.httpBody = body
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        try handleStatusCode(httpResponse.statusCode, data: data)
    }

    func uploadPhoto(
        endpoint: APIEndpoint,
        imageData: Data,
        fileName: String
    ) async throws -> PhotoUploadResponse {
        guard let url = URL(string: "\(configuration.baseURL)\(endpoint.path)") else {
            throw NetworkError.invalidURL
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.POST.rawValue
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = KeychainHelper.load(key: AppConstants.Storage.Keychain.authTokenKey) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let deviceId = KeychainHelper.getOrCreateDeviceId()
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        try handleStatusCode(httpResponse.statusCode, data: data)

        return try JSONDecoder().decode(PhotoUploadResponse.self, from: data)
    }

    // MARK: - Private Methods

    private func performRequestWithRetry(_ request: URLRequest) async throws -> (Data, URLResponse) {
        var lastError: Error?

        for attempt in 1...configuration.retryAttempts {
            do {
                return try await session.data(for: request)
            } catch {
                lastError = error

                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .badURL, .unsupportedURL, .cancelled:
                        throw error
                    default:
                        break
                    }
                }

                if attempt < configuration.retryAttempts {
                    try await Task.sleep(nanoseconds: UInt64(configuration.retryDelay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? NetworkError.unknown(nil)
    }

    private func handleStatusCode(_ statusCode: Int, data: Data) throws {
        switch statusCode {
        case 200...299:
            return
        case 400:
            let errorMessage = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw NetworkError.badRequest(errorMessage?.displayMessage)
        case 401:
            let errorMessage = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw NetworkError.unauthorized(errorMessage?.displayMessage)
        case 404:
            let errorMessage = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw NetworkError.notFound(errorMessage?.displayMessage)
        case 422:
            if let errorResponse = try? JSONDecoder().decode(ValidationErrorResponse.self, from: data) {
                throw NetworkError.validationError(errorResponse.errors)
            }
            let errorMessage = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw NetworkError.validationError([errorMessage?.displayMessage ?? "Validation error"])
        case 500...599:
            let errorMessage = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw NetworkError.serverError(errorMessage?.displayMessage)
        default:
            let errorMessage = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw NetworkError.unknown(errorMessage?.displayMessage)
        }
    }
}

// MARK: - HTTP Method

enum HTTPMethod: String, Sendable {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

// MARK: - API Endpoints

enum APIEndpoint: Sendable {
    // Restaurants
    case nearbyRestaurants(lat: Double, lon: Double, radius: Int)

    // Sessions
    case registerSession
    case updateSessionLocation(sessionId: String)
    case pickRestaurant(sessionId: String)
    case uploadPhoto(sessionId: String)

    // Recommendations
    case generateRecommendations(sessionId: String)
    case recommendationStatus(sessionId: String, jobId: String)
    case getRecommendations(sessionId: String)

    // Events & Feedback
    case trackEvent
    case submitFeedback(sessionId: String)

    var path: String {
        switch self {
        case .nearbyRestaurants(let lat, let lon, let radius):
            return "/restaurants/nearby?lat=\(lat)&lon=\(lon)&radius_m=\(radius)"
        case .registerSession:
            return "/sessions"
        case .updateSessionLocation(let sessionId):
            return "/sessions/\(sessionId)/location"
        case .pickRestaurant(let sessionId):
            return "/sessions/\(sessionId)/restaurant"
        case .uploadPhoto(let sessionId):
            return "/sessions/\(sessionId)/photos"
        case .generateRecommendations(let sessionId):
            return "/sessions/\(sessionId)/recommendations:generate"
        case .recommendationStatus(let sessionId, let jobId):
            return "/sessions/\(sessionId)/recommendations/status?job_id=\(jobId)"
        case .getRecommendations(let sessionId):
            return "/sessions/\(sessionId)/recommendations"
        case .trackEvent:
            return "/events"
        case .submitFeedback(let sessionId):
            return "/sessions/\(sessionId)/feedback"
        }
    }
}

// MARK: - Network Error

enum NetworkError: Error, LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case badRequest(String?)
    case unauthorized(String?)
    case notFound(String?)
    case validationError([String])
    case serverError(String?)
    case decodingError(String)
    case unknown(String?)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .badRequest(let message):
            return message ?? "Bad request"
        case .unauthorized(let message):
            return message ?? "Unauthorized access"
        case .notFound(let message):
            return message ?? "Resource not found"
        case .validationError(let errors):
            return errors.joined(separator: ", ")
        case .serverError(let message):
            return message ?? "Server error"
        case .decodingError(let details):
            return "Data decoding error: \(details)"
        case .unknown(let message):
            return message ?? "Unknown error occurred"
        }
    }
}

// MARK: - API Response Models

struct ValidationErrorResponse: Codable, Sendable {
    let errors: [String]
}

struct ErrorResponse: Codable, Sendable {
    let message: String?
    let error: String?

    var displayMessage: String? {
        message ?? error
    }
}

struct APIResponse<T: Codable & Sendable>: Codable, Sendable {
    let data: T
    let message: String?
}

struct OkResponse: Codable, Sendable {
    let ok: Bool
}

// MARK: - Decoding Error Helper

func extractDecodingErrorContext(_ error: DecodingError) -> String {
    switch error {
    case .typeMismatch(let type, let context):
        let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
        return "Type mismatch for '\(path)': expected \(type)"
    case .valueNotFound(let type, let context):
        let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
        return "Missing value for '\(path)': expected \(type)"
    case .keyNotFound(let key, let context):
        let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
        let fullPath = path.isEmpty ? key.stringValue : "\(path).\(key.stringValue)"
        return "Missing key '\(fullPath)'"
    case .dataCorrupted(let context):
        let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
        return "Data corrupted at '\(path)': \(context.debugDescription)"
    @unknown default:
        return "Unknown decoding error"
    }
}
