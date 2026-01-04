//
//  RecommendationEngine.swift
//  AILaCarte
//
//  Created by Claude on 1/3/26.
//

import Foundation

/// Local recommendation scoring engine that calculates confidence scores
/// based on user preferences, reason tags, and item-specific signals.
final class RecommendationEngine: RecommendationEngineProtocol, Sendable {

    // MARK: - Scoring Weights

    private enum Weights {
        static let baseScore: Double = 0.50

        // Reason tag boosts
        static let communityFavorite: Double = 0.15
        static let chefSignature: Double = 0.12
        static let greatValue: Double = 0.05
        static let pairingBoost: Double = 0.08
        static let houseSpecialty: Double = 0.10

        // Preference matching
        static let adventurousnessMatch: Double = 0.10
        static let spiceMatch: Double = 0.10

        // Wine-specific
        static let wineBoldnessMatch: Double = 0.08
        static let winePairingBoost: Double = 0.12  // Pairing more important for wine
    }

    // MARK: - Reason Codes

    private enum ReasonCode {
        static let communityFavorite = "COMMUNITY_FAVORITE"
        static let chefSignature = "CHEF_SIGNATURE"
        static let matchesSpice = "MATCHES_SPICE"
        static let adventurousPick = "ADVENTUROUS_PICK"
        static let crowdPleaser = "CROWD_PLEASER"
        static let greatValue = "GREAT_VALUE"
        static let pairsWithDish = "PAIRS_WITH_DISH"
        static let similarToPast = "SIMILAR_TO_PAST"
        static let lightAndFresh = "LIGHT_FRESH"
        static let richAndBold = "RICH_BOLD"
        static let vegetarian = "VEGETARIAN"
        static let houseSpecialty = "HOUSE_SPECIALTY"
    }

    // MARK: - Public Methods

    func scoreFood(
        items: [FoodItemResponse],
        preferences: FoodPreference
    ) -> [ScoredFoodItem] {
        items.map { item in
            let confidence = calculateFoodScore(item: item, preferences: preferences)
            return ScoredFoodItem(item: item, confidence: confidence)
        }
        .sorted { $0.confidence > $1.confidence }
    }

    func scoreWine(
        items: [WineItemResponse],
        preferences: FoodPreference
    ) -> [ScoredWineItem] {
        items.map { item in
            let confidence = calculateWineScore(item: item, preferences: preferences)
            return ScoredWineItem(item: item, confidence: confidence)
        }
        .sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Private Scoring Methods

    private func calculateFoodScore(
        item: FoodItemResponse,
        preferences: FoodPreference
    ) -> Double {
        var score = Weights.baseScore
        let reasonCodes = Set(item.reasons.map { $0.code })

        // Reason tag boosts
        if reasonCodes.contains(ReasonCode.communityFavorite) {
            score += Weights.communityFavorite
        }
        if reasonCodes.contains(ReasonCode.chefSignature) {
            score += Weights.chefSignature
        }
        if reasonCodes.contains(ReasonCode.greatValue) {
            score += Weights.greatValue
        }
        if reasonCodes.contains(ReasonCode.pairsWithDish) {
            score += Weights.pairingBoost
        }
        if reasonCodes.contains(ReasonCode.houseSpecialty) {
            score += Weights.houseSpecialty
        }
        if reasonCodes.contains(ReasonCode.similarToPast) {
            score += 0.08
        }

        // Adventurousness matching
        score += calculateAdventurousnessBoost(
            hasAdventurousPick: reasonCodes.contains(ReasonCode.adventurousPick),
            hasCrowdPleaser: reasonCodes.contains(ReasonCode.crowdPleaser),
            preference: preferences.adventurousness
        )

        // Spice matching
        score += calculateSpiceBoost(
            hasSpiceMatch: reasonCodes.contains(ReasonCode.matchesSpice),
            preference: preferences.spiceTolerance
        )

        return clamp(score)
    }

    private func calculateWineScore(
        item: WineItemResponse,
        preferences: FoodPreference
    ) -> Double {
        var score = Weights.baseScore
        let reasonCodes = Set(item.reasons.map { $0.code })

        // Reason tag boosts
        if reasonCodes.contains(ReasonCode.communityFavorite) {
            score += Weights.communityFavorite
        }
        if reasonCodes.contains(ReasonCode.chefSignature) {
            score += Weights.chefSignature
        }
        if reasonCodes.contains(ReasonCode.greatValue) {
            score += Weights.greatValue
        }
        if reasonCodes.contains(ReasonCode.houseSpecialty) {
            score += Weights.houseSpecialty
        }
        if reasonCodes.contains(ReasonCode.similarToPast) {
            score += 0.08
        }

        // Pairing is more important for wine
        if reasonCodes.contains(ReasonCode.pairsWithDish) {
            score += Weights.winePairingBoost
        }

        // Bold vs light preference based on adventurousness
        score += calculateWineBoldnessBoost(
            hasRichBold: reasonCodes.contains(ReasonCode.richAndBold),
            hasLightFresh: reasonCodes.contains(ReasonCode.lightAndFresh),
            adventurousness: preferences.adventurousness
        )

        return clamp(score)
    }

    // MARK: - Preference Matching

    private func calculateAdventurousnessBoost(
        hasAdventurousPick: Bool,
        hasCrowdPleaser: Bool,
        preference: Int
    ) -> Double {
        // High adventurousness (4-5) prefers ADVENTUROUS_PICK
        // Low adventurousness (1-2) prefers CROWD_PLEASER
        // Preference 3 is neutral

        if hasAdventurousPick {
            switch preference {
            case 5: return Weights.adventurousnessMatch
            case 4: return Weights.adventurousnessMatch * 0.7
            case 3: return Weights.adventurousnessMatch * 0.3
            case 2: return -0.02  // Slight penalty
            case 1: return -0.05  // Penalty for conservative users
            default: return 0.0
            }
        }

        if hasCrowdPleaser {
            switch preference {
            case 1: return Weights.adventurousnessMatch
            case 2: return Weights.adventurousnessMatch * 0.7
            case 3: return Weights.adventurousnessMatch * 0.3
            case 4: return -0.02  // Slight penalty
            case 5: return -0.05  // Penalty for adventurous users
            default: return 0.0
            }
        }

        return 0.0
    }

    private func calculateSpiceBoost(
        hasSpiceMatch: Bool,
        preference: Int
    ) -> Double {
        // If item is tagged as matching spice preference, boost based on preference level
        if hasSpiceMatch {
            // Higher spice preference = bigger boost for spicy items
            let factor = Double(preference) / 5.0
            return Weights.spiceMatch * factor
        }
        return 0.0
    }

    private func calculateWineBoldnessBoost(
        hasRichBold: Bool,
        hasLightFresh: Bool,
        adventurousness: Int
    ) -> Double {
        // Adventurous users tend to prefer bolder wines
        // Conservative users tend to prefer lighter wines

        if hasRichBold {
            switch adventurousness {
            case 5: return Weights.wineBoldnessMatch
            case 4: return Weights.wineBoldnessMatch * 0.6
            case 3: return 0.0
            case 2: return -0.02
            case 1: return -0.04
            default: return 0.0
            }
        }

        if hasLightFresh {
            switch adventurousness {
            case 1: return Weights.wineBoldnessMatch
            case 2: return Weights.wineBoldnessMatch * 0.6
            case 3: return 0.0
            case 4: return -0.02
            case 5: return -0.04
            default: return 0.0
            }
        }

        return 0.0
    }

    // MARK: - Utilities

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }
}
