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
        static let spiceMatch: Double = 0.10

        // Wine-specific
        static let wineBoldnessMatch: Double = 0.08
        static let winePairingBoost: Double = 0.12  // Pairing more important for wine
    }

    // MARK: - Food Tag Codes

    private enum FoodTagCode {
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

    // MARK: - Wine Tag Codes

    private enum WineTagCode {
        static let highCpValue = "HIGH_CP_VALUE"
        static let risingStar = "RISING_STAR"
        static let fineAndRare = "FINE_AND_RARE"
        static let awardWinning = "AWARD_WINNING"
        static let famous = "FAMOUS"
        static let highScore = "HIGH_SCORE"
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
        let reasonCodes = Set(item.tags.map { $0.code })

        // Food tag boosts
        if reasonCodes.contains(FoodTagCode.communityFavorite) {
            score += Weights.communityFavorite
        }
        if reasonCodes.contains(FoodTagCode.chefSignature) {
            score += Weights.chefSignature
        }
        if reasonCodes.contains(FoodTagCode.greatValue) {
            score += Weights.greatValue
        }
        if reasonCodes.contains(FoodTagCode.pairsWithDish) {
            score += Weights.pairingBoost
        }
        if reasonCodes.contains(FoodTagCode.houseSpecialty) {
            score += Weights.houseSpecialty
        }
        if reasonCodes.contains(FoodTagCode.similarToPast) {
            score += 0.08
        }

        // Spice preference matching
        score += calculateSpiceBoost(
            hasSpiceMatch: reasonCodes.contains(FoodTagCode.matchesSpice),
            preference: preferences.spicePreference
        )

        return clamp(score)
    }

    private func calculateWineScore(
        item: WineItemResponse,
        preferences: FoodPreference
    ) -> Double {
        var score = Weights.baseScore
        let tagCodes = Set(item.tags.map { $0.code })

        // Wine tag boosts (using new wine-specific tags)
        if tagCodes.contains(WineTagCode.highCpValue) {
            score += Weights.greatValue
        }
        if tagCodes.contains(WineTagCode.awardWinning) {
            score += Weights.chefSignature
        }
        if tagCodes.contains(WineTagCode.famous) {
            score += Weights.communityFavorite
        }
        if tagCodes.contains(WineTagCode.fineAndRare) {
            score += Weights.houseSpecialty
        }
        if tagCodes.contains(WineTagCode.risingStar) {
            score += 0.08
        }
        if tagCodes.contains(WineTagCode.highScore) {
            score += 0.10
        }

        return clamp(score)
    }

    // MARK: - Preference Matching

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
        richness: Int
    ) -> Double {
        // Users preferring rich food tend to prefer bolder wines
        // Users preferring light food tend to prefer lighter wines

        if hasRichBold {
            switch richness {
            case 5: return Weights.wineBoldnessMatch
            case 4: return Weights.wineBoldnessMatch * 0.6
            case 3: return 0.0
            case 2: return -0.02
            case 1: return -0.04
            default: return 0.0
            }
        }

        if hasLightFresh {
            switch richness {
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
