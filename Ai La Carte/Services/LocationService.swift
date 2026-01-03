//
//  LocationService.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation
import CoreLocation

final class LocationService: NSObject, LocationServiceProtocol {
    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<LocationCoordinate, Error>?
    private var authorizationContinuation: CheckedContinuation<LocationAuthorizationStatus, Never>?

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
            self.authorizationContinuation = continuation
            locationManager.requestWhenInUseAuthorization()
        }
    }

    func getCurrentLocation() async throws -> LocationCoordinate {
        guard authorizationStatus.isAuthorized else {
            throw LocationError.accessDenied
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            locationManager.requestLocation()
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            locationContinuation?.resume(throwing: LocationError.locationNotFound)
            locationContinuation = nil
            return
        }

        let coordinate = LocationCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )

        AppLogger.shared.info("Location updated: (\(coordinate.latitude), \(coordinate.longitude))", category: AppLogger.Category.location)
        locationContinuation?.resume(returning: coordinate)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        AppLogger.shared.error("Location error: \(error)", category: AppLogger.Category.location)

        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                locationContinuation?.resume(throwing: LocationError.accessDenied)
            case .locationUnknown:
                locationContinuation?.resume(throwing: LocationError.locationNotFound)
            default:
                locationContinuation?.resume(throwing: LocationError.notAvailable)
            }
        } else {
            locationContinuation?.resume(throwing: LocationError.notAvailable)
        }

        locationContinuation = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = authorizationStatus
        AppLogger.shared.info("Location authorization changed: \(status)", category: AppLogger.Category.location)
        authorizationContinuation?.resume(returning: status)
        authorizationContinuation = nil
    }
}
