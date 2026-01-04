//
//  CameraViewModel.swift
//  AILaCarte
//
//  Created by Claude on 1/4/26.
//

import Foundation
import SwiftUI
import AVFoundation

/// ViewModel responsible for camera operations
@MainActor
@Observable
final class CameraViewModel: BaseViewModel {
    // Camera state
    var cameraState: CameraState = .stopped

    // Captured photo awaiting review
    var pendingPhoto: UIImage?
    var showPhotoReview = false

    let cameraService: CameraServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol

    init(
        cameraService: CameraServiceProtocol,
        analyticsService: AnalyticsServiceProtocol
    ) {
        self.cameraService = cameraService
        self.analyticsService = analyticsService
        super.init()
    }

    // MARK: - Camera Permission

    var cameraPermissionStatus: CameraAuthorizationStatus {
        cameraService.authorizationStatus
    }

    // MARK: - Camera Operations

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
            AppLogger.shared.info("CameraViewModel: Camera state -> running", category: AppLogger.Category.camera)
            cameraState = .running
        } catch {
            AppLogger.shared.error("CameraViewModel: Camera error: \(error)", category: AppLogger.Category.camera)
            self.error = handleNetworkError(error)
            cameraState = .error
        }
    }

    func stopCamera() {
        cameraService.stopSession()
        cameraState = .stopped
    }

    func capturePhoto(sessionId: String?) async {
        guard cameraState == .running else { return }

        do {
            let photo = try await cameraService.capturePhoto()
            pendingPhoto = photo
            showPhotoReview = true

            analyticsService.track(event: .photoCaptured, sessionId: sessionId, meta: nil)
        } catch {
            self.error = handleNetworkError(error)
        }
    }

    func clearPendingPhoto() {
        pendingPhoto = nil
        showPhotoReview = false
    }
}
