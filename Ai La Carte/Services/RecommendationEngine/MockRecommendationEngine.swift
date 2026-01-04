//
//  MockRecommendationEngine.swift
//  AILaCarte
//
//  Created by Claude on 1/3/26.
//

import Foundation

/// Mock implementation of RecommendationEngine for testing and previews.
/// Returns deterministic scores based on item index.
final class MockRecommendationEngine: RecommendationEngineProtocol, Sendable {

    func scoreFood(
        items: [FoodItemResponse],
        preferences: FoodPreference
    ) -> [ScoredFoodItem] {
        items.enumerated().map { index, item in
            // Generate decreasing confidence based on index
            let confidence = max(0.95 - (Double(index) * 0.05), 0.60)
            return ScoredFoodItem(item: item, confidence: confidence)
        }
    }

    func scoreWine(
        items: [WineItemResponse],
        preferences: FoodPreference
    ) -> [ScoredWineItem] {
        items.enumerated().map { index, item in
            // Generate decreasing confidence based on index
            let confidence = max(0.92 - (Double(index) * 0.04), 0.55)
            return ScoredWineItem(item: item, confidence: confidence)
        }
    }
}
