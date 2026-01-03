//
//  DependencyContainer.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Dependency Container Protocol

protocol DependencyContainer: Sendable {
    // Core Services
    var networkManager: NetworkManagerProtocol { get }

    // API Services
    var userAPIService: UserAPIServiceProtocol { get }
    var restaurantAPIService: RestaurantAPIServiceProtocol { get }
    var sessionAPIService: SessionAPIServiceProtocol { get }
    var recommendationAPIService: RecommendationAPIServiceProtocol { get }

    // Device Services
    var locationService: LocationServiceProtocol { get }
    var cameraService: CameraServiceProtocol { get }
    var analyticsService: AnalyticsServiceProtocol { get }

    // Utilities
    var imageCacheService: ImageCacheServiceProtocol { get }

    // ViewModel Factory Methods (MainActor since ViewModels are @MainActor)
    @MainActor func makeWelcomeViewModel() -> WelcomeViewModel
    @MainActor func makeMainViewModel() -> MainViewModel
    @MainActor func makePhotoReviewViewModel(sessionId: String, photo: UIImage) -> PhotoReviewViewModel
    @MainActor func makeSessionPreferenceViewModel(sessionId: String) -> SessionPreferenceViewModel
    @MainActor func makeCalculatingViewModel(sessionId: String, jobId: String) -> CalculatingViewModel
    @MainActor func makeRecommendationViewModel(sessionId: String) -> RecommendationViewModel
    @MainActor func makeSurveyViewModel(sessionId: String, items: [RecommendationItemResponse]) -> SurveyViewModel
}

// MARK: - Environment Key

private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue: DependencyContainer = MockDependencyContainer()
}

extension EnvironmentValues {
    var dependencyContainer: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

// MARK: - Service Protocols

protocol UserAPIServiceProtocol: Sendable {
    func signInWithApple(identityToken: String) async throws -> UserResponse
    func signOut() async throws
    func deleteAccount() async throws
    func getCurrentUser() async throws -> UserResponse?
}

protocol RestaurantAPIServiceProtocol: Sendable {
    func getNearbyRestaurants(lat: Double, lon: Double, radius: Int) async throws -> [RestaurantResponse]
}

protocol SessionAPIServiceProtocol: Sendable {
    func createSession(restaurantId: String?, context: SessionContext?) async throws -> SessionResponse
    func uploadPhoto(sessionId: String, imageData: Data) async throws -> PhotoUploadResponse
    func submitPreferences(sessionId: String, preferences: SessionPreference) async throws
}

protocol RecommendationAPIServiceProtocol: Sendable {
    func generateRecommendations(sessionId: String, includeReviews: Bool) async throws -> JobResponse
    func getRecommendationStatus(sessionId: String, jobId: String) async throws -> JobStatusResponse
    func getRecommendations(sessionId: String) async throws -> RecommendationResponse
    func submitFeedback(sessionId: String, itemId: String, rating: FeedbackRating) async throws
}

protocol LocationServiceProtocol: Sendable {
    var authorizationStatus: LocationAuthorizationStatus { get }
    func requestWhenInUseAuthorization() async -> LocationAuthorizationStatus
    func getCurrentLocation() async throws -> LocationCoordinate
}

protocol CameraServiceProtocol: Sendable {
    var authorizationStatus: CameraAuthorizationStatus { get }
    func requestAuthorization() async -> CameraAuthorizationStatus
    func startSession() async throws
    func stopSession()
    func capturePhoto() async throws -> UIImage
}

protocol AnalyticsServiceProtocol: Sendable {
    func track(event: AnalyticsEventType, sessionId: String?, meta: [String: String]?)
}

protocol ImageCacheServiceProtocol: Sendable {
    func loadImage(from url: URL) async -> UIImage?
    func cacheImage(_ image: UIImage, for url: URL) async
    func clearCache() async
}

// MARK: - Supporting Types

struct SessionContext: Codable, Sendable {
    let lat: Double?
    let lon: Double?
}

struct JobResponse: Codable, Sendable {
    let jobId: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
    }
}

enum LocationAuthorizationStatus: Sendable {
    case notDetermined
    case restricted
    case denied
    case authorizedWhenInUse
    case authorizedAlways

    var isAuthorized: Bool {
        switch self {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }
}

enum CameraAuthorizationStatus: Sendable {
    case notDetermined
    case restricted
    case denied
    case authorized

    var isAuthorized: Bool {
        self == .authorized
    }
}

struct LocationCoordinate: Sendable {
    let latitude: Double
    let longitude: Double
}
