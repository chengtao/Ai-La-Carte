//
//  AppDependencyContainer.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation
import SwiftUI
import SwiftData

final class AppDependencyContainer: DependencyContainer {
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

    // MARK: - Utilities

    lazy var imageCacheService: ImageCacheServiceProtocol = {
        ImageCacheService()
    }()

    // MARK: - ViewModel Factory Methods

    func makeWelcomeViewModel() -> WelcomeViewModel {
        WelcomeViewModel(locationService: locationService, cameraService: cameraService)
    }

    func makeMainViewModel() -> MainViewModel {
        MainViewModel(
            restaurantService: restaurantAPIService,
            sessionService: sessionAPIService,
            locationService: locationService,
            cameraService: cameraService,
            analyticsService: analyticsService
        )
    }

    func makePhotoReviewViewModel(sessionId: String, photo: UIImage) -> PhotoReviewViewModel {
        PhotoReviewViewModel(
            sessionId: sessionId,
            photo: photo,
            sessionService: sessionAPIService
        )
    }

    func makeSessionPreferenceViewModel(sessionId: String) -> SessionPreferenceViewModel {
        SessionPreferenceViewModel(
            sessionId: sessionId,
            sessionService: sessionAPIService,
            recommendationService: recommendationAPIService,
            analyticsService: analyticsService
        )
    }

    func makeCalculatingViewModel(sessionId: String, jobId: String) -> CalculatingViewModel {
        CalculatingViewModel(
            sessionId: sessionId,
            jobId: jobId,
            recommendationService: recommendationAPIService
        )
    }

    func makeRecommendationViewModel(sessionId: String) -> RecommendationViewModel {
        RecommendationViewModel(
            sessionId: sessionId,
            recommendationService: recommendationAPIService,
            analyticsService: analyticsService
        )
    }

    func makeSurveyViewModel(sessionId: String, items: [RecommendationItemResponse]) -> SurveyViewModel {
        SurveyViewModel(
            sessionId: sessionId,
            items: items,
            recommendationService: recommendationAPIService,
            analyticsService: analyticsService
        )
    }
}

// MARK: - Production API Services

final class UserAPIService: UserAPIServiceProtocol {
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

final class RestaurantAPIService: RestaurantAPIServiceProtocol {
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

final class SessionAPIService: SessionAPIServiceProtocol {
    private let networkManager: NetworkManagerProtocol

    init(networkManager: NetworkManagerProtocol) {
        self.networkManager = networkManager
    }

    func createSession(restaurantId: String?, context: SessionContext?) async throws -> SessionResponse {
        var params: [String: Any] = [
            "device_id": KeychainHelper.getOrCreateDeviceId()
        ]

        if let restaurantId = restaurantId {
            params["restaurant_id"] = restaurantId
        }

        if let context = context {
            params["context"] = ["lat": context.lat, "lon": context.lon]
        }

        let body = try JSONSerialization.data(withJSONObject: params)
        return try await networkManager.request(endpoint: .createSession, method: .POST, body: body)
    }

    func uploadPhoto(sessionId: String, imageData: Data) async throws -> PhotoUploadResponse {
        return try await networkManager.uploadPhoto(
            endpoint: .uploadPhoto(sessionId: sessionId),
            imageData: imageData,
            fileName: "\(UUID().uuidString).jpg"
        )
    }

    func submitPreferences(sessionId: String, preferences: SessionPreference) async throws {
        let body = try JSONEncoder().encode([
            "adventurous_classic": preferences.adventurousClassic,
            "spice_tolerance": preferences.spiceTolerance
        ])
        try await networkManager.requestWithoutResponse(
            endpoint: .submitPreferences(sessionId: sessionId),
            method: .POST,
            body: body
        )
    }
}

final class RecommendationAPIService: RecommendationAPIServiceProtocol {
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

final class AnalyticsService: AnalyticsServiceProtocol {
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

final class ImageCacheService: ImageCacheServiceProtocol {
    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private let maxMemoryCacheCount = 100
    private let maxDiskCacheSize: Int64 = 100 * 1024 * 1024 // 100 MB

    init() {
        let documentsDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsDirectory.appendingPathComponent("ImageCache", isDirectory: true)

        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
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
                cacheImage(image, for: url)
                return image
            }
        } catch {
            AppLogger.shared.debug("Failed to load image: \(error)", category: AppLogger.Category.network)
        }

        return nil
    }

    func cacheImage(_ image: UIImage, for url: URL) {
        let cacheKey = cacheKey(for: url)
        memoryCache.setObject(image, forKey: cacheKey as NSString)
        saveToDisk(image, cacheKey: cacheKey)
    }

    func clearCache() {
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
