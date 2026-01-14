//
//  AppDependencyContainer.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation
import SwiftUI
import SwiftData

final class AppDependencyContainer: DependencyContainer, Sendable {
    private nonisolated(unsafe) let modelContext: ModelContext

    // MARK: - Core Services
    let networkManager: NetworkManagerProtocol
    let deviceIdentifierService: DeviceIdentifierServiceProtocol

    // MARK: - API Services
    let restaurantAPIService: RestaurantAPIServiceProtocol
    let sessionAPIService: SessionAPIServiceProtocol
    let menuAPIService: MenuAPIServiceProtocol

    // MARK: - Device Services
    let locationService: LocationServiceProtocol
    let cameraService: CameraServiceProtocol
    let analyticsService: AnalyticsServiceProtocol

    // MARK: - Local Engines
    let recommendationEngine: RecommendationEngineProtocol

    // MARK: - Utilities
    let imageCacheService: ImageCacheServiceProtocol
    let userPreferencesStorage: UserPreferencesStorageProtocol
    let preferenceManager: PreferenceManagerProtocol

    init(modelContext: ModelContext) {
        self.modelContext = modelContext

        // Initialize core services first
        self.networkManager = NetworkManager(configuration: .development)
        self.deviceIdentifierService = DeviceIdentifierService()

        // Initialize API services (depend on networkManager)
        self.restaurantAPIService = RestaurantAPIService(networkManager: networkManager)
        self.sessionAPIService = SessionAPIService(networkManager: networkManager)
        self.menuAPIService = MenuAPIService(networkManager: networkManager)

        // Initialize device services
        self.locationService = LocationService()
        self.cameraService = CameraService()
        self.analyticsService = AnalyticsService(networkManager: networkManager, deviceIdentifierService: deviceIdentifierService)

        // Initialize local engines
        self.recommendationEngine = RecommendationEngine()

        // Initialize utilities
        self.imageCacheService = ImageCacheService()
        self.userPreferencesStorage = UserPreferencesStorage()
        self.preferenceManager = PreferenceManager(storage: userPreferencesStorage)
        // Note: loadPreferences must be called on MainActor
        // This will be called when first accessed in a MainActor context
    }

    // MARK: - ViewModel Factory Methods

    @MainActor func makeWelcomeViewModel() -> WelcomeViewModel {
        WelcomeViewModel(locationService: locationService, cameraService: cameraService)
    }

    @MainActor func makeCameraViewModel() -> CameraViewModel {
        CameraViewModel(
            cameraService: cameraService,
            analyticsService: analyticsService
        )
    }

    @MainActor func makeLocationViewModel() -> LocationViewModel {
        LocationViewModel(
            locationService: locationService,
            restaurantService: restaurantAPIService,
            analyticsService: analyticsService
        )
    }

    @MainActor func makeSessionViewModel() -> SessionViewModel {
        SessionViewModel(
            sessionService: sessionAPIService,
            menuService: menuAPIService,
            analyticsService: analyticsService,
            makeCalculatingViewModel: { [weak self] mode, preferences in
                guard let self else { fatalError("Container deallocated") }
                return self.makeCalculatingViewModel(mode: mode, preferences: preferences)
            },
            makeRecommendationViewModel: { [weak self] sessionId, foodMenuId, wineMenuId, preferences in
                guard let self else { fatalError("Container deallocated") }
                return self.makeRecommendationViewModel(
                    sessionId: sessionId,
                    foodMenuId: foodMenuId,
                    wineMenuId: wineMenuId,
                    preferences: preferences
                )
            }
        )
    }

    @MainActor func makeMainViewModel() -> MainViewModel {
        // Load preferences before creating the MainViewModel
        if let manager = preferenceManager as? PreferenceManager {
            manager.loadPreferences()
        }

        return MainViewModel(
            cameraViewModel: makeCameraViewModel(),
            locationViewModel: makeLocationViewModel(),
            sessionViewModel: makeSessionViewModel(),
            preferenceManager: preferenceManager
        )
    }

    @MainActor func makePhotoReviewViewModel(sessionId: String, photo: UIImage) -> PhotoReviewViewModel {
        PhotoReviewViewModel(
            sessionId: sessionId,
            photo: photo,
            sessionService: sessionAPIService
        )
    }

    @MainActor func makeCalculatingViewModel(mode: CalculationMode, preferences: UserPreferences) -> CalculatingViewModel {
        CalculatingViewModel(
            mode: mode,
            preferences: preferences,
            menuService: menuAPIService,
            sessionService: sessionAPIService
        )
    }

    @MainActor func makeRecommendationViewModel(sessionId: String, foodMenuId: Int?, wineMenuId: Int?, preferences: UserPreferences) -> RecommendationViewModel {
        RecommendationViewModel(
            sessionId: sessionId,
            foodMenuId: foodMenuId,
            wineMenuId: wineMenuId,
            menuService: menuAPIService,
            recommendationEngine: recommendationEngine,
            analyticsService: analyticsService,
            preferenceManager: preferenceManager
        )
    }

    @MainActor func makeSurveyViewModel(sessionId: String, items: [ScoredFoodItem]) -> SurveyViewModel {
        SurveyViewModel(
            sessionId: sessionId,
            items: items,
            menuService: menuAPIService,
            analyticsService: analyticsService
        )
    }

