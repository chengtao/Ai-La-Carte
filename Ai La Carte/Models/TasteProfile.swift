//
//  TasteProfile.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation
import SwiftData

@Model
final class TasteProfile {
    var spicePreference: Double    // 0-1 (0 = no spice, 1 = loves spice)
    var adventurousness: Double    // 0-1 (0 = classic, 1 = adventurous)
    var richnessPreference: Double? // 0-1 (optional, for future)
    var sweetnessPreference: Double? // 0-1 (optional, for future)
    var lastUpdatedAt: Date

    init(
        spicePreference: Double = 0.5,
        adventurousness: Double = 0.5,
        richnessPreference: Double? = nil,
        sweetnessPreference: Double? = nil,
        lastUpdatedAt: Date = Date()
    ) {
        self.spicePreference = spicePreference
        self.adventurousness = adventurousness
        self.richnessPreference = richnessPreference
        self.sweetnessPreference = sweetnessPreference
        self.lastUpdatedAt = lastUpdatedAt
    }

    func updateFromSession(_ preference: FoodPreference) {
        // Session preference uses 1-5 scale, we use 0-1
        let newSpice = Double(preference.spiceTolerance - 1) / 4.0
        let newAdventurous = Double(preference.adventurousness - 1) / 4.0
        let newRichness = Double(preference.richness - 1) / 4.0

        // Weighted average: give more weight to newer data
        let weight = 0.7
        self.spicePreference = (spicePreference * (1 - weight)) + (newSpice * weight)
        self.adventurousness = (adventurousness * (1 - weight)) + (newAdventurous * weight)
        self.richnessPreference = ((richnessPreference ?? 0.5) * (1 - weight)) + (newRichness * weight)
        self.lastUpdatedAt = Date()
    }

    func updateFromFeedback(itemId: String, rating: FeedbackRating, itemAttributes: ItemAttributes?) {
        guard let attributes = itemAttributes else { return }

        let adjustment: Double
        switch rating {
        case .loved:
            adjustment = 0.1
        case .disliked:
            adjustment = -0.1
        case .notOrdered:
            return // No adjustment for items not ordered
        }

        // Adjust preferences based on item attributes
        if let spiceLevel = attributes.spiceLevel {
            spicePreference = max(0, min(1, spicePreference + (spiceLevel > 0.5 ? adjustment : -adjustment)))
        }

        if let isAdventurous = attributes.isAdventurous, isAdventurous {
            adventurousness = max(0, min(1, adventurousness + adjustment))
        }

        lastUpdatedAt = Date()
    }
}

// MARK: - Feedback Types

enum FeedbackRating: String, Codable {
    case loved
    case disliked
    case notOrdered = "not_ordered"

    var displayText: String {
        switch self {
        case .loved: return "Loved it!"
        case .disliked: return "Not for me"
        case .notOrdered: return "Didn't order"
        }
    }

    var emoji: String {
        switch self {
        case .loved: return "thumbsup"
        case .disliked: return "thumbsdown"
        case .notOrdered: return "nosign"
        }
    }
}

struct ItemAttributes: Codable {
    let spiceLevel: Double?  // 0-1
    let isAdventurous: Bool?
    let isRich: Bool?
}

// MARK: - Feedback Request/Response

struct FeedbackRequest: Codable {
    let itemId: String
    let action: String

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case action
    }
}

struct FeedbackResponse: Codable {
    let ok: Bool
}

// MARK: - Event Tracking

struct AnalyticsEvent: Codable {
    let sessionId: String?
    let userId: String?
    let deviceId: String
    let event: String
    let meta: [String: String]?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case userId = "user_id"
        case deviceId = "device_id"
        case event
        case meta
    }
}

enum AnalyticsEventType: String {
    case appOpen = "app_open"
    case restaurantSuggestedShown = "restaurant_suggested_shown"
    case restaurantSelected = "restaurant_selected"
    case photoCaptured = "photo_captured"
    case photoAccepted = "photo_accepted"
    case recommendClicked = "recommend_clicked"
    case sliderSet = "slider_set"
    case preferenceAdjusted = "preference_adjusted"
    case recommendationViewed = "recommendation_viewed"
    case itemExpanded = "item_expanded"
    case itemTapped = "item_tapped"
    case surveyCompleted = "survey_completed"
    case itemAddedToCart = "item_added_to_cart"
    case itemRemovedFromCart = "item_removed_from_cart"
}
