//
//  MockDependencyContainer.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation
import SwiftUI
import SwiftData

final class MockDependencyContainer: DependencyContainer, @unchecked Sendable {
    // Note: @unchecked because lazy vars are not Sendable-safe by default
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

    // MARK: - Local Engines

    lazy var recommendationEngine: RecommendationEngineProtocol = {
        MockRecommendationEngine()
    }()

    // MARK: - Utilities

    lazy var imageCacheService: ImageCacheServiceProtocol = {
        MockImageCacheService()
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

// MARK: - Mock User API Service

final class MockUserAPIService: UserAPIServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _currentUser: UserResponse?

    private var currentUser: UserResponse? {
        get { lock.withLock { _currentUser } }
        set { lock.withLock { _currentUser = newValue } }
    }

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

final class MockRestaurantAPIService: RestaurantAPIServiceProtocol, Sendable {
    func getNearbyRestaurants(lat: Double, lon: Double, radius: Int) async throws -> [RestaurantResponse] {
        try await Task.sleep(nanoseconds: 800_000_000) // 0.8 second delay

        AppLogger.shared.info("[MOCK] Fetching nearby restaurants at (\(lat), \(lon))", category: AppLogger.Category.network)

        return [
            RestaurantResponse(
                id: "r1",
                name: "Golden Dragon",
                cuisine: "Chinese",
                address: "123 Main Street",
                hasFoodMenu: true,
                hasWineMenu: false,
                menuUpdatedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400 * 2))
            ),
            RestaurantResponse(
                id: "r2",
                name: "Trattoria Milano",
                cuisine: "Italian",
                address: "456 Oak Avenue",
                hasFoodMenu: true,
                hasWineMenu: true,
                menuUpdatedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400))
            ),
            RestaurantResponse(
                id: "r3",
                name: "Sakura Sushi",
                cuisine: "Japanese",
                address: "789 Cherry Lane",
                hasFoodMenu: true,
                hasWineMenu: true,
                menuUpdatedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400 * 5))
            ),
            RestaurantResponse(
                id: "r4",
                name: "The Spice Room",
                cuisine: "Indian",
                address: "321 Curry Road",
                hasFoodMenu: true,
                hasWineMenu: false,
                menuUpdatedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400 * 3))
            ),
            RestaurantResponse(
                id: "r5",
                name: "Bistro Parisien",
                cuisine: "French",
                address: "555 French Quarter",
                hasFoodMenu: true,
                hasWineMenu: true,
                menuUpdatedAt: ISO8601DateFormatter().string(from: Date())
            )
        ]
    }
}

// MARK: - Mock Session API Service

final class MockSessionAPIService: SessionAPIServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _sessions: [String: Bool] = [:]

    private func addSession(_ id: String) {
        lock.withLock { _sessions[id] = true }
    }

    func registerSession(sessionId: String) async throws {
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        addSession(sessionId)
        AppLogger.shared.info("[MOCK] Registered session: \(sessionId)", category: AppLogger.Category.session)
    }

    func updateSessionLocation(sessionId: String, lat: Double, lon: Double) async throws {
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        AppLogger.shared.info("[MOCK] Updated session \(sessionId) location: (\(lat), \(lon))", category: AppLogger.Category.session)
    }

    func pickRestaurant(sessionId: String, restaurantId: String) async throws {
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        AppLogger.shared.info("[MOCK] Session \(sessionId) picked restaurant: \(restaurantId)", category: AppLogger.Category.session)
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

    func submitPreferences(sessionId: String, preferences: FoodPreference) async throws {
        try await Task.sleep(nanoseconds: 300_000_000)

        AppLogger.shared.info("[MOCK] Submitted preferences for session \(sessionId): adventurous=\(preferences.adventurousness), spice=\(preferences.spiceTolerance)", category: AppLogger.Category.session)
    }
}

// MARK: - Mock Recommendation API Service

