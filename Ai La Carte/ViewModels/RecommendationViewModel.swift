//
//  RecommendationViewModel.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation

@Observable
final class RecommendationViewModel: BaseViewModel {
    let sessionId: String

    var foodRecommendations: [RecommendationItemResponse] = []
    var wineRecommendations: [RecommendationItemResponse] = []
    var profileSummary: String?

    var expandedItemId: String?
    var selectedTab: RecommendationTab = .food

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

    @MainActor
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
        }
    }

    var hasWineRecommendations: Bool {
        !wineRecommendations.isEmpty
    }
}

enum RecommendationTab: String, CaseIterable {
    case food = "Food"
    case wine = "Wine"

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .wine: return "wineglass"
        }
    }
}