    @MainActor func makePhotoCarouselReviewViewModel(photos: [CapturedPhoto], sessionId: String?) -> PhotoCarouselReviewViewModel {
        PhotoCarouselReviewViewModel(
            photos: photos,
            sessionId: sessionId,
            analyticsService: analyticsService
        )
    }
}

// MARK: - Production API Services

final class RestaurantAPIService: RestaurantAPIServiceProtocol, Sendable {
    private let networkManager: NetworkManagerProtocol

    init(networkManager: NetworkManagerProtocol) {
        self.networkManager = networkManager
    }

    func getNearbyRestaurants(lat: Double, lon: Double, radius: Int) async throws -> [RestaurantResponse] {
        let response: RestaurantListResponse = try await networkManager.request(
            endpoint: .nearbyRestaurants(lat: lat, lon: lon, radius: radius),
            method: .GET,
            body: nil
        )
        return response.restaurants
    }
}

final class SessionAPIService: SessionAPIServiceProtocol, Sendable {
    private let networkManager: NetworkManagerProtocol

    init(networkManager: NetworkManagerProtocol) {
        self.networkManager = networkManager
    }

    func uploadPhoto(sessionId: String, imageData: Data) async throws -> PhotoUploadResponse {
        return try await networkManager.uploadPhoto(
            endpoint: .uploadPhoto(sessionId: sessionId),
            imageData: imageData,
            fileName: "\(UUID().uuidString).jpg"
        )
    }
}

final class MenuAPIService: MenuAPIServiceProtocol, Sendable {
    private let networkManager: NetworkManagerProtocol

    init(networkManager: NetworkManagerProtocol) {
        self.networkManager = networkManager
    }

    func createMenus(sessionId: String, lat: Double?, lon: Double?) async throws -> JobResponse {
        return try await networkManager.request(
            endpoint: .createMenus(sessionId: sessionId, lat: lat, lon: lon),
            method: .POST,
            body: nil
        )
    }

    func getMenusCreationStatus(jobId: String) async throws -> JobStatusResponse {
        return try await networkManager.request(
            endpoint: .menusCreationStatus(jobId: jobId),
            method: .GET,
            body: nil
        )
    }

    func getMenus(foodMenuId: Int?, wineMenuId: Int?) async throws -> RecommendationResponse {
        return try await networkManager.request(
            endpoint: .getMenus(foodMenuId: foodMenuId, wineMenuId: wineMenuId),
            method: .GET,
            body: nil
        )
    }

    func submitFeedback(sessionId: String, itemId: Int, rating: FeedbackRating) async throws {
        let request = FeedbackRequest(itemId: itemId, action: rating.rawValue)
        let body = try JSONEncoder().encode(request)
        try await networkManager.requestWithoutResponse(
            endpoint: .submitFeedback(sessionId: sessionId),
            method: .POST,
            body: body
        )
    }
}

final class AnalyticsService: AnalyticsServiceProtocol, Sendable {
    private let networkManager: NetworkManagerProtocol
    private let deviceIdentifierService: DeviceIdentifierServiceProtocol

    init(networkManager: NetworkManagerProtocol, deviceIdentifierService: DeviceIdentifierServiceProtocol) {
        self.networkManager = networkManager
        self.deviceIdentifierService = deviceIdentifierService
    }

    func track(event: AnalyticsEventType, sessionId: String?, meta: [String: Any]?) {
        // Convert Any values to String for JSON encoding
        let metaStrings = meta?.mapValues { value -> String in
            if let stringValue = value as? String {
                return stringValue
            } else if let intValue = value as? Int {
                return String(intValue)
            } else if let doubleValue = value as? Double {
                return String(doubleValue)
            } else if let boolValue = value as? Bool {
                return String(boolValue)
            } else {
                return "\(value)"
            }
        }

        let analyticsEvent = AnalyticsEvent(
            sessionId: sessionId,
            userId: nil,
            deviceId: deviceIdentifierService.getDeviceId(),
            event: event.rawValue,
            meta: metaStrings
        )

        Task {
            do {
                let body = try JSONEncoder().encode(analyticsEvent)
                try await networkManager.requestWithoutResponse(endpoint: .trackEvent, method: .POST, body: body)
            } catch {
                AppLogger.shared.debug("Failed to track event: \(error)", category: AppLogger.Category.analytics)
            }
        }
    }
}

// MARK: - Analytics Event Types

enum AnalyticsEventType: String {
    case appOpen = "app_open"
    case restaurantSuggestedShown = "restaurant_suggested_shown"
    case restaurantSelected = "restaurant_selected"
    case photoCaptured = "photo_captured"
    case photoAccepted = "photo_accepted"
    case photoDiscarded = "photo_discarded"
    case carouselReviewOpened = "carousel_review_opened"
    case carouselReviewCompleted = "carousel_review_completed"
    case recommendClicked = "recommend_clicked"
    case sliderSet = "slider_set"
    case preferenceAdjusted = "preference_adjusted"
    case recommendationViewed = "recommendation_viewed"
    case itemExpanded = "item_expanded"
    case itemTapped = "item_tapped"
    case surveyCompleted = "survey_completed"
    case itemAddedToCart = "item_added_to_cart"
    case itemRemovedFromCart = "item_removed_from_cart"
}

// ImageCacheService implementation is now in Services/ImageCacheService.swift