final class MockRecommendationAPIService: RecommendationAPIServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _jobProgress: [String: Int] = [:]

    private func getProgress(_ jobId: String) -> Int {
        lock.withLock { _jobProgress[jobId] ?? 0 }
    }

    private func setProgress(_ jobId: String, _ value: Int) {
        lock.withLock { _jobProgress[jobId] = value }
    }

    func generateRecommendations(sessionId: String, includeReviews: Bool) async throws -> JobResponse {
        try await Task.sleep(nanoseconds: 300_000_000)

        let jobId = UUID().uuidString
        setProgress(jobId, 0)

        AppLogger.shared.info("[MOCK] Started recommendation job \(jobId) for session \(sessionId)", category: AppLogger.Category.recommendation)
        return JobResponse(jobId: jobId, status: "queued")
    }

    func getRecommendationStatus(sessionId: String, jobId: String) async throws -> JobStatusResponse {
        try await Task.sleep(nanoseconds: 500_000_000)

        let currentStep = getProgress(jobId)
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
            setProgress(jobId, currentStep + 1)
        }

        AppLogger.shared.debug("[MOCK] Job \(jobId) status: \(status.rawValue)", category: AppLogger.Category.recommendation)
        return JobStatusResponse(status: status.rawValue, progress: status.progress)
    }

    func getRecommendations(sessionId: String) async throws -> RecommendationResponse {
        try await Task.sleep(nanoseconds: 500_000_000)

        let foodItems: [FoodItemResponse] = [
            // Appetizers
            FoodItemResponse(
                id: "f4",
                title: "Dim Sum Platter",
                description: "An assortment of hand-crafted dumplings including har gow, siu mai, and char siu bao. Perfect for sharing.",
                reasons: [
                    ReasonTagResponse(code: "CROWD_PLEASER", label: "Crowd Pleaser"),
                    ReasonTagResponse(code: "COMMUNITY_FAVORITE", label: "Community Favorite")
                ],
                pairingIds: nil,
                photoUrl: "https://images.unsplash.com/photo-1496116218417-1a781b1c416c?w=400",
                price: "$24.00",
                category: "appetizer"
            ),
            FoodItemResponse(
                id: "f5",
                title: "Spring Rolls",
                description: "Crispy golden rolls filled with vegetables and glass noodles. Served with sweet chili dipping sauce.",
                reasons: [
                    ReasonTagResponse(code: "VEGETARIAN", label: "Vegetarian Friendly"),
                    ReasonTagResponse(code: "GREAT_VALUE", label: "Great Value")
                ],
                pairingIds: nil,
                photoUrl: "https://images.unsplash.com/photo-1548507243-d1f7c03cb2ac?w=400",
                price: "$8.95",
                category: "appetizer"
            ),
            // Entrees
            FoodItemResponse(
                id: "f1",
                title: "Kung Pao Chicken",
                description: "Tender chicken with peanuts, vegetables, and chili peppers in a savory-sweet sauce. A perfect balance of spice and flavor.",
                reasons: [
                    ReasonTagResponse(code: "COMMUNITY_FAVORITE", label: "Community Favorite"),
                    ReasonTagResponse(code: "MATCHES_SPICE", label: "Matches Your Spice Level")
                ],
                pairingIds: ["w1"],
                photoUrl: "https://images.unsplash.com/photo-1525755662778-989d0524087e?w=400",
                price: "$18.95",
                category: "entree"
            ),
            FoodItemResponse(
                id: "f2",
                title: "Peking Duck",
                description: "Crispy roasted duck served with thin pancakes, scallions, and hoisin sauce. A house specialty that's been perfected over generations.",
                reasons: [
                    ReasonTagResponse(code: "CHEF_SIGNATURE", label: "Chef's Signature"),
                    ReasonTagResponse(code: "HOUSE_SPECIALTY", label: "House Specialty")
                ],
                pairingIds: ["w2"],
                photoUrl: "https://images.unsplash.com/photo-1518492104633-130d0cc84637?w=400",
                price: "$42.00",
                category: "entree"
            ),
            FoodItemResponse(
                id: "f3",
                title: "Mapo Tofu",
                description: "Silky tofu in a fiery, aromatic sauce with minced pork and Sichuan peppercorns. Bold and satisfying.",
                reasons: [
                    ReasonTagResponse(code: "ADVENTUROUS_PICK", label: "Adventurous Pick"),
                    ReasonTagResponse(code: "GREAT_VALUE", label: "Great Value")
                ],
                pairingIds: nil,
                photoUrl: "https://images.unsplash.com/photo-1582452919408-39bddf60a4a2?w=400",
                price: "$14.50",
                category: "entree"
            ),
            // Dessert
            FoodItemResponse(
                id: "f6",
                title: "Mango Sticky Rice",
                description: "Sweet coconut sticky rice topped with fresh mango slices and drizzled with coconut cream. A refreshing finish.",
                reasons: [
                    ReasonTagResponse(code: "CROWD_PLEASER", label: "Crowd Pleaser")
                ],
                pairingIds: nil,
                photoUrl: "https://images.unsplash.com/photo-1621293954908-907159247fc8?w=400",
                price: "$9.50",
                category: "dessert"
            ),
            FoodItemResponse(
                id: "f7",
                title: "Sesame Balls",
                description: "Crispy fried glutinous rice balls filled with sweet red bean paste and coated in sesame seeds.",
                reasons: [
                    ReasonTagResponse(code: "COMMUNITY_FAVORITE", label: "Community Favorite")
                ],
                pairingIds: nil,
                photoUrl: "https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=400",
                price: "$6.00",
                category: "dessert"
            )
        ]

        let wineItems: [WineItemResponse] = [
            // Sparkling
            WineItemResponse(
                id: "w3",
                title: "NV Moët & Chandon Brut Imperial",
                description: "Celebratory bubbles with toasty brioche notes. A versatile pairing that elevates any meal.",
                reasons: [
                    ReasonTagResponse(code: "CROWD_PLEASER", label: "Crowd Pleaser"),
                    ReasonTagResponse(code: "GREAT_VALUE", label: "Great Value")
                ],
                pairingIds: nil,
                grapeVarietal: "Chardonnay, Pinot Noir, Pinot Meunier",
                region: "Champagne",
                country: "France",
                priceGlass: nil,
                priceBottle: "$85",
                category: "sparkling"
            ),
            // White Wines
            WineItemResponse(
                id: "w1",
                title: "2021 Trimbach Riesling",
                description: "A crisp, aromatic white with notes of green apple and lime. The slight sweetness pairs beautifully with spicy dishes.",
                reasons: [
                    ReasonTagResponse(code: "PAIRS_WITH_DISH", label: "Perfect Pairing"),
                    ReasonTagResponse(code: "LIGHT_FRESH", label: "Light & Fresh")
                ],
                pairingIds: ["f1", "f3"],
                grapeVarietal: "Riesling",
                region: "Alsace",
                country: "France",
                priceGlass: "$14",
                priceBottle: "$52",
                category: "white"
            ),
            WineItemResponse(
                id: "w4",
                title: "2022 Cloudy Bay Sauvignon Blanc",
                description: "Vibrant and zesty with passion fruit and citrus notes. Perfect with seafood and light dishes.",
                reasons: [
                    ReasonTagResponse(code: "LIGHT_FRESH", label: "Light & Fresh"),
                    ReasonTagResponse(code: "COMMUNITY_FAVORITE", label: "Community Favorite")
                ],
                pairingIds: nil,
                grapeVarietal: "Sauvignon Blanc",
                region: "Marlborough",
                country: "New Zealand",
                priceGlass: "$15",
                priceBottle: "$58",
                category: "white"
            ),
            // Rosé
            WineItemResponse(
                id: "w5",
                title: "2023 Whispering Angel Rosé",
                description: "Elegant Provence rosé with delicate strawberry and peach flavors. Refreshingly dry and versatile.",
                reasons: [
                    ReasonTagResponse(code: "CROWD_PLEASER", label: "Crowd Pleaser"),
                    ReasonTagResponse(code: "LIGHT_FRESH", label: "Light & Fresh")
                ],
                pairingIds: nil,
                grapeVarietal: "Grenache, Cinsault, Rolle",
                region: "Provence",
                country: "France",
                priceGlass: "$14",
                priceBottle: "$48",
                category: "rose"
            ),
            // Red Wines
            WineItemResponse(
                id: "w2",
                title: "2019 Willamette Valley Pinot Noir",
                description: "Elegant and fruit-forward with cherry and earthy notes. Its medium body complements rich, savory dishes.",
                reasons: [
                    ReasonTagResponse(code: "PAIRS_WITH_DISH", label: "Perfect Pairing"),
                    ReasonTagResponse(code: "RICH_BOLD", label: "Rich & Bold")
                ],
                pairingIds: ["f2"],
                grapeVarietal: "Pinot Noir",
                region: "Willamette Valley",
                country: "USA",
                priceGlass: "$16",
                priceBottle: "$64",
                category: "red"
            ),
            WineItemResponse(
                id: "w6",
                title: "2018 Caymus Cabernet Sauvignon",
                description: "Rich and full-bodied with blackberry, cassis, and vanilla oak notes. A bold choice for hearty dishes.",
                reasons: [
                    ReasonTagResponse(code: "CHEF_SIGNATURE", label: "Chef's Signature"),
                    ReasonTagResponse(code: "RICH_BOLD", label: "Rich & Bold")
                ],
                pairingIds: ["f2"],
                grapeVarietal: "Cabernet Sauvignon",
                region: "Napa Valley",
                country: "USA",
                priceGlass: "$22",
                priceBottle: "$95",
                category: "red"
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

final class MockLocationService: LocationServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _authStatus: LocationAuthorizationStatus = .notDetermined

    var authorizationStatus: LocationAuthorizationStatus {
        lock.withLock { _authStatus }
    }

    private func setAuthStatus(_ status: LocationAuthorizationStatus) {
        lock.withLock { _authStatus = status }
    }

    func requestWhenInUseAuthorization() async -> LocationAuthorizationStatus {
        try? await Task.sleep(nanoseconds: 500_000_000)
        setAuthStatus(.authorizedWhenInUse)
        AppLogger.shared.info("[MOCK] Location authorization granted", category: AppLogger.Category.location)
        return authorizationStatus
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

final class MockAnalyticsService: AnalyticsServiceProtocol, Sendable {
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

final class MockImageCacheService: ImageCacheServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _cache: [String: UIImage] = [:]

    private func getCached(_ key: String) -> UIImage? {
        lock.withLock { _cache[key] }
    }

    private func setCache(_ key: String, _ image: UIImage) {
        lock.withLock { _cache[key] = image }
    }

    func loadImage(from url: URL) async -> UIImage? {
        let key = url.absoluteString

        if let cached = getCached(key) {
            return cached
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                setCache(key, image)
                return image
            }
        } catch {
            AppLogger.shared.debug("[MOCK] Failed to load image: \(error)", category: AppLogger.Category.network)
        }

        return nil
    }

    func cacheImage(_ image: UIImage, for url: URL) async {
        setCache(url.absoluteString, image)
    }

    func clearCache() async {
        lock.withLock { _cache.removeAll() }
    }
}
