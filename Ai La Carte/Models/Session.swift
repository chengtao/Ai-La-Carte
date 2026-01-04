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
    var adventurousClassic: Int? // 1-5
    var spiceTolerance: Int? // 1-5
    var richness: Int? // 1-5

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
        guard let adv = adventurousClassic, let spice = spiceTolerance else { return nil }
        return FoodPreference(adventurousness: adv, spiceTolerance: spice, richness: richness ?? 3)
    }

    func setPreference(_ preference: FoodPreference) {
        self.adventurousClassic = preference.adventurousness
        self.spiceTolerance = preference.spiceTolerance
        self.richness = preference.richness
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

// MARK: - Food Preference

struct FoodPreference: Codable, Equatable {
    var adventurousness: Int // 1 = Classic, 5 = Adventurous
    var spiceTolerance: Int  // 1 = Non-spicy, 5 = The spicier the better
    var richness: Int        // 1 = Light, 5 = Rich

    static let `default` = FoodPreference(adventurousness: 3, spiceTolerance: 3, richness: 3)

    var adventurousnessLabel: String {
        switch adventurousness {
        case 1: return "Classic comfort"
        case 2: return "Mostly familiar"
        case 3: return "Balanced"
        case 4: return "Open to new"
        case 5: return "Adventurous"
        default: return "Balanced"
        }
    }

    var spiceLabel: String {
        switch spiceTolerance {
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

    static let `default` = WinePreference(
        countries: [],
        whiteVarietals: [],
        redVarietals: [],
        flavors: []
    )

    var isEmpty: Bool {
        countries.isEmpty && whiteVarietals.isEmpty && redVarietals.isEmpty && flavors.isEmpty
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

    var sessionStatus: SessionStatus {
        SessionStatus(rawValue: status) ?? .created
    }
}
