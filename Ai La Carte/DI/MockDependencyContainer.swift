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

    lazy var deviceIdentifierService: DeviceIdentifierServiceProtocol = {
        MockDeviceIdentifierService()
    }()

    // MARK: - API Services

    lazy var restaurantAPIService: RestaurantAPIServiceProtocol = {
        MockRestaurantAPIService()
    }()

    lazy var sessionAPIService: SessionAPIServiceProtocol = {
        MockSessionAPIService()
    }()

    lazy var menuAPIService: MenuAPIServiceProtocol = {
        MockMenuAPIService()
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
        // Use real RecommendationEngine even in mock mode for consistent behavior
        RecommendationEngine()
    }()

    // MARK: - Utilities

    lazy var imageCacheService: ImageCacheServiceProtocol = {
        MockImageCacheService()
    }()

    lazy var userPreferencesStorage: UserPreferencesStorageProtocol = {
        MockUserPreferencesStorage()
    }()

    lazy var preferenceManager: PreferenceManagerProtocol = {
        let manager = PreferenceManager(storage: userPreferencesStorage)
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

// MARK: - Mock Restaurant API Service

final class MockRestaurantAPIService: RestaurantAPIServiceProtocol, Sendable {
    func getNearbyRestaurants(lat: Double, lon: Double, radius: Int) async throws -> [RestaurantResponse] {
        try await Task.sleep(nanoseconds: 800_000_000) // 0.8 second delay

        AppLogger.shared.info("[MOCK] Fetching nearby restaurants at (\(lat), \(lon))", category: AppLogger.Category.network)

        return [
            RestaurantResponse(
                id: 1,
                name: "Golden Dragon",
                cuisine: "Chinese",
                address: "123 Main Street",
                latestFoodMenuId: 101,
                latestWineMenuId: nil,
                menuUpdatedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400 * 2))
            ),
            RestaurantResponse(
                id: 2,
                name: "Trattoria Milano",
                cuisine: "Italian",
                address: "456 Oak Avenue",
                latestFoodMenuId: 102,
                latestWineMenuId: 202,
                menuUpdatedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400))
            ),
            RestaurantResponse(
                id: 3,
                name: "Sakura Sushi",
                cuisine: "Japanese",
                address: "789 Cherry Lane",
                latestFoodMenuId: 103,
                latestWineMenuId: 203,
                menuUpdatedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400 * 5))
            ),
            RestaurantResponse(
                id: 4,
                name: "The Spice Room",
                cuisine: "Indian",
                address: "321 Curry Road",
                latestFoodMenuId: 104,
                latestWineMenuId: nil,
                menuUpdatedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400 * 3))
            ),
            RestaurantResponse(
                id: 5,
                name: "Bistro Parisien",
                cuisine: "French",
                address: "555 French Quarter",
                latestFoodMenuId: 105,
                latestWineMenuId: 205,
                menuUpdatedAt: ISO8601DateFormatter().string(from: Date())
            )
        ]
    }
}

// MARK: - Mock Session API Service

final class MockSessionAPIService: SessionAPIServiceProtocol, Sendable {
    func uploadPhoto(sessionId: String, imageData: Data) async throws -> PhotoUploadResponse {
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 second delay

        let photoId = UUID().uuidString
        AppLogger.shared.info("[MOCK] Uploaded photo \(photoId) for session \(sessionId)", category: AppLogger.Category.session)

        return PhotoUploadResponse(
            photoId: photoId,
            url: "https://mock.ailacarte.app/photos/\(photoId).jpg"
        )
    }
}

// MARK: - Mock Menu API Service

