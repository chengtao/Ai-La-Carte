//
//  AppDependencyContainer.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation
import SwiftUI
import SwiftData

final class AppDependencyContainer: DependencyContainer, @unchecked Sendable {
    // Note: @unchecked because lazy vars are not Sendable-safe by default
    // Thread safety is managed by only accessing from main thread during init
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Core Services

    lazy var networkManager: NetworkManagerProtocol = {
        NetworkManager(configuration: .development)
    }()

    lazy var deviceIdentifierService: DeviceIdentifierServiceProtocol = {
        DeviceIdentifierService()
    }()

    // MARK: - API Services

    lazy var restaurantAPIService: RestaurantAPIServiceProtocol = {
        RestaurantAPIService(networkManager: networkManager)
    }()

    lazy var sessionAPIService: SessionAPIServiceProtocol = {
        SessionAPIService(networkManager: networkManager)
    }()

    lazy var menuAPIService: MenuAPIServiceProtocol = {
        MenuAPIService(networkManager: networkManager)
    }()

    // MARK: - Device Services

    lazy var locationService: LocationServiceProtocol = {
        LocationService()
    }()

    lazy var cameraService: CameraServiceProtocol = {
        CameraService()
    }()

    lazy var analyticsService: AnalyticsServiceProtocol = {
        AnalyticsService(networkManager: networkManager, deviceIdentifierService: deviceIdentifierService)
    }()

    // MARK: - Local Engines

    lazy var recommendationEngine: RecommendationEngineProtocol = {
        RecommendationEngine()
    }()

    // MARK: - Utilities

    lazy var imageCacheService: ImageCacheServiceProtocol = {
        ImageCacheService()
    }()

    lazy var userPreferencesStorage: UserPreferencesStorageProtocol = {
        UserPreferencesStorage()
    }()

    lazy var preferenceManager: PreferenceManagerProtocol = {
        let manager = PreferenceManager(storage: userPreferencesStorage)
        // Note: loadPreferences must be called on MainActor
        // This will be called when first accessed in a MainActor context
        return manager
    }()

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
            analyticsService: analyticsService
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

    @MainActor func makeCalculatingViewModel(sessionId: String, mode: CalculationMode, preferences: UserPreferences) -> CalculatingViewModel {
        CalculatingViewModel(
            sessionId: sessionId,
            mode: mode,
            preferences: preferences,
            menuService: menuAPIService
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

    func submitFeedback(sessionId: String, itemId: String, rating: FeedbackRating) async throws {
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

    func track(event: AnalyticsEventType, sessionId: String?, meta: [String: String]?) {
        let analyticsEvent = AnalyticsEvent(
            sessionId: sessionId,
            userId: nil,
            deviceId: deviceIdentifierService.getDeviceId(),
            event: event.rawValue,
            meta: meta
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

actor ImageCacheService: ImageCacheServiceProtocol {
    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private let maxMemoryCacheCount = 100

    init() {
        let documentsDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsDirectory.appendingPathComponent("ImageCache", isDirectory: true)

        if !FileManager.default.fileExists(atPath: cacheDirectory.path) {
            try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }

        memoryCache.countLimit = maxMemoryCacheCount
    }

    func loadImage(from url: URL) async -> UIImage? {
        let cacheKey = cacheKey(for: url)

        // Check memory cache
        if let cached = memoryCache.object(forKey: cacheKey as NSString) {
            return cached
        }

        // Check disk cache
        if let diskImage = loadFromDisk(cacheKey: cacheKey) {
            memoryCache.setObject(diskImage, forKey: cacheKey as NSString)
            return diskImage
        }

        // Download
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await cacheImage(image, for: url)
                return image
            }
        } catch {
            AppLogger.shared.debug("Failed to load image: \(error)", category: AppLogger.Category.network)
        }

        return nil
    }

    func cacheImage(_ image: UIImage, for url: URL) async {
        let cacheKey = cacheKey(for: url)
        memoryCache.setObject(image, forKey: cacheKey as NSString)
        saveToDisk(image, cacheKey: cacheKey)
    }

    func clearCache() async {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    private func cacheKey(for url: URL) -> String {
        url.absoluteString.data(using: .utf8)!.base64EncodedString()
    }

    private func loadFromDisk(cacheKey: String) -> UIImage? {
        let filePath = cacheDirectory.appendingPathComponent(cacheKey)
        guard let data = try? Data(contentsOf: filePath) else { return nil }
        return UIImage(data: data)
    }

    private func saveToDisk(_ image: UIImage, cacheKey: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let filePath = cacheDirectory.appendingPathComponent(cacheKey)
        try? data.write(to: filePath)
    }
}
