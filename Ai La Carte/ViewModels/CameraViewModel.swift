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

    // Torch state
    var isTorchOn: Bool = false

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
        // Turn off torch before stopping
        if isTorchOn {
            setTorch(on: false)
        }
        cameraService.stopSession()
        cameraState = .stopped
    }

    /// Captures a photo and returns it directly (no review trigger)
    func capturePhoto(sessionId: String?) async -> UIImage? {
        guard cameraState == .running else { return nil }

        do {
            let photo = try await cameraService.capturePhoto()
            analyticsService.track(event: .photoCaptured, sessionId: sessionId, meta: nil)
            return photo
        } catch {
            self.error = handleNetworkError(error)
            return nil
        }
    }

    // MARK: - Torch Control

    var isTorchAvailable: Bool {
        cameraService.isTorchAvailable
    }

    func toggleTorch() {
        do {
            try cameraService.toggleTorch()
            isTorchOn = cameraService.isTorchOn
        } catch {
            AppLogger.shared.error("Failed to toggle torch: \(error)", category: AppLogger.Category.camera)
        }
    }

    func setTorch(on: Bool) {
        do {
            try cameraService.setTorch(on: on)
            isTorchOn = cameraService.isTorchOn
        } catch {
            AppLogger.shared.error("Failed to set torch: \(error)", category: AppLogger.Category.camera)
        }
    }
}
