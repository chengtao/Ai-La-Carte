//
//  MockRecommendationEngine.swift
//  AILaCarte
//
//  Created by Claude on 1/3/26.
//

import Foundation

/// Mock implementation of RecommendationEngine for testing and previews.
/// Calculates scores based on preferences to test UI auto-refresh.
final class MockRecommendationEngine: RecommendationEngineProtocol, Sendable {

    func scoreFood(
        items: [FoodItemResponse],
        preferences: FoodPreference
    ) -> [ScoredFoodItem] {
        let scored = items.map { item in
            let confidence = calculateFoodScore(item: item, preferences: preferences)
            return ScoredFoodItem(item: item, confidence: confidence)
        }
        // Sort by confidence descending
        return scored.sorted { $0.confidence > $1.confidence }
    }

    func scoreWine(
        items: [WineItemResponse],
        preferences: FoodPreference
    ) -> [ScoredWineItem] {
        let scored = items.map { item in
            let confidence = calculateWineScore(item: item, preferences: preferences)
            return ScoredWineItem(item: item, confidence: confidence)
        }
        // Sort by confidence descending
        return scored.sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Private Scoring Methods

    private func calculateFoodScore(item: FoodItemResponse, preferences: FoodPreference) -> Double {
        var score = 0.5 // Base score

        let reasonCodes = Set(item.reasons.map { $0.code })

        // Adventurousness scoring (1 = classic, 5 = adventurous)
        if reasonCodes.contains("ADVENTUROUS_PICK") {
            // High adventurousness preference boosts adventurous picks
            score += Double(preferences.adventurousness - 3) * 0.08
        }
        if reasonCodes.contains("CROWD_PLEASER") {
            // Low adventurousness preference boosts crowd pleasers
            score += Double(3 - preferences.adventurousness) * 0.06
        }

        // Spice tolerance scoring (1 = mild, 5 = spicy)
        if reasonCodes.contains("MATCHES_SPICE") {
            // Higher spice tolerance boosts spicy items
            score += Double(preferences.spiceTolerance - 2) * 0.07
        }

        // Universal boosts
        if reasonCodes.contains("COMMUNITY_FAVORITE") {
            score += 0.12
        }
        if reasonCodes.contains("CHEF_SIGNATURE") {
            score += 0.10
        }
        if reasonCodes.contains("GREAT_VALUE") {
            score += 0.05
        }
        if reasonCodes.contains("HOUSE_SPECIALTY") {
            score += 0.08
        }

        // Add some variation based on item ID hash for variety
        let idHash = abs(item.id.hashValue % 100)
        score += Double(idHash) * 0.001

        return min(max(score, 0.3), 0.98) // Clamp between 0.3 and 0.98
    }

    private func calculateWineScore(item: WineItemResponse, preferences: FoodPreference) -> Double {
        var score = 0.5 // Base score

        let reasonCodes = Set(item.reasons.map { $0.code })

        // Adventurousness affects wine boldness preference
        if reasonCodes.contains("RICH_BOLD") {
            // High adventurousness prefers bold wines
            score += Double(preferences.adventurousness - 3) * 0.09
        }
        if reasonCodes.contains("LIGHT_FRESH") {
            // Low adventurousness prefers light wines
            score += Double(3 - preferences.adventurousness) * 0.07
        }

        // Universal boosts
        if reasonCodes.contains("PAIRS_WITH_DISH") {
            score += 0.15
        }
        if reasonCodes.contains("COMMUNITY_FAVORITE") {
            score += 0.10
        }
        if reasonCodes.contains("CROWD_PLEASER") {
            score += 0.08
        }
        if reasonCodes.contains("CHEF_SIGNATURE") {
            score += 0.12
        }
        if reasonCodes.contains("GREAT_VALUE") {
            score += 0.05
        }

        // Add some variation based on item ID hash for variety
        let idHash = abs(item.id.hashValue % 100)
        score += Double(idHash) * 0.001

        return min(max(score, 0.3), 0.98) // Clamp between 0.3 and 0.98
    }
}
