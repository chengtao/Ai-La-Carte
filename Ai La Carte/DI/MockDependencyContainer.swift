//
//  MockDependencyContainer.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation
import SwiftUI
import SwiftData

final class MockDependencyContainer: DependencyContainer {
    // MARK: - Core Services

    lazy var networkManager: NetworkManagerProtocol = {
        NetworkManager(configuration: .mock)
    }()

    // MARK: - API Services

    lazy var userAPIService: UserAPIServiceProtocol = {
        MockUserAPIService()
    }()

    lazy var restaurantAPIService: RestaurantAPIServiceProtocol = {
        MockRestaurantAPIService()
    }()

    lazy var sessionAPIService: SessionAPIServiceProtocol = {
        MockSessionAPIService()
    }()

    lazy var recommendationAPIService: RecommendationAPIServiceProtocol = {
        MockRecommendationAPIService()
    }()

    // MARK: - Device Services

    lazy var locationService: LocationServiceProtocol = {
        // Use real location service even in mock mode for permission dialogs
        LocationService()
    }()

    lazy var cameraService: CameraServiceProtocol = {
        // Use real camera service even in mock mode for better UX
        CameraService()
    }()

    lazy var analyticsService: AnalyticsServiceProtocol = {
        MockAnalyticsService()
    }()

    // MARK: - Utilities

    lazy var imageCacheService: ImageCacheServiceProtocol = {
        MockImageCacheService()
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

// MARK: - Mock User API Service

final class MockUserAPIService: UserAPIServiceProtocol {
    private var currentUser: UserResponse?

    func signInWithApple(identityToken: String) async throws -> UserResponse {
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay

        let user = UserResponse(
            id: UUID().uuidString,
            name: "Test User",
            email: "test@example.com",
            phoneNumber: nil,
            deviceId: KeychainHelper.getOrCreateDeviceId(),
            createdAt: ISO8601DateFormatter().string(from: Date())
        )

        currentUser = user
        AppLogger.shared.info("[MOCK] User signed in: \(user.id)", category: AppLogger.Category.authentication)
        return user
    }

    func signOut() async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
        currentUser = nil
        AppLogger.shared.info("[MOCK] User signed out", category: AppLogger.Category.authentication)
    }

    func deleteAccount() async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
        currentUser = nil
        AppLogger.shared.info("[MOCK] Account deleted", category: AppLogger.Category.authentication)
    }

    func getCurrentUser() async throws -> UserResponse? {
        return currentUser
    }
}

// MARK: - Mock Restaurant API Service

final class MockRestaurantAPIService: RestaurantAPIServiceProtocol {
    func getNearbyRestaurants(lat: Double, lon: Double, radius: Int) async throws -> [RestaurantResponse] {
        try await Task.sleep(nanoseconds: 800_000_000) // 0.8 second delay

        AppLogger.shared.info("[MOCK] Fetching nearby restaurants at (\(lat), \(lon))", category: AppLogger.Category.network)

        return [
            RestaurantResponse(
                id: "r1",
                name: "Golden Dragon",
                distanceMeters: 42,
                hasFoodMenu: true,
                hasWineMenu: false,
                menuUpdatedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400 * 2)),
                confidence: 95
            ),
            RestaurantResponse(
                id: "r2",
                name: "Trattoria Milano",
                distanceMeters: 120,
                hasFoodMenu: true,
                hasWineMenu: true,
                menuUpdatedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400)),
                confidence: 88
            ),
            RestaurantResponse(
                id: "r3",
                name: "Sakura Sushi",
                distanceMeters: 85,
                hasFoodMenu: true,
                hasWineMenu: true,
                menuUpdatedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400 * 5)),
                confidence: 72
            ),
            RestaurantResponse(
                id: "r4",
                name: "The Spice Room",
                distanceMeters: 200,
                hasFoodMenu: true,
                hasWineMenu: false,
                menuUpdatedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400 * 3)),
                confidence: 65
            ),
            RestaurantResponse(
                id: "r5",
                name: "Bistro Parisien",
                distanceMeters: 350,
                hasFoodMenu: true,
                hasWineMenu: true,
                menuUpdatedAt: ISO8601DateFormatter().string(from: Date()),
                confidence: 80
            )
        ].sorted { $0.distanceMeters < $1.distanceMeters }
    }
}

// MARK: - Mock Session API Service

final class MockSessionAPIService: SessionAPIServiceProtocol {
    private var sessions: [String: Bool] = [:]

