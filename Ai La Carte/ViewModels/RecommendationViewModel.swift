//
//  RecommendationViewModel.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation

@MainActor
@Observable
final class RecommendationViewModel: BaseViewModel {
    let sessionId: String

    var foodRecommendations: [RecommendationItemResponse] = []
    var wineRecommendations: [RecommendationItemResponse] = []
    var profileSummary: String?

    var expandedItemId: String?
    var selectedTab: RecommendationTab = .food

    // Cart state
    var cartItems: [RecommendationItemResponse] = []

    private let recommendationService: RecommendationAPIServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol

    init(
        sessionId: String,
        recommendationService: RecommendationAPIServiceProtocol,
        analyticsService: AnalyticsServiceProtocol
    ) {
        self.sessionId = sessionId
        self.recommendationService = recommendationService
        self.analyticsService = analyticsService
        super.init()
    }

    func loadRecommendations() async {
        isLoading = true

        do {
            let response = try await recommendationService.getRecommendations(sessionId: sessionId)
            foodRecommendations = response.food
            wineRecommendations = response.wine
            profileSummary = response.explanations?.profileSummary

            analyticsService.track(event: .recommendationViewed, sessionId: sessionId, meta: [
                "food_count": "\(response.food.count)",
                "wine_count": "\(response.wine.count)"
            ])
        } catch {
            self.error = handleNetworkError(error)
        }

        isLoading = false
    }

    func toggleExpanded(_ itemId: String) {
        if expandedItemId == itemId {
            expandedItemId = nil
        } else {
            expandedItemId = itemId
            analyticsService.track(event: .itemExpanded, sessionId: sessionId, meta: ["item_id": itemId])
        }
    }

    func trackItemTap(_ itemId: String) {
        analyticsService.track(event: .itemTapped, sessionId: sessionId, meta: ["item_id": itemId])
    }

    var currentItems: [RecommendationItemResponse] {
        switch selectedTab {
        case .food:
            return foodRecommendations
        case .wine:
            return wineRecommendations
        case .cart:
            return cartItems
        }
    }

    var hasWineRecommendations: Bool {
        !wineRecommendations.isEmpty
    }

    // MARK: - Cart Management

    var cartItemCount: Int {
        cartItems.count
    }

    func isInCart(_ item: RecommendationItemResponse) -> Bool {
        cartItems.contains { $0.id == item.id }
    }

    func addToCart(_ item: RecommendationItemResponse) {
        guard !isInCart(item) else { return }
        cartItems.append(item)
        analyticsService.track(event: .itemAddedToCart, sessionId: sessionId, meta: [
            "item_id": item.id,
            "item_type": item.type,
            "item_title": item.title
        ])
    }

    func removeFromCart(_ item: RecommendationItemResponse) {
        cartItems.removeAll { $0.id == item.id }
        analyticsService.track(event: .itemRemovedFromCart, sessionId: sessionId, meta: [
            "item_id": item.id,
            "item_type": item.type
        ])
    }

    func toggleCart(_ item: RecommendationItemResponse) {
        if isInCart(item) {
            removeFromCart(item)
        } else {
            addToCart(item)
        }
    }

    func clearCart() {
        cartItems.removeAll()
    }
}

enum RecommendationTab: String, CaseIterable {
    case food = "Food"
    case wine = "Wine"
    case cart = "Cart"

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .wine: return "wineglass"
        case .cart: return "cart"
        }
    }
}
