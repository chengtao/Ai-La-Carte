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
    var deviceIdentifierService: DeviceIdentifierServiceProtocol { get }

    // API Services
    var restaurantAPIService: RestaurantAPIServiceProtocol { get }
    var sessionAPIService: SessionAPIServiceProtocol { get }
    var recommendationAPIService: RecommendationAPIServiceProtocol { get }

    // Device Services
    var locationService: LocationServiceProtocol { get }
    var cameraService: CameraServiceProtocol { get }
    var analyticsService: AnalyticsServiceProtocol { get }

    // Local Engines
    var recommendationEngine: RecommendationEngineProtocol { get }

    // Utilities
    var imageCacheService: ImageCacheServiceProtocol { get }
    var userPreferencesStorage: UserPreferencesStorageProtocol { get }

    // Preference Manager (centralized preference state)
    var preferenceManager: PreferenceManagerProtocol { get }

    // ViewModel Factory Methods (MainActor since ViewModels are @MainActor)
    @MainActor func makeWelcomeViewModel() -> WelcomeViewModel
    @MainActor func makeMainViewModel() -> MainViewModel
    @MainActor func makeCameraViewModel() -> CameraViewModel
    @MainActor func makeLocationViewModel() -> LocationViewModel
    @MainActor func makeSessionViewModel() -> SessionViewModel
    @MainActor func makePhotoReviewViewModel(sessionId: String, photo: UIImage) -> PhotoReviewViewModel
    @MainActor func makePhotoCarouselReviewViewModel(photos: [CapturedPhoto], sessionId: String?) -> PhotoCarouselReviewViewModel
    @MainActor func makeCalculatingViewModel(sessionId: String, jobId: String, preferences: UserPreferences) -> CalculatingViewModel
    @MainActor func makeRecommendationViewModel(sessionId: String, preferences: UserPreferences) -> RecommendationViewModel
    @MainActor func makeSurveyViewModel(sessionId: String, items: [ScoredFoodItem]) -> SurveyViewModel
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

protocol RestaurantAPIServiceProtocol: Sendable {
    func getNearbyRestaurants(lat: Double, lon: Double, radius: Int) async throws -> [RestaurantResponse]
}

protocol SessionAPIServiceProtocol: Sendable {
    /// Registers a locally-created session with the server
    func registerSession(sessionId: String) async throws
    /// Updates the session's location (call when location is acquired or improved)
    func updateSessionLocation(sessionId: String, lat: Double, lon: Double) async throws
    /// Sets the restaurant for this session
    func pickRestaurant(sessionId: String, restaurantId: String) async throws
    /// Uploads a photo to the session
    func uploadPhoto(sessionId: String, imageData: Data) async throws -> PhotoUploadResponse
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

// MARK: - Recommendation Engine Protocol

/// Protocol for local recommendation scoring engine.
/// Calculates confidence scores for food and wine items based on user preferences.
protocol RecommendationEngineProtocol: Sendable {
    /// Score food items based on user preferences
    /// - Parameters:
    ///   - items: Raw food items from the server
    ///   - preferences: User's current food preferences
    /// - Returns: Scored food items sorted by confidence (highest first)
    func scoreFood(
        items: [FoodItemResponse],
        preferences: FoodPreference
    ) -> [ScoredFoodItem]

    /// Score wine items based on user preferences
    /// - Parameters:
    ///   - items: Raw wine items from the server
    ///   - preferences: User's current food preferences
    /// - Returns: Scored wine items sorted by confidence (highest first)
    func scoreWine(
        items: [WineItemResponse],
        preferences: FoodPreference
    ) -> [ScoredWineItem]
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