final class MockMenuAPIService: MenuAPIServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _jobProgress: [String: Int] = [:]

    private func getProgress(_ jobId: String) -> Int {
        lock.withLock { _jobProgress[jobId] ?? 0 }
    }

    private func setProgress(_ jobId: String, _ value: Int) {
        lock.withLock { _jobProgress[jobId] = value }
    }

    func createMenus(sessionId: String, lat: Double?, lon: Double?) async throws -> JobResponse {
        try await Task.sleep(nanoseconds: 300_000_000)

        let jobId = UUID().uuidString
        setProgress(jobId, 0)

        let locationStr = lat != nil && lon != nil ? "(\(lat!), \(lon!))" : "(no location)"
        AppLogger.shared.info("[MOCK] Started menu creation job \(jobId) for session \(sessionId) at \(locationStr)", category: AppLogger.Category.recommendation)
        return JobResponse(jobId: jobId, status: "queued")
    }

    func getMenusCreationStatus(jobId: String) async throws -> JobStatusResponse {
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

        // Return menu IDs when job is complete
        let foodMenuId: Int? = status == .done ? 999 : nil
        let wineMenuId: Int? = status == .done ? 998 : nil

        return JobStatusResponse(
            status: status.rawValue,
            progress: status.progress,
            foodMenuId: foodMenuId,
            wineMenuId: wineMenuId
        )
    }

    func getMenus(foodMenuId: Int?, wineMenuId: Int?) async throws -> RecommendationResponse {
        try await Task.sleep(nanoseconds: 500_000_000)

        AppLogger.shared.info("[MOCK] Fetching menus - food: \(foodMenuId.map(String.init) ?? "nil"), wine: \(wineMenuId.map(String.init) ?? "nil")", category: AppLogger.Category.recommendation)

        let foodItems: [FoodItemResponse] = [
            // Appetizers
            FoodItemResponse(
                id: 4,
                title: "Dim Sum Platter",
                description: "An assortment of hand-crafted dumplings including har gow, siu mai, and char siu bao. Perfect for sharing.",
                tags: [
                    FoodTagResponse(code : "CROWD_PLEASER", label: "Crowd Pleaser"),
                    FoodTagResponse(code: "COMMUNITY_FAVORITE", label: "Community Favorite")
                ],
                photoUrl: "https://images.unsplash.com/photo-1496116218417-1a781b1c416c?w=400",
                price: 24.00,
                category: "appetizer",
                spice: 1,
                richness: 3,
                ingredients: ["Pork", "Seafood"]
            ),
            FoodItemResponse(
                id: 5,
                title: "Spring Rolls",
                description: "Crispy golden rolls filled with vegetables and glass noodles. Served with sweet chili dipping sauce.",
                tags: [
                    FoodTagResponse(code: "VEGETARIAN", label: "Vegetarian Friendly"),
                    FoodTagResponse(code: "GREAT_VALUE", label: "Great Value")
                ],
                photoUrl: "https://images.unsplash.com/photo-1548507243-d1f7c03cb2ac?w=400",
                price: 8.95,
                category: "appetizer",
                spice: 2,
                richness: 2,
                ingredients: nil
            ),
            // Entrees
            FoodItemResponse(
                id: 1,
                title: "Kung Pao Chicken",
                description: "Tender chicken with peanuts, vegetables, and chili peppers in a savory-sweet sauce. A perfect balance of spice and flavor.",
                tags: [
                    FoodTagResponse(code: "COMMUNITY_FAVORITE", label: "Community Favorite"),
                    FoodTagResponse(code: "MATCHES_SPICE", label: "Matches Your Spice Level")
                ],
                photoUrl: "https://images.unsplash.com/photo-1525755662778-989d0524087e?w=400",
                price: 18.95,
                category: "entree",
                spice: 4,
                richness: 3,
                ingredients: ["Chicken"]
            ),
            FoodItemResponse(
                id: 2,
                title: "Peking Duck",
                description: "Crispy roasted duck served with thin pancakes, scallions, and hoisin sauce. A house specialty that's been perfected over generations.",
                tags: [
                    FoodTagResponse(code: "CHEF_SIGNATURE", label: "Chef's Signature"),
                    FoodTagResponse(code: "HOUSE_SPECIALTY", label: "House Specialty")
                ],
                photoUrl: "https://images.unsplash.com/photo-1518492104633-130d0cc84637?w=400",
                price: 42.00,
                category: "entree",
                spice: 1,
                richness: 5,
                ingredients: nil
            ),
            FoodItemResponse(
                id: 3,
                title: "Mapo Tofu",
                description: "Silky tofu in a fiery, aromatic sauce with minced pork and Sichuan peppercorns. Bold and satisfying.",
                tags: [
                    FoodTagResponse(code: "ADVENTUROUS_PICK", label: "Adventurous Pick"),
                    FoodTagResponse(code: "GREAT_VALUE", label: "Great Value")
                ],
                photoUrl: "https://images.unsplash.com/photo-1582452919408-39bddf60a4a2?w=400",
                price: 14.50,
                category: "entree",
                spice: 5,
                richness: 4,
                ingredients: ["Pork"]
            ),
            // Dessert
            FoodItemResponse(
                id: 6,
                title: "Mango Sticky Rice",
                description: "Sweet coconut sticky rice topped with fresh mango slices and drizzled with coconut cream. A refreshing finish.",
                tags: [
                    FoodTagResponse(code: "CROWD_PLEASER", label: "Crowd Pleaser")
                ],
                photoUrl: "https://images.unsplash.com/photo-1621293954908-907159247fc8?w=400",
                price: 9.50,
                category: "dessert",
                spice: 1,
                richness: 3,
                ingredients: ["Rice"]
            ),
            FoodItemResponse(
                id: 7,
                title: "Sesame Balls",
                description: "Crispy fried glutinous rice balls filled with sweet red bean paste and coated in sesame seeds.",
                tags: [
                    FoodTagResponse(code: "COMMUNITY_FAVORITE", label: "Community Favorite")
                ],
                photoUrl: "https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=400",
                price: 6.00,
                category: "dessert",
                spice: 1,
                richness: 4,
                ingredients: ["Rice"]
            )
        ]

        let wineItems: [WineItemResponse] = [
            // Sparkling
            WineItemResponse(
                id: 3,
                title: "NV Moët & Chandon Brut Imperial",
                description: "Celebratory bubbles with toasty brioche notes. A versatile pairing that elevates any meal.",
                tags: [
                    WineTagResponse(code: "FAMOUS", label: "Famous"),
                    WineTagResponse(code: "HIGH_CP_VALUE", label: "High CP Value")
                ],
                grapeVarietal: "Chardonnay, Pinot Noir, Pinot Meunier",
                region: "Champagne",
                country: "France",
                priceGlass: nil,
                priceBottle: 85.00,
                category: "sparkling",
                flavor: "Elegant"
            ),
            // White Wines
            WineItemResponse(
                id: 1,
                title: "2021 Trimbach Riesling",
                description: "A crisp, aromatic white with notes of green apple and lime. The slight sweetness pairs beautifully with spicy dishes.",
                tags: [
                    WineTagResponse(code: "HIGH_SCORE", label: "High Score"),
                    WineTagResponse(code: "HIGH_CP_VALUE", label: "High CP Value")
                ],
                grapeVarietal: "Riesling",
                region: "Alsace",
                country: "France",
                priceGlass: 14.00,
                priceBottle: 52.00,
                category: "white",
                flavor: "Acidic"
            ),
            WineItemResponse(
                id: 4,
                title: "2022 Cloudy Bay Sauvignon Blanc",
                description: "Vibrant and zesty with passion fruit and citrus notes. Perfect with seafood and light dishes.",
                tags: [
                    WineTagResponse(code: "FAMOUS", label: "Famous"),
                    WineTagResponse(code: "AWARD_WINNING", label: "Award Winning")
                ],
                grapeVarietal: "Sauvignon Blanc",
                region: "Marlborough",
                country: "New Zealand",
                priceGlass: 15.00,
                priceBottle: 58.00,
                category: "white",
                flavor: "Fruity"
            ),
            // Rosé
            WineItemResponse(
                id: 5,
                title: "2023 Whispering Angel Rosé",
                description: "Elegant Provence rosé with delicate strawberry and peach flavors. Refreshingly dry and versatile.",
                tags: [
                    WineTagResponse(code: "FAMOUS", label: "Famous"),
                    WineTagResponse(code: "RISING_STAR", label: "Rising Star")
                ],
                grapeVarietal: "Grenache, Cinsault, Rolle",
                region: "Provence",
                country: "France",
                priceGlass: 14.00,
                priceBottle: 48.00,
                category: "rose",
                flavor: "Fruity"
            ),
            // Red Wines
            WineItemResponse(
                id: 2,
                title: "2019 Willamette Valley Pinot Noir",
                description: "Elegant and fruit-forward with cherry and earthy notes. Its medium body complements rich, savory dishes.",
                tags: [
                    WineTagResponse(code: "RISING_STAR", label: "Rising Star"),
                    WineTagResponse(code: "HIGH_SCORE", label: "High Score")
                ],
                grapeVarietal: "Pinot Noir",
                region: "Willamette Valley",
                country: "USA",
                priceGlass: 16.00,
                priceBottle: 64.00,
                category: "red",
                flavor: "Elegant"
            ),
            WineItemResponse(
                id: 6,
                title: "2018 Caymus Cabernet Sauvignon",
                description: "Rich and full-bodied with blackberry, cassis, and vanilla oak notes. A bold choice for hearty dishes.",
                tags: [
                    WineTagResponse(code: "FINE_AND_RARE", label: "Fine & Rare"),
                    WineTagResponse(code: "AWARD_WINNING", label: "Award Winning")
                ],
                grapeVarietal: "Cabernet Sauvignon",
                region: "Napa Valley",
                country: "USA",
                priceGlass: 22.00,
                priceBottle: 95.00,
                category: "red",
                flavor: "Full-Body"
            )
        ]

        AppLogger.shared.info("[MOCK] Returning \(foodItems.count) food and \(wineItems.count) wine recommendations", category: AppLogger.Category.recommendation)

        return RecommendationResponse(
            food: foodItems,
            wine: wineItems
        )
    }

    func submitFeedback(sessionId: String, itemId: Int, rating: FeedbackRating) async throws {
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
    func track(event: AnalyticsEventType, sessionId: String?, meta: [String: Any]?) {
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

// MARK: - Mock User Preferences Storage
// Note: Uses real UserDefaults so preferences persist across app restarts even in mock mode

final class MockUserPreferencesStorage: UserPreferencesStorageProtocol, Sendable {
    private let key = AppConstants.Storage.userPreferencesKey

    func loadPreferences() -> UserPreferences {
        guard let data = UserDefaults.standard.data(forKey: key),
              let preferences = try? JSONDecoder().decode(UserPreferences.self, from: data)
        else {
            AppLogger.shared.debug("[MOCK] No saved preferences found, using defaults", category: AppLogger.Category.session)
            return .default
        }
        AppLogger.shared.debug("[MOCK] Loaded preferences: ingredients=\(preferences.food.ingredients.count), spice=\(preferences.food.spicePreference)", category: AppLogger.Category.session)
        return preferences
    }

    func savePreferences(_ preferences: UserPreferences) {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: key)
        }
        AppLogger.shared.debug("[MOCK] Saved preferences: ingredients=\(preferences.food.ingredients.count), spice=\(preferences.food.spicePreference)", category: AppLogger.Category.session)
    }

    func resetPreferences() {
        UserDefaults.standard.removeObject(forKey: key)
        AppLogger.shared.debug("[MOCK] Reset preferences to defaults", category: AppLogger.Category.session)
    }
}
