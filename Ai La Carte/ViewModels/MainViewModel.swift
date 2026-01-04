//
//  MainViewModel.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation
import SwiftUI
import AVFoundation

@MainActor
@Observable
final class MainViewModel: BaseViewModel {
    // Camera state
    var cameraState: CameraState = .stopped
    var captureSession: AVCaptureSession?

    // Location & Restaurants
    var nearbyRestaurants: [RestaurantResponse] = []
    var selectedRestaurant: RestaurantResponse?
    var isLoadingRestaurants = false

    // Session state - created locally with UUID
    var currentSession: SessionInfo?
    var capturedPhotos: [CapturedPhoto] = []
    private var lastReportedLocation: LocationCoordinate?
    private var sessionRegistered = false

    // Navigation
    var showPhotoReview = false
    var showPreferenceSheet = false
    var showCalculating = false
    var showAccount = false
    var pendingPhoto: UIImage?

    // User preferences for recommendations
    var userPreferences: UserPreferences = .default

    // Recommendation generation
    var jobId: String?
    var calculatingViewModel: CalculatingViewModel?

    private let restaurantService: RestaurantAPIServiceProtocol
    private let sessionService: SessionAPIServiceProtocol
    private let recommendationService: RecommendationAPIServiceProtocol
    private let locationService: LocationServiceProtocol
    let cameraService: CameraServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol

    init(
        restaurantService: RestaurantAPIServiceProtocol,
        sessionService: SessionAPIServiceProtocol,
        recommendationService: RecommendationAPIServiceProtocol,
        locationService: LocationServiceProtocol,
        cameraService: CameraServiceProtocol,
        analyticsService: AnalyticsServiceProtocol
    ) {
        self.restaurantService = restaurantService
        self.sessionService = sessionService
        self.recommendationService = recommendationService
        self.locationService = locationService
        self.cameraService = cameraService
        self.analyticsService = analyticsService
        super.init()
    }

    // MARK: - Camera

    var cameraPermissionStatus: CameraAuthorizationStatus {
        cameraService.authorizationStatus
    }

    func startCamera() async {
        // Request permission if not determined
        if cameraService.authorizationStatus == .notDetermined {
            let status = await cameraService.requestAuthorization()
            if !status.isAuthorized {
                cameraState = .permissionDenied
                return
            }
        }

        guard cameraService.authorizationStatus.isAuthorized else {
            cameraState = .permissionDenied
            return
        }

        cameraState = .starting

        do {
            try await cameraService.startSession()
            AppLogger.shared.info("MainViewModel: Camera state -> running", category: AppLogger.Category.camera)
            cameraState = .running
        } catch {
            AppLogger.shared.error("MainViewModel: Camera error: \(error)", category: AppLogger.Category.camera)
            self.error = handleNetworkError(error)
            cameraState = .error
        }
    }

    func stopCamera() {
        cameraService.stopSession()
        cameraState = .stopped
    }

    func capturePhoto() async {
        guard cameraState == .running else { return }

        do {
            let photo = try await cameraService.capturePhoto()
            pendingPhoto = photo
            showPhotoReview = true

            analyticsService.track(event: .photoCaptured, sessionId: currentSession?.id, meta: nil)
        } catch {
            self.error = handleNetworkError(error)
        }
    }

    // MARK: - Location & Restaurants

    var locationPermissionStatus: LocationAuthorizationStatus {
        locationService.authorizationStatus
    }

    func requestLocationPermission() async {
        _ = await locationService.requestWhenInUseAuthorization()
    }

    func fetchNearbyRestaurants() async {
        // Request permission if not determined
        if locationService.authorizationStatus == .notDetermined {
            let status = await locationService.requestWhenInUseAuthorization()
            if !status.isAuthorized {
                return
            }
        }

        guard locationService.authorizationStatus.isAuthorized else {
            return
        }

        isLoadingRestaurants = true

        do {
            let location = try await locationService.getCurrentLocation()

            // Create session if not exists and update location
            if currentSession == nil {
                createLocalSession()
            }

            // Update session location in background
            Task {
                await updateSessionLocation(location)
            }

            let restaurants = try await restaurantService.getNearbyRestaurants(
                lat: location.latitude,
                lon: location.longitude,
                radius: AppConstants.Location.defaultSearchRadius
            )

            self.nearbyRestaurants = restaurants

            analyticsService.track(
                event: .restaurantSuggestedShown,
                sessionId: currentSession?.id,
                meta: ["count": "\(restaurants.count)"]
            )
        } catch {
            AppLogger.shared.error("Failed to fetch restaurants: \(error)", category: AppLogger.Category.network)
        }

        isLoadingRestaurants = false
    }

    // MARK: - Session Management

    /// Creates a new local session with UUID - call this when starting a recommendation flow
    func createLocalSession() {
        let sessionId = UUID().uuidString
        currentSession = SessionInfo(
            id: sessionId,
            restaurantId: nil,
            restaurantName: nil
        )
        sessionRegistered = false
        lastReportedLocation = nil

        AppLogger.shared.info("Created local session: \(sessionId)", category: AppLogger.Category.session)

        // Register with server in background
        Task {
            await registerSessionWithServer()
        }
    }