    func createSession(restaurantId: String?, context: SessionContext?) async throws -> SessionResponse {
        try await Task.sleep(nanoseconds: 500_000_000)

        let sessionId = UUID().uuidString
        sessions[sessionId] = true

        AppLogger.shared.info("[MOCK] Created session: \(sessionId) for restaurant: \(restaurantId ?? "none")", category: AppLogger.Category.session)
        return SessionResponse(sessionId: sessionId)
    }

    func uploadPhoto(sessionId: String, imageData: Data) async throws -> PhotoUploadResponse {
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 second delay

        let photoId = UUID().uuidString
        AppLogger.shared.info("[MOCK] Uploaded photo \(photoId) for session \(sessionId)", category: AppLogger.Category.session)

        return PhotoUploadResponse(
            photoId: photoId,
            url: "https://mock.ailacarte.app/photos/\(photoId).jpg"
        )
    }

    func submitPreferences(sessionId: String, preferences: SessionPreference) async throws {
        try await Task.sleep(nanoseconds: 300_000_000)

        AppLogger.shared.info("[MOCK] Submitted preferences for session \(sessionId): adventurous=\(preferences.adventurousClassic), spice=\(preferences.spiceTolerance)", category: AppLogger.Category.session)
    }
}

// MARK: - Mock Recommendation API Service

final class MockRecommendationAPIService: RecommendationAPIServiceProtocol {
    private var jobProgress: [String: Int] = [:]

    func generateRecommendations(sessionId: String, includeReviews: Bool) async throws -> JobResponse {
        try await Task.sleep(nanoseconds: 300_000_000)

        let jobId = UUID().uuidString
        jobProgress[jobId] = 0

        AppLogger.shared.info("[MOCK] Started recommendation job \(jobId) for session \(sessionId)", category: AppLogger.Category.recommendation)
        return JobResponse(jobId: jobId, status: "queued")
    }

    func getRecommendationStatus(sessionId: String, jobId: String) async throws -> JobStatusResponse {
        try await Task.sleep(nanoseconds: 500_000_000)

        let currentStep = jobProgress[jobId] ?? 0
        let statuses: [SessionStatus] = [
            .photosUploading,
            .parsingMenu,
            .collectingReviews,
            .buildingProfile,
            .ranking,
            .done
        ]

        let status = currentStep < statuses.count ? statuses[currentStep] : .done

        if status != .done {
            jobProgress[jobId] = currentStep + 1
        }

        AppLogger.shared.debug("[MOCK] Job \(jobId) status: \(status.rawValue)", category: AppLogger.Category.recommendation)
        return JobStatusResponse(status: status.rawValue, progress: status.progress)
    }

