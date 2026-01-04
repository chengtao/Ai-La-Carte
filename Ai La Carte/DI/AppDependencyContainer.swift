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
        NetworkManager(configuration: .default)
    }()

    // MARK: - API Services

    lazy var userAPIService: UserAPIServiceProtocol = {
        UserAPIService(networkManager: networkManager)
    }()

    lazy var restaurantAPIService: RestaurantAPIServiceProtocol = {
        RestaurantAPIService(networkManager: networkManager)
    }()

    lazy var sessionAPIService: SessionAPIServiceProtocol = {
        SessionAPIService(networkManager: networkManager)
    }()

    lazy var recommendationAPIService: RecommendationAPIServiceProtocol = {
        RecommendationAPIService(networkManager: networkManager)
    }()

    // MARK: - Device Services

    lazy var locationService: LocationServiceProtocol = {
        LocationService()
    }()

    lazy var cameraService: CameraServiceProtocol = {
        CameraService()
    }()

    lazy var analyticsService: AnalyticsServiceProtocol = {
        AnalyticsService(networkManager: networkManager)
    }()

    // MARK: - Local Engines

    lazy var recommendationEngine: RecommendationEngineProtocol = {
        RecommendationEngine()
    }()

    // MARK: - Utilities

    lazy var imageCacheService: ImageCacheServiceProtocol = {
        ImageCacheService()
    }()

    // MARK: - ViewModel Factory Methods

    @MainActor func makeWelcomeViewModel() -> WelcomeViewModel {
        WelcomeViewModel(locationService: locationService, cameraService: cameraService)
    }

    @MainActor func makeMainViewModel() -> MainViewModel {
        MainViewModel(
            restaurantService: restaurantAPIService,
            sessionService: sessionAPIService,
            recommendationService: recommendationAPIService,
            locationService: locationService,
            cameraService: cameraService,
            analyticsService: analyticsService
        )
    }

    @MainActor func makePhotoReviewViewModel(sessionId: String, photo: UIImage) -> PhotoReviewViewModel {
        PhotoReviewViewModel(
            sessionId: sessionId,
            photo: photo,
            sessionService: sessionAPIService
        )
    }

    @MainActor func makeCalculatingViewModel(sessionId: String, jobId: String, preferences: UserPreferences) -> CalculatingViewModel {
        CalculatingViewModel(
            sessionId: sessionId,
            jobId: jobId,
            preferences: preferences,
            recommendationService: recommendationAPIService
        )
    }

    @MainActor func makeRecommendationViewModel(sessionId: String, preferences: UserPreferences) -> RecommendationViewModel {
        RecommendationViewModel(
            sessionId: sessionId,
            preferences: preferences,
            recommendationService: recommendationAPIService,
            recommendationEngine: recommendationEngine,
            analyticsService: analyticsService
        )
    }

    @MainActor func makeSurveyViewModel(sessionId: String, items: [ScoredFoodItem]) -> SurveyViewModel {
        SurveyViewModel(
            sessionId: sessionId,
            items: items,
            recommendationService: recommendationAPIService,
            analyticsService: analyticsService
        )
    }
}

// MARK: - Production API Services

final class UserAPIService: UserAPIServiceProtocol, Sendable {
    private let networkManager: NetworkManagerProtocol

    init(networkManager: NetworkManagerProtocol) {
        self.networkManager = networkManager
    }

    func signInWithApple(identityToken: String) async throws -> UserResponse {
        let body = try JSONEncoder().encode(["identity_token": identityToken])
        return try await networkManager.request(endpoint: .appleAuth, method: .POST, body: body)
    }

    func signOut() async throws {
        try await networkManager.requestWithoutResponse(endpoint: .logout, method: .POST, body: nil)
    }

    func deleteAccount() async throws {
        try await networkManager.requestWithoutResponse(endpoint: .deleteAccount, method: .DELETE, body: nil)
    }

    func getCurrentUser() async throws -> UserResponse? {
        // Could implement with a /me endpoint
        return nil
    }
}

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

    func registerSession(sessionId: String) async throws {
        let params: [String: Any] = [
            "session_id": sessionId,
            "device_id": KeychainHelper.getOrCreateDeviceId()
        ]
        let body = try JSONSerialization.data(withJSONObject: params)
        try await networkManager.requestWithoutResponse(endpoint: .registerSession, method: .POST, body: body)
    }

    func updateSessionLocation(sessionId: String, lat: Double, lon: Double) async throws {
        let params: [String: Any] = [
            "lat": lat,
            "lon": lon
        ]
        let body = try JSONSerialization.data(withJSONObject: params)
        try await networkManager.requestWithoutResponse(
            endpoint: .updateSessionLocation(sessionId: sessionId),
            method: .PUT,
            body: body
        )
    }

    func pickRestaurant(sessionId: String, restaurantId: String) async throws {
        let params: [String: Any] = [
            "restaurant_id": restaurantId
        ]
        let body = try JSONSerialization.data(withJSONObject: params)
        try await networkManager.requestWithoutResponse(
            endpoint: .pickRestaurant(sessionId: sessionId),
            method: .PUT,
            body: body
        )
    }

    func uploadPhoto(sessionId: String, imageData: Data) async throws -> PhotoUploadResponse {
        return try await networkManager.uploadPhoto(
            endpoint: .uploadPhoto(sessionId: sessionId),
            imageData: imageData,
            fileName: "\(UUID().uuidString).jpg"
        )
    }

    func submitPreferences(sessionId: String, preferences: FoodPreference) async throws {
        let body = try JSONEncoder().encode([
            "adventurous_classic": preferences.adventurousness,
            "spice_tolerance": preferences.spiceTolerance
        ])
        try await networkManager.requestWithoutResponse(
            endpoint: .submitPreferences(sessionId: sessionId),
            method: .POST,
            body: body
        )
    }
}

final class RecommendationAPIService: RecommendationAPIServiceProtocol, Sendable {
    private let networkManager: NetworkManagerProtocol

    init(networkManager: NetworkManagerProtocol) {
        self.networkManager = networkManager
    }

    func generateRecommendations(sessionId: String, includeReviews: Bool) async throws -> JobResponse {
        let body = try JSONEncoder().encode(["include_reviews": includeReviews])
        return try await networkManager.request(
            endpoint: .generateRecommendations(sessionId: sessionId),
            method: .POST,
            body: body
        )
    }

    func getRecommendationStatus(sessionId: String, jobId: String) async throws -> JobStatusResponse {
        return try await networkManager.request(
            endpoint: .recommendationStatus(sessionId: sessionId, jobId: jobId),
            method: .GET,
            body: nil
        )
    }

    func getRecommendations(sessionId: String) async throws -> RecommendationResponse {
        return try await networkManager.request(
            endpoint: .getRecommendations(sessionId: sessionId),
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

    init(networkManager: NetworkManagerProtocol) {
        self.networkManager = networkManager
    }

    func track(event: AnalyticsEventType, sessionId: String?, meta: [String: String]?) {
        let analyticsEvent = AnalyticsEvent(
            sessionId: sessionId,
            userId: nil,
            deviceId: KeychainHelper.getOrCreateDeviceId(),
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
