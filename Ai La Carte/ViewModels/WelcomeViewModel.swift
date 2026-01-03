//
//  WelcomeViewModel.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class WelcomeViewModel: BaseViewModel {
    var locationPermissionStatus: LocationAuthorizationStatus = .notDetermined
    var cameraPermissionStatus: CameraAuthorizationStatus = .notDetermined
    var currentStep: OnboardingStep = .welcome
    var didCompleteOnboarding = false

    private let locationService: LocationServiceProtocol
    private let cameraService: CameraServiceProtocol

    init(locationService: LocationServiceProtocol, cameraService: CameraServiceProtocol) {
        self.locationService = locationService
        self.cameraService = cameraService
        super.init()

        // Check current status
        self.locationPermissionStatus = locationService.authorizationStatus
        self.cameraPermissionStatus = cameraService.authorizationStatus
    }

    func requestPermissions() async {
        isLoading = true
        currentStep = .requestingLocation

        // Request location permission
        locationPermissionStatus = await locationService.requestWhenInUseAuthorization()

        currentStep = .requestingCamera

        // Request camera permission
        cameraPermissionStatus = await cameraService.requestAuthorization()

        isLoading = false
        currentStep = .completed
    }

    func proceedWithoutPermissions() {
        currentStep = .completed
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: AppConstants.Storage.onboardingCompletedKey)
        didCompleteOnboarding = true
    }

    var canProceed: Bool {
        // Allow proceeding even without all permissions
        true
    }

    var hasAllPermissions: Bool {
        locationPermissionStatus.isAuthorized && cameraPermissionStatus.isAuthorized
    }
}

enum OnboardingStep {
    case welcome
    case requestingLocation
    case requestingCamera
    case completed

    var title: String {
        switch self {
        case .welcome:
            return "Welcome to AI La Carte"
        case .requestingLocation:
            return "Enable Location"
        case .requestingCamera:
            return "Enable Camera"
        case .completed:
            return "You're all set!"
        }
    }
}
