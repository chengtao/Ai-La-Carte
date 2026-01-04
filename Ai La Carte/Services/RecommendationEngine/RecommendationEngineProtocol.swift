//
//  RecommendationEngineProtocol.swift
//  AILaCarte
//
//  Created by Claude on 1/3/26.
//

import Foundation

/// Protocol for local recommendation scoring engine.
/// Calculates confidence scores for food and wine items based on user preferences.
protocol RecommendationEngineProtocol: Sendable {
    /// Score food items based on user preferences
    /// - Parameters:
    ///   - items: Raw food items from the server
    ///   - preferences: User's current food preferences
    /// - Returns: Scored food items sorted by confidence (highest first)
    func scoreFood(
        items: [FoodItemResponse],
        preferences: FoodPreference
    ) -> [ScoredFoodItem]

    /// Score wine items based on user preferences
    /// - Parameters:
    ///   - items: Raw wine items from the server
    ///   - preferences: User's current food preferences
    /// - Returns: Scored wine items sorted by confidence (highest first)
    func scoreWine(
        items: [WineItemResponse],
        preferences: FoodPreference
    ) -> [ScoredWineItem]
}
