//
//  RecommendationItem.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation
import SwiftData

@Model
final class RecommendationItem {
    @Attribute(.unique) var id: String
    var typeRaw: String
    var title: String
    var itemDescription: String
    var reasonsData: Data? // Encoded [ReasonTag]
    var confidence: Double // 0-1
    var pairingIds: [String]
    var sessionId: String

    // Food-specific fields
    var photoUrl: String?
    var price: String?

    // Wine-specific fields
    var grapeVarietal: String?
    var region: String?
    var country: String?
    var priceGlass: String?
    var priceBottle: String?

    var session: Session?

    var type: RecommendationType {
        get { RecommendationType(rawValue: typeRaw) ?? .food }
        set { typeRaw = newValue.rawValue }
    }

    var reasons: [ReasonTag] {
        get {
            guard let data = reasonsData else { return [] }
            return (try? JSONDecoder().decode([ReasonTag].self, from: data)) ?? []
        }
        set {
            reasonsData = try? JSONEncoder().encode(newValue)
        }
    }

    init(
        id: String = UUID().uuidString,
        type: RecommendationType,
        title: String,
        description: String,
        reasons: [ReasonTag] = [],
        confidence: Double = 0.0,
        pairingIds: [String] = [],
        sessionId: String,
        photoUrl: String? = nil,
        price: String? = nil,
        grapeVarietal: String? = nil,
        region: String? = nil,
        country: String? = nil,
        priceGlass: String? = nil,
        priceBottle: String? = nil
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.title = title
        self.itemDescription = description
        self.reasonsData = try? JSONEncoder().encode(reasons)
        self.confidence = confidence
        self.pairingIds = pairingIds
        self.sessionId = sessionId
        self.photoUrl = photoUrl
        self.price = price
        self.grapeVarietal = grapeVarietal
        self.region = region
        self.country = country
        self.priceGlass = priceGlass
        self.priceBottle = priceBottle
    }
}

// MARK: - Recommendation Type

enum RecommendationType: String, Codable {
    case food
    case wine
}

// MARK: - Reason Tag

struct ReasonTag: Codable, Identifiable, Hashable {
    let code: String
    let label: String

    var id: String { code }

    // Common reason codes
    static let communityFavorite = ReasonTag(code: "COMMUNITY_FAVORITE", label: "Community Favorite")
    static let chefSignature = ReasonTag(code: "CHEF_SIGNATURE", label: "Chef's Signature")
    static let matchesSpice = ReasonTag(code: "MATCHES_SPICE", label: "Matches Your Spice Level")
    static let adventurousPick = ReasonTag(code: "ADVENTUROUS_PICK", label: "Adventurous Pick")
    static let crowdPleaser = ReasonTag(code: "CROWD_PLEASER", label: "Crowd Pleaser")
    static let greatValue = ReasonTag(code: "GREAT_VALUE", label: "Great Value")
    static let pairsWithDish = ReasonTag(code: "PAIRS_WITH_DISH", label: "Perfect Pairing")
    static let similarToPast = ReasonTag(code: "SIMILAR_TO_PAST", label: "Similar to Your Favorites")
    static let lightAndFresh = ReasonTag(code: "LIGHT_FRESH", label: "Light & Fresh")
    static let richAndBold = ReasonTag(code: "RICH_BOLD", label: "Rich & Bold")
    static let vegetarianFriendly = ReasonTag(code: "VEGETARIAN", label: "Vegetarian Friendly")
    static let houseSpecialty = ReasonTag(code: "HOUSE_SPECIALTY", label: "House Specialty")
}

// MARK: - Recommendation Response DTOs

struct RecommendationResponse: Codable {
    let food: [RecommendationItemResponse]
    let wine: [RecommendationItemResponse]
    let explanations: ExplanationsResponse?
}

struct RecommendationItemResponse: Codable, Identifiable {
    let id: String
    let type: String
    let title: String
    let description: String
    let reasons: [ReasonTagResponse]
    let confidence: Double
    let pairingIds: [String]?

    // Food-specific fields
    let photoUrl: String?
    let price: String?

    // Wine-specific fields
    let grapeVarietal: String?
    let region: String?
    let country: String?
    let priceGlass: String?
    let priceBottle: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case description
        case reasons
        case confidence
        case pairingIds = "pairing_ids"
        case photoUrl = "photo_url"
        case price
        case grapeVarietal = "grape_varietal"
        case region
        case country
        case priceGlass = "price_glass"
        case priceBottle = "price_bottle"
    }

    var reasonTags: [ReasonTag] {
        reasons.map { ReasonTag(code: $0.code, label: $0.label) }
    }

    var recommendationType: RecommendationType {
        RecommendationType(rawValue: type) ?? .food
    }

    /// Formatted wine origin (e.g., "Napa Valley, California, USA")
    var wineOrigin: String? {
        let parts = [region, country].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// Check if wine has pricing
    var hasWinePricing: Bool {
        priceGlass != nil || priceBottle != nil
    }
}

struct ReasonTagResponse: Codable {
    let code: String
    let label: String
}

struct ExplanationsResponse: Codable {
    let profileSummary: String?

    enum CodingKeys: String, CodingKey {
        case profileSummary = "profile_summary"
    }
}