    /// Registers the local session with the server
    private func registerSessionWithServer() async {
        guard let session = currentSession, !sessionRegistered else { return }

        do {
            try await sessionService.registerSession(sessionId: session.id)
            sessionRegistered = true
            AppLogger.shared.info("Session registered with server: \(session.id)", category: AppLogger.Category.session)
        } catch {
            AppLogger.shared.error("Failed to register session: \(error)", category: AppLogger.Category.network)
        }
    }

    /// Updates the server with the current location (call when location improves)
    func updateSessionLocation(_ location: LocationCoordinate) async {
        guard let session = currentSession else { return }

        // Skip if location hasn't changed significantly (within ~10 meters)
        if let lastLocation = lastReportedLocation {
            let latDiff = abs(lastLocation.latitude - location.latitude)
            let lonDiff = abs(lastLocation.longitude - location.longitude)
            if latDiff < 0.0001 && lonDiff < 0.0001 {
                return
            }
        }

        lastReportedLocation = location

        do {
            try await sessionService.updateSessionLocation(
                sessionId: session.id,
                lat: location.latitude,
                lon: location.longitude
            )
            AppLogger.shared.debug("Updated session location: (\(location.latitude), \(location.longitude))", category: AppLogger.Category.session)
        } catch {
            AppLogger.shared.error("Failed to update session location: \(error)", category: AppLogger.Category.network)
        }
    }

    func selectRestaurant(_ restaurant: RestaurantResponse) async {
        selectedRestaurant = restaurant

        // Ensure we have a session
        if currentSession == nil {
            createLocalSession()
        }

        guard let session = currentSession else { return }

        analyticsService.track(
            event: .restaurantSelected,
            sessionId: session.id,
            meta: ["restaurant_id": restaurant.id]
        )

        // Update session with restaurant selection
        currentSession = SessionInfo(
            id: session.id,
            restaurantId: restaurant.id,
            restaurantName: restaurant.name
        )

        // Tell server about restaurant selection
        do {
            try await sessionService.pickRestaurant(sessionId: session.id, restaurantId: restaurant.id)
        } catch {
            AppLogger.shared.error("Failed to pick restaurant: \(error)", category: AppLogger.Category.network)
        }

        // Show preference sheet before starting recommendation generation
        showPreferenceSheet = true
    }

    /// Called when user confirms preferences and wants to proceed with recommendations
    func confirmPreferencesAndProceed() async {
        showPreferenceSheet = false

        analyticsService.track(
            event: .sliderSet,
            sessionId: currentSession?.id,
            meta: [
                "adventurousness": "\(userPreferences.food.adventurousness)",
                "spice": "\(userPreferences.food.spiceTolerance)",
                "richness": "\(userPreferences.food.richness)"
            ]
        )

        await startRecommendationGeneration()
    }

    /// Triggers recommendation generation and navigates to CalculatingView
    func startRecommendationGeneration() async {
        guard let session = currentSession else { return }

        do {
            let jobResponse = try await recommendationService.generateRecommendations(
                sessionId: session.id,
                includeReviews: true
            )
            jobId = jobResponse.jobId
            // Create the viewModel once and store it, passing user preferences
            calculatingViewModel = CalculatingViewModel(
                sessionId: session.id,
                jobId: jobResponse.jobId,
                preferences: userPreferences,
                recommendationService: recommendationService
            )
            showCalculating = true
        } catch {
            self.error = handleNetworkError(error)
        }
    }

    func acceptPhoto(_ photo: UIImage) async {
        // Create session if not exists
        if currentSession == nil {
            createLocalSession()
        }

        guard let session = currentSession else { return }

        let capturedPhoto = CapturedPhoto(id: UUID().uuidString, image: photo)
        capturedPhotos.append(capturedPhoto)

        analyticsService.track(event: .photoAccepted, sessionId: session.id, meta: nil)

        // Upload photo in background
        Task {
            await uploadPhoto(capturedPhoto, sessionId: session.id)
        }
    }

    private func uploadPhoto(_ photo: CapturedPhoto, sessionId: String) async {
        guard let imageData = photo.image.jpegData(compressionQuality: AppConstants.Camera.compressionQuality) else {
            return
        }

        do {
            _ = try await sessionService.uploadPhoto(sessionId: sessionId, imageData: imageData)
            // Mark as uploaded (in real app, update the photo state)
        } catch {
            AppLogger.shared.error("Failed to upload photo: \(error)", category: AppLogger.Category.network)
        }
    }

    func cancelSession() {
        capturedPhotos.removeAll()
        currentSession = nil
        selectedRestaurant = nil
        pendingPhoto = nil
    }

    func resetSession() {
        // Reset navigation state
        showCalculating = false
        showPhotoReview = false
        showPreferenceSheet = false

        // Reset recommendation state
        jobId = nil
        calculatingViewModel = nil

        // Reset session data
        capturedPhotos.removeAll()
        currentSession = nil
        selectedRestaurant = nil
        pendingPhoto = nil
        lastReportedLocation = nil
        sessionRegistered = false

        // Reset preferences to default
        userPreferences = .default
    }

    var mostLikelyRestaurant: RestaurantResponse? {
        nearbyRestaurants.first
    }
}

// MARK: - Supporting Types

enum CameraState {
    case stopped
    case starting
    case running
    case error
    case permissionDenied
}

struct SessionInfo {
    let id: String
    let restaurantId: String?
    let restaurantName: String?
}

struct CapturedPhoto: Identifiable {
    let id: String
    let image: UIImage
    var uploaded: Bool = false
}
