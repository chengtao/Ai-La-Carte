//
//  SurveyViewModel.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation

@MainActor
@Observable
final class SurveyViewModel: BaseViewModel {
    let sessionId: String
    let items: [ScoredFoodItem]

    var ratings: [String: FeedbackRating] = [:]
    var currentItemIndex = 0
    var isComplete = false

    private let recommendationService: RecommendationAPIServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol

    init(
        sessionId: String,
        items: [ScoredFoodItem],
        recommendationService: RecommendationAPIServiceProtocol,
        analyticsService: AnalyticsServiceProtocol
    ) {
        self.sessionId = sessionId
        self.items = Array(items.prefix(3)) // Only rate top 3
        self.recommendationService = recommendationService
        self.analyticsService = analyticsService
        super.init()
    }

    var currentItem: ScoredFoodItem? {
        guard currentItemIndex < items.count else { return nil }
        return items[currentItemIndex]
    }

    var progress: Double {
        guard !items.isEmpty else { return 1.0 }
        return Double(currentItemIndex) / Double(items.count)
    }

    func submitRating(_ rating: FeedbackRating) async {
        guard let item = currentItem else { return }

        ratings[item.id] = rating

        // Submit to backend
        do {
            try await recommendationService.submitFeedback(
                sessionId: sessionId,
                itemId: item.id,
                rating: rating
            )
        } catch {
            AppLogger.shared.error("Failed to submit feedback: \(error)", category: AppLogger.Category.recommendation)
        }

        // Move to next item
        if currentItemIndex < items.count - 1 {
            currentItemIndex += 1
        } else {
            isComplete = true
            analyticsService.track(event: .surveyCompleted, sessionId: sessionId, meta: [
                "items_rated": "\(ratings.count)"
            ])
        }
    }

    func skip() {
        if currentItemIndex < items.count - 1 {
            currentItemIndex += 1
        } else {
            isComplete = true
        }
    }
}
