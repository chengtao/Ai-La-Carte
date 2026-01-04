//
//  SessionViewModel.swift
//  AILaCarte
//
//  Created by Claude on 1/4/26.
//

import Foundation
import SwiftUI

/// ViewModel responsible for session lifecycle management and photo handling
@MainActor
@Observable
final class SessionViewModel: BaseViewModel {
    // Session state
    var currentSession: SessionInfo?
    var capturedPhotos: [CapturedPhoto] = []
    var pendingPhotos: [CapturedPhoto] = []
    private var lastReportedLocation: LocationCoordinate?
    private var sessionRegistered = false

    // Photo limit computed properties
    var canCaptureMore: Bool {
        pendingPhotos.count < AppConstants.Photo.maxPhotos
    }

    var isAtPhotoLimit: Bool {
        pendingPhotos.count >= AppConstants.Photo.maxPhotos
    }

    // Restaurant selection
    var selectedRestaurant: RestaurantResponse?

    // Navigation
    var showPreferenceSheet = false
    var showCalculating = false

    // Recommendation generation
    var jobId: String?
    var calculatingViewModel: CalculatingViewModel?

    private let sessionService: SessionAPIServiceProtocol
    private let recommendationService: RecommendationAPIServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol

    init(
        sessionService: SessionAPIServiceProtocol,
        recommendationService: RecommendationAPIServiceProtocol,
        analyticsService: AnalyticsServiceProtocol
    ) {
        self.sessionService = sessionService
        self.recommendationService = recommendationService
        self.analyticsService = analyticsService
        super.init()
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

    /// Ensures a session exists, creating one if necessary
    func ensureSession() {
        if currentSession == nil {
            createLocalSession()
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

    // MARK: - Restaurant Selection

    func selectRestaurant(_ restaurant: RestaurantResponse) async {
        selectedRestaurant = restaurant

        ensureSession()
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

    // MARK: - Photo Management

    /// Adds a photo to the pending collection (pre-review, no upload)
    func addPendingPhoto(_ image: UIImage) {
        guard canCaptureMore else { return }

        ensureSession()
        let photo = CapturedPhoto(id: UUID().uuidString, image: image)
        pendingPhotos.append(photo)
    }

    /// Accepts photos from review, moves to capturedPhotos, and starts uploads
    func acceptPhotosFromReview(_ photos: [CapturedPhoto]) async {
        guard let session = currentSession else { return }

        // Move reviewed photos to capturedPhotos
        capturedPhotos = photos
        pendingPhotos.removeAll()

        analyticsService.track(
            event: .photoAccepted,
            sessionId: session.id,
            meta: ["count": "\(photos.count)"]
        )

        // Upload all accepted photos
        for photo in photos {
            Task {
                await uploadPhoto(photo, sessionId: session.id)
            }
        }
    }

    /// Clears all pending photos
    func clearPendingPhotos() {
        pendingPhotos.removeAll()
    }

    /// Updates pending photos (e.g., after review where some were deleted)
    func updatePendingPhotos(_ photos: [CapturedPhoto]) {
        pendingPhotos = photos
    }

    func acceptPhoto(_ photo: UIImage) async {
        ensureSession()
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

    // MARK: - Recommendation Generation

    /// Called when user confirms preferences and wants to proceed with recommendations
    func confirmPreferencesAndProceed(preferences: UserPreferences) async {
        showPreferenceSheet = false

        analyticsService.track(
            event: .sliderSet,
            sessionId: currentSession?.id,
            meta: [
                "adventurousness": "\(preferences.food.adventurousness)",
                "spice": "\(preferences.food.spiceTolerance)",
                "richness": "\(preferences.food.richness)"
            ]
        )

        await startRecommendationGeneration(preferences: preferences)
    }

    /// Triggers recommendation generation and navigates to CalculatingView
    func startRecommendationGeneration(preferences: UserPreferences) async {
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
                preferences: preferences,
                recommendationService: recommendationService
            )
            showCalculating = true
        } catch {
            self.error = handleNetworkError(error)
        }
    }

    // MARK: - Session Reset

    func cancelSession() {
        capturedPhotos.removeAll()
        pendingPhotos.removeAll()
        currentSession = nil
        selectedRestaurant = nil
    }

    func resetSession() {
        // Reset navigation state
        showCalculating = false
        showPreferenceSheet = false

        // Reset recommendation state
        jobId = nil
        calculatingViewModel = nil

        // Reset session data
        capturedPhotos.removeAll()
        pendingPhotos.removeAll()
        currentSession = nil
        selectedRestaurant = nil
        lastReportedLocation = nil
        sessionRegistered = false
    }
}
