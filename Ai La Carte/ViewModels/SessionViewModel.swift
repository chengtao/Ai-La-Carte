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

    // Loading state for preference sheet (while creating job)
    var isPreparingRecommendation = false

    // Recommendation generation
    var jobId: String?
    var calculatingViewModel: CalculatingViewModel?

    private let sessionService: SessionAPIServiceProtocol
    private let menuService: MenuAPIServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol

    init(
        sessionService: SessionAPIServiceProtocol,
        menuService: MenuAPIServiceProtocol,
        analyticsService: AnalyticsServiceProtocol
    ) {
        self.sessionService = sessionService
        self.menuService = menuService
        self.analyticsService = analyticsService
        super.init()
    }

    // MARK: - Session Management

    /// Creates a new local session with UUID - call this when starting a recommendation flow
    func createLocalSession() {
        let sessionId = UUID().uuidString
        currentSession = SessionInfo(id: sessionId)

        AppLogger.shared.info("Created local session: \(sessionId)", category: AppLogger.Category.session)
    }

    /// Ensures a session exists, creating one if necessary
    func ensureSession() {
        if currentSession == nil {
            createLocalSession()
        }
    }

    // MARK: - Restaurant Selection

    /// Selects a nearby restaurant (with existing menus or for photo scan)
    func selectRestaurant(_ restaurant: RestaurantResponse, location: LocationCoordinate?) async {
        selectedRestaurant = restaurant

        ensureSession()
        guard let session = currentSession else { return }

        analyticsService.track(
            event: .restaurantSelected,
            sessionId: session.id,
            meta: [
                "restaurant_id": restaurant.id,
                "has_existing_menus": "\(restaurant.hasExistingMenus)"
            ]
        )

        // Update session with restaurant selection, menu IDs, and location
        currentSession = SessionInfo(
            id: session.id,
            restaurantId: restaurant.id,
            restaurantName: restaurant.name,
            foodMenuId: restaurant.latestFoodMenuId,
            wineMenuId: restaurant.latestWineMenuId,
            latitude: location?.latitude,
            longitude: location?.longitude
        )

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
    func confirmPreferencesAndProceed(preferences: UserPreferences, location: LocationCoordinate?) async {
        // Show loading state while preparing (don't dismiss sheet yet!)
        isPreparingRecommendation = true

        // Update session with location if not already set (photo scan flow)
        if let session = currentSession, session.latitude == nil, let location = location {
            currentSession = SessionInfo(
                id: session.id,
                restaurantId: session.restaurantId,
                restaurantName: session.restaurantName,
                foodMenuId: session.foodMenuId,
                wineMenuId: session.wineMenuId,
                latitude: location.latitude,
                longitude: location.longitude
            )
        }

        analyticsService.track(
            event: .sliderSet,
            sessionId: currentSession?.id,
            meta: [
                "ingredients": preferences.food.ingredients.map { $0.rawValue }.joined(separator: ","),
                "spice": "\(preferences.food.spicePreference)",
                "richness": "\(preferences.food.richness)"
            ]
        )

        await startRecommendationGeneration(preferences: preferences)

        // Clear loading state after completion
        isPreparingRecommendation = false
    }

    /// Triggers recommendation generation and navigates to CalculatingView
    func startRecommendationGeneration(preferences: UserPreferences) async {
        guard let session = currentSession else {
            self.error = AppError.notFound("No active session")
            return
        }

        // FLOW A: Restaurant has existing menus -> artificial delay mode (no createMenus call)
        if session.hasExistingMenus {
            calculatingViewModel = CalculatingViewModel(
                sessionId: session.id,
                mode: .artificialDelay(foodMenuId: session.foodMenuId, wineMenuId: session.wineMenuId),
                preferences: preferences,
                menuService: menuService
            )
            // Dismiss sheet and show calculating view TOGETHER to prevent race condition
            showPreferenceSheet = false
            showCalculating = true
            return
        }

        // FLOW B: Photo scan -> createMenus(sessionId, lat, lon) -> polling mode
        // Location is optional - backend will handle missing location gracefully
        do {
            let jobResponse = try await menuService.createMenus(
                sessionId: session.id,
                lat: session.latitude,
                lon: session.longitude
            )
            jobId = jobResponse.jobId

            calculatingViewModel = CalculatingViewModel(
                sessionId: session.id,
                mode: .polling(jobId: jobResponse.jobId),
                preferences: preferences,
                menuService: menuService
            )
            // Dismiss sheet and show calculating view TOGETHER to prevent race condition
            showPreferenceSheet = false
            showCalculating = true
        } catch {
            // On error, keep sheet open and show error to user
            self.error = handleNetworkError(error)
            AppLogger.shared.error("Failed to create menus: \(error)", category: AppLogger.Category.recommendation)
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
        isPreparingRecommendation = false

        // Reset recommendation state
        jobId = nil
        calculatingViewModel = nil

        // Reset session data
        capturedPhotos.removeAll()
        pendingPhotos.removeAll()
        currentSession = nil
        selectedRestaurant = nil
    }
}
