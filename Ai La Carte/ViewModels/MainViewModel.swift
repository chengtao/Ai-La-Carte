//
//  MainViewModel.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation
import SwiftUI
import AVFoundation

@Observable
final class MainViewModel: BaseViewModel {
    // Camera state
    var cameraState: CameraState = .stopped
    var captureSession: AVCaptureSession?

    // Location & Restaurants
    var nearbyRestaurants: [RestaurantResponse] = []
    var selectedRestaurant: RestaurantResponse?
    var isLoadingRestaurants = false

    // Session state
    var currentSession: SessionInfo?
    var capturedPhotos: [CapturedPhoto] = []

    // Navigation
    var showPhotoReview = false
    var showPreferences = false
    var pendingPhoto: UIImage?

    private let restaurantService: RestaurantAPIServiceProtocol
    private let sessionService: SessionAPIServiceProtocol
    private let locationService: LocationServiceProtocol
    let cameraService: CameraServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol

    init(
        restaurantService: RestaurantAPIServiceProtocol,
        sessionService: SessionAPIServiceProtocol,
        locationService: LocationServiceProtocol,
        cameraService: CameraServiceProtocol,
        analyticsService: AnalyticsServiceProtocol
    ) {
        self.restaurantService = restaurantService
        self.sessionService = sessionService
        self.locationService = locationService
        self.cameraService = cameraService
        self.analyticsService = analyticsService
        super.init()
    }

    // MARK: - Camera

    @MainActor
    func startCamera() async {
        guard cameraService.authorizationStatus.isAuthorized else {
            cameraState = .permissionDenied
            return
        }

        cameraState = .starting

        do {
            try await cameraService.startSession()
            cameraState = .running
        } catch {
            self.error = handleNetworkError(error)
            cameraState = .error
        }
    }

    func stopCamera() {
        cameraService.stopSession()
        cameraState = .stopped
    }

    @MainActor
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

    @MainActor
    func fetchNearbyRestaurants() async {
        guard locationService.authorizationStatus.isAuthorized else {
            return
        }

        isLoadingRestaurants = true

        do {
            let location = try await locationService.getCurrentLocation()
            let restaurants = try await restaurantService.getNearbyRestaurants(
                lat: location.latitude,
                lon: location.longitude,
                radius: AppConstants.Location.defaultSearchRadius
            )

            self.nearbyRestaurants = restaurants

            analyticsService.track(
                event: .restaurantSuggestedShown,
                sessionId: nil,
                meta: ["count": "\(restaurants.count)"]
            )
        } catch {
            AppLogger.shared.error("Failed to fetch restaurants: \(error)", category: AppLogger.Category.network)
        }

        isLoadingRestaurants = false
    }

    // MARK: - Session Management

    @MainActor
    func selectRestaurant(_ restaurant: RestaurantResponse) async {
        selectedRestaurant = restaurant

        analyticsService.track(
            event: .restaurantSelected,
            sessionId: nil,
            meta: ["restaurant_id": restaurant.id]
        )

        // Create session and navigate to preferences
        await createSession(restaurantId: restaurant.id, restaurantName: restaurant.name)
        showPreferences = true
    }

    @MainActor
    func createSession(restaurantId: String?, restaurantName: String? = nil) async {
        do {
            let context: SessionContext?
            if let location = try? await locationService.getCurrentLocation() {
                context = SessionContext(lat: location.latitude, lon: location.longitude)
            } else {
                context = nil
            }

            let response = try await sessionService.createSession(restaurantId: restaurantId, context: context)

            currentSession = SessionInfo(
                id: response.sessionId,
                restaurantId: restaurantId,
                restaurantName: restaurantName
            )
        } catch {
            self.error = handleNetworkError(error)
        }
    }

    @MainActor
    func acceptPhoto(_ photo: UIImage) async {
        // Create session if not exists
        if currentSession == nil {
            await createSession(restaurantId: nil)
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

    func proceedToRecommendations() {
        guard !capturedPhotos.isEmpty || selectedRestaurant != nil else { return }

        analyticsService.track(event: .recommendClicked, sessionId: currentSession?.id, meta: nil)
        showPreferences = true
    }

    func cancelSession() {
        capturedPhotos.removeAll()
        currentSession = nil
        selectedRestaurant = nil
        pendingPhoto = nil
    }

    var hasPhotosOrRestaurant: Bool {
        !capturedPhotos.isEmpty || selectedRestaurant != nil
    }

    var mostLikelyRestaurant: RestaurantResponse? {
        nearbyRestaurants.first { $0.confidence >= 80 }
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
