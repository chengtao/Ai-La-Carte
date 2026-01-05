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
    var menuAPIService: MenuAPIServiceProtocol { get }

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
    @MainActor func makeCalculatingViewModel(sessionId: String, mode: CalculationMode, preferences: UserPreferences) -> CalculatingViewModel
    @MainActor func makeRecommendationViewModel(sessionId: String, foodMenuId: String?, wineMenuId: String?, preferences: UserPreferences) -> RecommendationViewModel
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
    /// Uploads a photo to the session
    func uploadPhoto(sessionId: String, imageData: Data) async throws -> PhotoUploadResponse
}

protocol MenuAPIServiceProtocol: Sendable {
    /// Creates menus from uploaded photos for a session
    func createMenus(sessionId: String, lat: Double?, lon: Double?) async throws -> JobResponse
    /// Gets the status of menu creation job
    func getMenusCreationStatus(jobId: String) async throws -> JobStatusResponse
    /// Gets menus by their IDs
    func getMenus(foodMenuId: String?, wineMenuId: String?) async throws -> RecommendationResponse
    /// Submit feedback for a menu item
    func submitFeedback(sessionId: String, itemId: String, rating: FeedbackRating) async throws
}

protocol LocationServiceProtocol: Sendable {
    var authorizationStatus: LocationAuthorizationStatus { get }
    func requestWhenInUseAuthorization() async -> LocationAuthorizationStatus
    func getCurrentLocation() async throws -> LocationCoordinate
}

protocol CameraServiceProtocol: Sendable {
    var authorizationStatus: CameraAuthorizationStatus { get }
    var isTorchAvailable: Bool { get }
    var isTorchOn: Bool { get }
    func requestAuthorization() async -> CameraAuthorizationStatus
    func startSession() async throws
    func stopSession()
    func capturePhoto() async throws -> UIImage
    func setTorch(on: Bool) throws
    func toggleTorch() throws
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

/// Mode for the calculating view - either artificial delay (for nearby restaurants) or real polling
enum CalculationMode: Sendable {
    /// Artificial delay when restaurant has existing menus
    case artificialDelay(foodMenuId: String?, wineMenuId: String?)
    /// Real polling for photo scan flow
    case polling(jobId: String)
}

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
