//
//  MainViewModel.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation
import SwiftUI
import AVFoundation

/// Thin orchestrator ViewModel that coordinates CameraViewModel, LocationViewModel, and SessionViewModel
@MainActor
@Observable
final class MainViewModel: BaseViewModel {
    // Child ViewModels
    let cameraViewModel: CameraViewModel
    let locationViewModel: LocationViewModel
    let sessionViewModel: SessionViewModel

    // User preferences - managed by PreferenceManager
    private let preferenceManager: PreferenceManagerProtocol

    // Navigation state for photo carousel review
    var showPhotoCarouselReview = false
    var reviewLaunchedFromThumbnails = false

    var userPreferences: UserPreferences {
        get { preferenceManager.currentPreferences }
        set { preferenceManager.updatePreferences(newValue) }
    }

    init(
        cameraViewModel: CameraViewModel,
        locationViewModel: LocationViewModel,
        sessionViewModel: SessionViewModel,
        preferenceManager: PreferenceManagerProtocol
    ) {
        self.cameraViewModel = cameraViewModel
        self.locationViewModel = locationViewModel
        self.sessionViewModel = sessionViewModel
        self.preferenceManager = preferenceManager
        super.init()
    }

    // MARK: - Convenience Accessors (delegate to child ViewModels)

    // Camera
    var cameraState: CameraState { cameraViewModel.cameraState }
    var cameraService: CameraServiceProtocol { cameraViewModel.cameraService }
    var cameraPermissionStatus: CameraAuthorizationStatus { cameraViewModel.cameraPermissionStatus }

    // Torch
    var isTorchOn: Bool { cameraViewModel.isTorchOn }
    var isTorchAvailable: Bool { cameraViewModel.isTorchAvailable }

    func toggleTorch() {
        cameraViewModel.toggleTorch()
    }

    // Pending photos (pre-review)
    var pendingPhotos: [CapturedPhoto] { sessionViewModel.pendingPhotos }
    var canCaptureMore: Bool { sessionViewModel.canCaptureMore }
    var isAtPhotoLimit: Bool { sessionViewModel.isAtPhotoLimit }

    // Location
    var nearbyRestaurants: [RestaurantResponse] { locationViewModel.nearbyRestaurants }
    var isLoadingRestaurants: Bool { locationViewModel.isLoadingRestaurants }
    var locationPermissionStatus: LocationAuthorizationStatus { locationViewModel.locationPermissionStatus }
    var mostLikelyRestaurant: RestaurantResponse? { locationViewModel.mostLikelyRestaurant }

    // Session
    var currentSession: SessionInfo? { sessionViewModel.currentSession }
    var capturedPhotos: [CapturedPhoto] { sessionViewModel.capturedPhotos }
    var selectedRestaurant: RestaurantResponse? { sessionViewModel.selectedRestaurant }
    var showPreferenceSheet: Bool {
        get { sessionViewModel.showPreferenceSheet }
        set { sessionViewModel.showPreferenceSheet = newValue }
    }
    var showCalculating: Bool {
        get { sessionViewModel.showCalculating }
        set { sessionViewModel.showCalculating = newValue }
    }
    var calculatingViewModel: CalculatingViewModel? { sessionViewModel.calculatingViewModel }

    // MARK: - Camera Operations

    func startCamera() async {
        await cameraViewModel.startCamera()
    }

    func stopCamera() {
        cameraViewModel.stopCamera()
    }

    func capturePhoto() async {
        // If at limit, show carousel instead of capturing
        guard sessionViewModel.canCaptureMore else {
            showPhotoCarouselReview = true
            return
        }

        if let image = await cameraViewModel.capturePhoto(sessionId: sessionViewModel.currentSession?.id) {
            sessionViewModel.addPendingPhoto(image)
        }
    }

    // MARK: - Location Operations

    func requestLocationPermission() async {
        await locationViewModel.requestLocationPermission()
    }

    func fetchNearbyRestaurants() async {
        // Ensure session exists before fetching
        sessionViewModel.ensureSession()

        await locationViewModel.fetchNearbyRestaurants(sessionId: sessionViewModel.currentSession?.id)
    }

    // MARK: - Restaurant Selection

    func selectRestaurant(_ restaurant: RestaurantResponse) async {
        await sessionViewModel.selectRestaurant(restaurant, location: locationViewModel.currentLocation)
    }

    // MARK: - Photo Management

    func acceptPhoto(_ photo: UIImage) async {
        await sessionViewModel.acceptPhoto(photo)
    }

    // MARK: - Photo Review Flow

    /// Opens the photo carousel review view from thumbnails (hides Next button)
    func showReviewFromThumbnails() {
        guard !sessionViewModel.pendingPhotos.isEmpty else { return }
        reviewLaunchedFromThumbnails = true
        showPhotoCarouselReview = true
    }

    /// Opens the photo carousel review view from Recommend button (shows Next button)
    func showReviewFromRecommend() {
        guard !sessionViewModel.pendingPhotos.isEmpty else { return }
        reviewLaunchedFromThumbnails = false
        showPhotoCarouselReview = true
    }

    /// Completes the review and proceeds to preference sheet
    func completeReview(withPhotos photos: [CapturedPhoto]) async {
        showPhotoCarouselReview = false
        await sessionViewModel.acceptPhotosFromReview(photos)
        sessionViewModel.showPreferenceSheet = true
    }

    /// Returns to camera from review, syncing any deleted photos
    func returnToCamera(withPhotos photos: [CapturedPhoto]) {
        sessionViewModel.updatePendingPhotos(photos)
        showPhotoCarouselReview = false
    }

    /// Discards all pending photos and returns to camera
    func discardAllPendingPhotos() {
        sessionViewModel.clearPendingPhotos()
        showPhotoCarouselReview = false
    }

    // MARK: - Recommendation Flow

    func confirmPreferencesAndProceed() async {
        // Fetch location if not already available (photo scan flow)
        var location = locationViewModel.currentLocation
        if location == nil {
            location = await locationViewModel.fetchCurrentLocation()
        }

        await sessionViewModel.confirmPreferencesAndProceed(
            preferences: userPreferences,
            location: location
        )
    }

    // MARK: - Preferences

    func resetPreferences() {
        preferenceManager.resetPreferences()
    }

    // MARK: - Session Management

    func cancelSession() {
        sessionViewModel.cancelSession()
        showPhotoCarouselReview = false
    }

    func resetSession() {
        sessionViewModel.resetSession()
        showPhotoCarouselReview = false
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
    let foodMenuId: String?
    let wineMenuId: String?
    let latitude: Double?
    let longitude: Double?

    init(
        id: String,
        restaurantId: String? = nil,
        restaurantName: String? = nil,
        foodMenuId: String? = nil,
        wineMenuId: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.restaurantName = restaurantName
        self.foodMenuId = foodMenuId
        self.wineMenuId = wineMenuId
        self.latitude = latitude
        self.longitude = longitude
    }

    var hasExistingMenus: Bool {
        foodMenuId != nil || wineMenuId != nil
    }
}

struct CapturedPhoto: Identifiable {
    let id: String
    let image: UIImage
    var uploaded: Bool = false
}