    func getRecommendations(sessionId: String) async throws -> RecommendationResponse {
        try await Task.sleep(nanoseconds: 500_000_000)

        let foodItems = [
            RecommendationItemResponse(
                id: "f1",
                type: "food",
                title: "Kung Pao Chicken",
                description: "Tender chicken with peanuts, vegetables, and chili peppers in a savory-sweet sauce. A perfect balance of spice and flavor.",
                reasons: [
                    ReasonTagResponse(code: "COMMUNITY_FAVORITE", label: "Community Favorite"),
                    ReasonTagResponse(code: "MATCHES_SPICE", label: "Matches Your Spice Level")
                ],
                confidence: 0.92,
                pairingIds: ["w1"]
            ),
            RecommendationItemResponse(
                id: "f2",
                type: "food",
                title: "Peking Duck",
                description: "Crispy roasted duck served with thin pancakes, scallions, and hoisin sauce. A house specialty that's been perfected over generations.",
                reasons: [
                    ReasonTagResponse(code: "CHEF_SIGNATURE", label: "Chef's Signature"),
                    ReasonTagResponse(code: "HOUSE_SPECIALTY", label: "House Specialty")
                ],
                confidence: 0.88,
                pairingIds: ["w2"]
            ),
            RecommendationItemResponse(
                id: "f3",
                type: "food",
                title: "Mapo Tofu",
                description: "Silky tofu in a fiery, aromatic sauce with minced pork and Sichuan peppercorns. Bold and satisfying.",
                reasons: [
                    ReasonTagResponse(code: "ADVENTUROUS_PICK", label: "Adventurous Pick"),
                    ReasonTagResponse(code: "GREAT_VALUE", label: "Great Value")
                ],
                confidence: 0.85,
                pairingIds: nil
            ),
            RecommendationItemResponse(
                id: "f4",
                type: "food",
                title: "Dim Sum Platter",
                description: "An assortment of hand-crafted dumplings including har gow, siu mai, and char siu bao. Perfect for sharing.",
                reasons: [
                    ReasonTagResponse(code: "CROWD_PLEASER", label: "Crowd Pleaser"),
                    ReasonTagResponse(code: "COMMUNITY_FAVORITE", label: "Community Favorite")
                ],
                confidence: 0.82,
                pairingIds: nil
            )
        ]

        let wineItems = [
            RecommendationItemResponse(
                id: "w1",
                type: "wine",
                title: "2021 Riesling, Alsace",
                description: "A crisp, aromatic white with notes of green apple and lime. The slight sweetness pairs beautifully with spicy dishes.",
                reasons: [
                    ReasonTagResponse(code: "PAIRS_WITH_DISH", label: "Perfect Pairing"),
                    ReasonTagResponse(code: "LIGHT_FRESH", label: "Light & Fresh")
                ],
                confidence: 0.90,
                pairingIds: ["f1", "f3"]
            ),
            RecommendationItemResponse(
                id: "w2",
                type: "wine",
                title: "2019 Pinot Noir, Oregon",
                description: "Elegant and fruit-forward with cherry and earthy notes. Its medium body complements rich, savory dishes.",
                reasons: [
                    ReasonTagResponse(code: "PAIRS_WITH_DISH", label: "Perfect Pairing"),
                    ReasonTagResponse(code: "RICH_BOLD", label: "Rich & Bold")
                ],
                confidence: 0.88,
                pairingIds: ["f2"]
            ),
            RecommendationItemResponse(
                id: "w3",
                type: "wine",
                title: "NV Champagne Brut",
                description: "Celebratory bubbles with toasty brioche notes. A versatile pairing that elevates any meal.",
                reasons: [
                    ReasonTagResponse(code: "CROWD_PLEASER", label: "Crowd Pleaser"),
                    ReasonTagResponse(code: "GREAT_VALUE", label: "Great Value")
                ],
                confidence: 0.75,
                pairingIds: nil
            )
        ]

        AppLogger.shared.info("[MOCK] Returning \(foodItems.count) food and \(wineItems.count) wine recommendations", category: AppLogger.Category.recommendation)

        return RecommendationResponse(
            food: foodItems,
            wine: wineItems,
            explanations: ExplanationsResponse(profileSummary: "Based on your preference for balanced adventure and medium spice, we've selected dishes that blend familiar comfort with exciting new flavors.")
        )
    }

    func submitFeedback(sessionId: String, itemId: String, rating: FeedbackRating) async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
        AppLogger.shared.info("[MOCK] Submitted feedback for item \(itemId): \(rating.rawValue)", category: AppLogger.Category.recommendation)
    }
}

// MARK: - Mock Location Service

final class MockLocationService: LocationServiceProtocol {
    private var _authorizationStatus: LocationAuthorizationStatus = .notDetermined

    var authorizationStatus: LocationAuthorizationStatus {
        _authorizationStatus
    }

    func requestWhenInUseAuthorization() async -> LocationAuthorizationStatus {
        try? await Task.sleep(nanoseconds: 500_000_000)
        _authorizationStatus = .authorizedWhenInUse
        AppLogger.shared.info("[MOCK] Location authorization granted", category: AppLogger.Category.location)
        return _authorizationStatus
    }

    func getCurrentLocation() async throws -> LocationCoordinate {
        try await Task.sleep(nanoseconds: 300_000_000)

        // Return San Francisco coordinates
        let coordinate = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        AppLogger.shared.info("[MOCK] Returning location: (\(coordinate.latitude), \(coordinate.longitude))", category: AppLogger.Category.location)
        return coordinate
    }
}

// MARK: - Mock Analytics Service

final class MockAnalyticsService: AnalyticsServiceProtocol {
    func track(event: AnalyticsEventType, sessionId: String?, meta: [String: String]?) {
        var logMessage = "[MOCK] Analytics: \(event.rawValue)"
        if let sessionId = sessionId {
            logMessage += " | session: \(sessionId)"
        }
        if let meta = meta, !meta.isEmpty {
            logMessage += " | meta: \(meta)"
        }
        AppLogger.shared.debug(logMessage, category: AppLogger.Category.analytics)
    }
}

// MARK: - Mock Image Cache Service

final class MockImageCacheService: ImageCacheServiceProtocol {
    private var cache: [String: UIImage] = [:]

    func loadImage(from url: URL) async -> UIImage? {
        let key = url.absoluteString

        if let cached = cache[key] {
            return cached
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                cache[key] = image
                return image
            }
        } catch {
            AppLogger.shared.debug("[MOCK] Failed to load image: \(error)", category: AppLogger.Category.network)
        }

        return nil
    }

    func cacheImage(_ image: UIImage, for url: URL) {
        cache[url.absoluteString] = image
    }

    func clearCache() {
        cache.removeAll()
    }
}
