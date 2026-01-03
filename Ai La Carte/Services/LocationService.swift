//
//  LocationService.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation
import CoreLocation

// MARK: - Thread-safe Continuation Manager

private actor LocationContinuationManager {
    private var locationContinuation: CheckedContinuation<LocationCoordinate, Error>?
    private var authorizationContinuation: CheckedContinuation<LocationAuthorizationStatus, Never>?

    func setLocationContinuation(_ continuation: CheckedContinuation<LocationCoordinate, Error>) {
        locationContinuation = continuation
    }

    func setAuthContinuation(_ continuation: CheckedContinuation<LocationAuthorizationStatus, Never>) {
        authorizationContinuation = continuation
    }

    func resumeLocationWithSuccess(_ coordinate: LocationCoordinate) {
        locationContinuation?.resume(returning: coordinate)
        locationContinuation = nil
    }

    func resumeLocationWithError(_ error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }

    func resumeAuthWith(_ status: LocationAuthorizationStatus) {
        authorizationContinuation?.resume(returning: status)
        authorizationContinuation = nil
    }
}

// MARK: - Location Service

final class LocationService: NSObject, LocationServiceProtocol, @unchecked Sendable {
    // Note: @unchecked Sendable because we manage thread safety via actor

    private let locationManager = CLLocationManager()
    private let continuationManager = LocationContinuationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    var authorizationStatus: LocationAuthorizationStatus {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorizedWhenInUse:
            return .authorizedWhenInUse
        case .authorizedAlways:
            return .authorizedAlways
        @unknown default:
            return .notDetermined
        }
    }

    func requestWhenInUseAuthorization() async -> LocationAuthorizationStatus {
        if authorizationStatus != .notDetermined {
            return authorizationStatus
        }

        return await withCheckedContinuation { continuation in
            // Store continuation in actor for thread-safe access
            Task {
                await self.continuationManager.setAuthContinuation(continuation)
            }
            // Must be called on main thread
            DispatchQueue.main.async {
                self.locationManager.requestWhenInUseAuthorization()
            }
        }
    }

    func getCurrentLocation() async throws -> LocationCoordinate {
        guard authorizationStatus.isAuthorized else {
            throw LocationError.accessDenied
        }

        return try await withCheckedThrowingContinuation { continuation in
            // Store continuation in actor for thread-safe access
            Task {
                await self.continuationManager.setLocationContinuation(continuation)
            }
            // Must be called on main thread
            DispatchQueue.main.async {
                self.locationManager.requestLocation()
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Use Task to safely access the actor-isolated continuation
        Task {
            guard let location = locations.last else {
                await continuationManager.resumeLocationWithError(LocationError.locationNotFound)
                return
            }

            let coordinate = LocationCoordinate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )

            AppLogger.shared.info("Location updated: (\(coordinate.latitude), \(coordinate.longitude))", category: AppLogger.Category.location)
            await continuationManager.resumeLocationWithSuccess(coordinate)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Use Task to safely access the actor-isolated continuation
        Task {
            AppLogger.shared.error("Location error: \(error)", category: AppLogger.Category.location)

            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    await continuationManager.resumeLocationWithError(LocationError.accessDenied)
                case .locationUnknown:
                    await continuationManager.resumeLocationWithError(LocationError.locationNotFound)
                default:
                    await continuationManager.resumeLocationWithError(LocationError.notAvailable)
                }
            } else {
                await continuationManager.resumeLocationWithError(LocationError.notAvailable)
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Use Task to safely access the actor-isolated continuation
        Task {
            let status = authorizationStatus
            AppLogger.shared.info("Location authorization changed: \(status)", category: AppLogger.Category.location)
            await continuationManager.resumeAuthWith(status)
        }
    }
}
