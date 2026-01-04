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
    var pendingPhoto: UIImage? {
        get { cameraViewModel.pendingPhoto }
        set { cameraViewModel.pendingPhoto = newValue }
    }
    var showPhotoReview: Bool {
        get { cameraViewModel.showPhotoReview }
        set { cameraViewModel.showPhotoReview = newValue }
    }
    var cameraPermissionStatus: CameraAuthorizationStatus { cameraViewModel.cameraPermissionStatus }

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
        await cameraViewModel.capturePhoto(sessionId: sessionViewModel.currentSession?.id)
    }

    // MARK: - Location Operations

    func requestLocationPermission() async {
        await locationViewModel.requestLocationPermission()
    }

    func fetchNearbyRestaurants() async {
        // Ensure session exists before fetching
        sessionViewModel.ensureSession()

        await locationViewModel.fetchNearbyRestaurants(sessionId: sessionViewModel.currentSession?.id)

        // Update session location if we got one
        if let location = locationViewModel.currentLocation {
            Task {
                await sessionViewModel.updateSessionLocation(location)
            }
        }
    }

    // MARK: - Restaurant Selection

    func selectRestaurant(_ restaurant: RestaurantResponse) async {
        await sessionViewModel.selectRestaurant(restaurant)
    }

    // MARK: - Photo Management

    func acceptPhoto(_ photo: UIImage) async {
        await sessionViewModel.acceptPhoto(photo)
    }

    // MARK: - Recommendation Flow

    func confirmPreferencesAndProceed() async {
        await sessionViewModel.confirmPreferencesAndProceed(preferences: userPreferences)
    }

    // MARK: - Preferences

    func resetPreferences() {
        preferenceManager.resetPreferences()
    }

    // MARK: - Session Management

    func cancelSession() {
        sessionViewModel.cancelSession()
        cameraViewModel.clearPendingPhoto()
    }

    func resetSession() {
        sessionViewModel.resetSession()
        cameraViewModel.clearPendingPhoto()
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
