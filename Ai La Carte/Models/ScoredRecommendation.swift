//
//  ScoredRecommendation.swift
//  AILaCarte
//
//  Created by Claude on 1/3/26.
//

import Foundation

// MARK: - Scored Food Item

/// Wrapper that adds locally-calculated confidence score to a food item
struct ScoredFoodItem: Identifiable, Hashable {
    let item: FoodItemResponse
    let confidence: Double  // 0.0 - 1.0, locally calculated by RecommendationEngine

    var id: String { item.id }

    // Convenience accessors
    var title: String { item.title }
    var description: String { item.description }
    var reasonTags: [ReasonTag] { item.reasonTags }
    var pairingIds: [String]? { item.pairingIds }
    var photoUrl: String? { item.photoUrl }
    var price: String? { item.price }
    var foodCategory: FoodCategory { item.foodCategory }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ScoredFoodItem, rhs: ScoredFoodItem) -> Bool {
        lhs.id == rhs.id && lhs.confidence == rhs.confidence
    }
}

// MARK: - Scored Wine Item

/// Wrapper that adds locally-calculated confidence score to a wine item
struct ScoredWineItem: Identifiable, Hashable {
    let item: WineItemResponse
    let confidence: Double  // 0.0 - 1.0, locally calculated by RecommendationEngine

    var id: String { item.id }

    // Convenience accessors
    var title: String { item.title }
    var description: String { item.description }
    var reasonTags: [ReasonTag] { item.reasonTags }
    var pairingIds: [String]? { item.pairingIds }
    var grapeVarietal: String? { item.grapeVarietal }
    var region: String? { item.region }
    var country: String? { item.country }
    var priceGlass: String? { item.priceGlass }
    var priceBottle: String? { item.priceBottle }
    var wineCategory: WineCategory { item.wineCategory }
    var wineOrigin: String? { item.wineOrigin }
    var hasWinePricing: Bool { item.hasWinePricing }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ScoredWineItem, rhs: ScoredWineItem) -> Bool {
        lhs.id == rhs.id && lhs.confidence == rhs.confidence
    }
}

// MARK: - Scored Recommendation Protocol

/// Protocol for common scoring behavior across food and wine items
protocol ScoredRecommendation {
    var confidence: Double { get }
    var reasonTags: [ReasonTag] { get }
}

extension ScoredFoodItem: ScoredRecommendation {}
extension ScoredWineItem: ScoredRecommendation {}
