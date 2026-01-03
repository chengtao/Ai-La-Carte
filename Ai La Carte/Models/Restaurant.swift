//
//  Restaurant.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class Restaurant {
    @Attribute(.unique) var id: String
    var name: String
    var latitude: Double
    var longitude: Double
    var hasFoodMenu: Bool
    var hasWineMenu: Bool
    var menuUpdatedAt: Date?
    var confidenceScore: Int // 0-100

    init(
        id: String,
        name: String,
        latitude: Double,
        longitude: Double,
        hasFoodMenu: Bool = false,
        hasWineMenu: Bool = false,
        menuUpdatedAt: Date? = nil,
        confidenceScore: Int = 0
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.hasFoodMenu = hasFoodMenu
        self.hasWineMenu = hasWineMenu
        self.menuUpdatedAt = menuUpdatedAt
        self.confidenceScore = confidenceScore
    }

    var location: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func distance(from userLocation: CLLocation) -> Double {
        let restaurantLocation = CLLocation(latitude: latitude, longitude: longitude)
        return userLocation.distance(from: restaurantLocation)
    }
}

// MARK: - Restaurant Response DTO

struct RestaurantResponse: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let distanceMeters: Double
    let hasFoodMenu: Bool
    let hasWineMenu: Bool
    let menuUpdatedAt: String?
    let confidence: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case distanceMeters = "distance_m"
        case hasFoodMenu = "has_food_menu"
        case hasWineMenu = "has_wine_menu"
        case menuUpdatedAt = "menu_updated_at"
        case confidence
    }

    var formattedDistance: String {
        if distanceMeters < 1000 {
            return "\(Int(distanceMeters))m"
        } else {
            let km = distanceMeters / 1000
            return String(format: "%.1fkm", km)
        }
    }

    var menuAgeDescription: String? {
        guard let dateString = menuUpdatedAt else { return nil }

        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return nil }

        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0

        if days == 0 {
            return "Updated today"
        } else if days == 1 {
            return "Updated yesterday"
        } else if days < 7 {
            return "Updated \(days)d ago"
        } else if days < 30 {
            let weeks = days / 7
            return "Updated \(weeks)w ago"
        } else {
            let months = days / 30
            return "Updated \(months)mo ago"
        }
    }
}

struct RestaurantListResponse: Codable {
    let restaurants: [RestaurantResponse]
}
