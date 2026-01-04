//
//  LocationViewModel.swift
//  AILaCarte
//
//  Created by Claude on 1/4/26.
//

import Foundation

/// ViewModel responsible for location services and nearby restaurant fetching
@MainActor
@Observable
final class LocationViewModel: BaseViewModel {
    // Location & Restaurants
    var nearbyRestaurants: [RestaurantResponse] = []
    var isLoadingRestaurants = false
    private(set) var currentLocation: LocationCoordinate?

    private let locationService: LocationServiceProtocol
    private let restaurantService: RestaurantAPIServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol

    init(
        locationService: LocationServiceProtocol,
        restaurantService: RestaurantAPIServiceProtocol,
        analyticsService: AnalyticsServiceProtocol
    ) {
        self.locationService = locationService
        self.restaurantService = restaurantService
        self.analyticsService = analyticsService
        super.init()
    }

    // MARK: - Location Permission

    var locationPermissionStatus: LocationAuthorizationStatus {
        locationService.authorizationStatus
    }

    func requestLocationPermission() async {
        _ = await locationService.requestWhenInUseAuthorization()
    }

    // MARK: - Location Operations

    func fetchCurrentLocation() async -> LocationCoordinate? {
        // Request permission if not determined
        if locationService.authorizationStatus == .notDetermined {
            let status = await locationService.requestWhenInUseAuthorization()
            if !status.isAuthorized {
                return nil
            }
        }

        guard locationService.authorizationStatus.isAuthorized else {
            return nil
        }

        do {
            let location = try await locationService.getCurrentLocation()
            currentLocation = location
            return location
        } catch {
            AppLogger.shared.error("Failed to get location: \(error)", category: AppLogger.Category.location)
            return nil
        }
    }

    func fetchNearbyRestaurants(sessionId: String?) async {
        isLoadingRestaurants = true

        guard let location = await fetchCurrentLocation() else {
            isLoadingRestaurants = false
            return
        }

        do {
            let restaurants = try await restaurantService.getNearbyRestaurants(
                lat: location.latitude,
                lon: location.longitude,
                radius: AppConstants.Location.defaultSearchRadius
            )

            self.nearbyRestaurants = restaurants

            analyticsService.track(
                event: .restaurantSuggestedShown,
                sessionId: sessionId,
                meta: ["count": "\(restaurants.count)"]
            )
        } catch {
            AppLogger.shared.error("Failed to fetch restaurants: \(error)", category: AppLogger.Category.network)
        }

        isLoadingRestaurants = false
    }

    var mostLikelyRestaurant: RestaurantResponse? {
        nearbyRestaurants.first
    }
}
