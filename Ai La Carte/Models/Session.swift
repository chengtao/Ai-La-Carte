//
//  Session.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation
import SwiftData

@Model
final class Session {
    @Attribute(.unique) var id: String
    var createdAt: Date
    var restaurantId: String?
    var restaurantName: String?
    var statusRaw: String

    // Session preferences
    var ingredientsJSON: String? // JSON encoded Set<FoodIngredient>
    var richness: Int? // 1-5
    var spicePreference: Int? // 1-5

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \PhotoAsset.session) var photos: [PhotoAsset] = []
    @Relationship(deleteRule: .cascade, inverse: \RecommendationItem.session) var recommendations: [RecommendationItem] = []
    var user: User?

    var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .created }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        createdAt: Date = Date(),
        restaurantId: String? = nil,
        restaurantName: String? = nil,
        status: SessionStatus = .created
    ) {
        self.id = id
        self.createdAt = createdAt
        self.restaurantId = restaurantId
        self.restaurantName = restaurantName
        self.statusRaw = status.rawValue
    }

    var foodPreference: FoodPreference? {
        guard let spice = spicePreference else { return nil }
        let ingredients: Set<FoodIngredient>
        if let json = ingredientsJSON,
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(Set<FoodIngredient>.self, from: data) {
            ingredients = decoded
        } else {
            ingredients = []
        }
        return FoodPreference(ingredients: ingredients, richness: richness ?? 3, spicePreference: spice)
    }

    func setPreference(_ preference: FoodPreference) {
        if let data = try? JSONEncoder().encode(preference.ingredients),
           let json = String(data: data, encoding: .utf8) {
            self.ingredientsJSON = json
        }
        self.richness = preference.richness
        self.spicePreference = preference.spicePreference
    }

    var foodRecommendations: [RecommendationItem] {
        recommendations.filter { $0.type == .food }
    }

    var wineRecommendations: [RecommendationItem] {
        recommendations.filter { $0.type == .wine }
    }
}

// MARK: - Session Status

enum SessionStatus: String, Codable {
    case created
    case photosUploading = "uploading_photos"
    case parsingMenu = "parsing_menu"
    case collectingReviews = "collecting_reviews"
    case buildingProfile = "building_profile"
    case ranking
    case done
    case failed

    var displayText: String {
        switch self {
        case .created:
            return "Getting started..."
        case .photosUploading:
            return "Preparing the menu..."
        case .parsingMenu:
            return "Reading the menu..."
        case .collectingReviews:
            return "Collecting public reviews from other websites..."
        case .buildingProfile:
            return "Analyzing your taste preferences..."
        case .ranking:
            return "Finding the perfect dishes for you..."
        case .done:
            return "Ready!"
        case .failed:
            return "Something went wrong"
        }
    }

    var progress: Double {
        switch self {
        case .created: return 0.0
        case .photosUploading: return 0.15
        case .parsingMenu: return 0.30
        case .collectingReviews: return 0.50
        case .buildingProfile: return 0.70
        case .ranking: return 0.85
        case .done: return 1.0
        case .failed: return 0.0
        }
    }

    var isInProgress: Bool {
        switch self {
        case .created, .photosUploading, .parsingMenu, .collectingReviews, .buildingProfile, .ranking:
            return true
        case .done, .failed:
            return false
        }
    }
}

// MARK: - Food Ingredient

enum FoodIngredient: String, Codable, CaseIterable, Identifiable {
    case beef = "Beef"
    case pork = "Pork"
    case chicken = "Chicken"
    case seafood = "Seafood"
    case noodle = "Noodle"
    case rice = "Rice"
    case other = "Other"
    
    var id: String { rawValue }
}

// MARK: - Food Preference

struct FoodPreference: Codable, Equatable {
    var ingredients: Set<FoodIngredient>  // Selected ingredient preferences
    var richness: Int                      // 1 = Light, 5 = Rich
    var spicePreference: Int               // 1 = Non-spicy, 5 = The spicier the better

    static let `default` = FoodPreference(ingredients: [], richness: 3, spicePreference: 3)

    var spiceLabel: String {
        switch spicePreference {
        case 1: return "No spice"
        case 2: return "Mild"
        case 3: return "Medium"
        case 4: return "Spicy"
        case 5: return "Bring the heat!"
        default: return "Medium"
        }
    }

    var richnessLabel: String {
        switch richness {
        case 1: return "Very light"
        case 2: return "Light"
        case 3: return "Balanced"
        case 4: return "Rich"
        case 5: return "Very rich"
        default: return "Balanced"
        }
    }
}

// MARK: - Wine Preference

struct WinePreference: Codable, Equatable {
    var countries: Set<WineCountry>
    var whiteVarietals: Set<WhiteGrapeVarietal>
    var redVarietals: Set<RedGrapeVarietal>
    var flavors: Set<WineFlavor>
    var categories: Set<WineCategory>

    static let `default` = WinePreference(
        countries: [],
        whiteVarietals: [],
        redVarietals: [],
        flavors: [],
        categories: []
    )

    var isEmpty: Bool {
        countries.isEmpty && whiteVarietals.isEmpty && redVarietals.isEmpty && flavors.isEmpty && categories.isEmpty
    }
}

enum WineCountry: String, Codable, CaseIterable, Identifiable {
    case france = "France"
    case usa = "USA"
    case italy = "Italy"
    case spain = "Spain"
    case others = "Others"

    var id: String { rawValue }
}

enum WhiteGrapeVarietal: String, Codable, CaseIterable, Identifiable {
    case sauvignonBlanc = "Sauvignon Blanc"
    case chardonnay = "Chardonnay"
    case pinotGrigio = "Pinot Grigio"
    case others = "Others"

    var id: String { rawValue }
}

enum RedGrapeVarietal: String, Codable, CaseIterable, Identifiable {
    case pinotNoir = "Pinot Noir"
    case cabernetSauvignon = "Cabernet Sauvignon"
    case merlot = "Merlot"
    case others = "Others"

    var id: String { rawValue }
}

enum WineFlavor: String, Codable, CaseIterable, Identifiable {
    case elegant = "Elegant"
    case fruity = "Fruity"
    case fullBody = "Full-Body"
    case sweet = "Sweet"
    case acidic = "Acidic"

    var id: String { rawValue }
}

// MARK: - Combined User Preferences

struct UserPreferences: Codable, Equatable {
    var food: FoodPreference
    var wine: WinePreference

    static let `default` = UserPreferences(food: .default, wine: .default)
}

// Type alias for backwards compatibility during migration
typealias SessionPreference = FoodPreference

// MARK: - Session Response DTOs

struct SessionResponse: Codable {
    let sessionId: String

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
    }
}

struct JobStatusResponse: Codable {
    let status: String
    let progress: Double?
    let foodMenuId: String?
    let wineMenuId: String?

    enum CodingKeys: String, CodingKey {
        case status, progress
        case foodMenuId = "food_menu_id"
        case wineMenuId = "wine_menu_id"
    }

    var sessionStatus: SessionStatus {
        SessionStatus(rawValue: status) ?? .created
    }

    /// Returns true if at least one menu ID exists
    var hasMenus: Bool {
        foodMenuId != nil || wineMenuId != nil
    }
}
