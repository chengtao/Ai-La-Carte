//
//  SessionPreferenceViewModel.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation

@MainActor
@Observable
final class SessionPreferenceViewModel: BaseViewModel {
    let sessionId: String

    // Slider values (1-5)
    var adventurousClassic: Double = 3
    var spiceTolerance: Double = 3

    // Navigation
    var jobId: String?
    var showCalculating = false

    private let sessionService: SessionAPIServiceProtocol
    private let recommendationService: RecommendationAPIServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol

    init(
        sessionId: String,
        sessionService: SessionAPIServiceProtocol,
        recommendationService: RecommendationAPIServiceProtocol,
        analyticsService: AnalyticsServiceProtocol
    ) {
        self.sessionId = sessionId
        self.sessionService = sessionService
        self.recommendationService = recommendationService
        self.analyticsService = analyticsService
        super.init()
    }

    var preference: SessionPreference {
        SessionPreference(
            adventurousClassic: Int(adventurousClassic),
            spiceTolerance: Int(spiceTolerance)
        )
    }

    func submitAndGenerate() async {
        isLoading = true

        do {
            // Submit preferences
            try await sessionService.submitPreferences(sessionId: sessionId, preferences: preference)

            analyticsService.track(
                event: .sliderSet,
                sessionId: sessionId,
                meta: [
                    "adventurous": "\(Int(adventurousClassic))",
                    "spice": "\(Int(spiceTolerance))"
                ]
            )

            // Start recommendation generation
            let jobResponse = try await recommendationService.generateRecommendations(
                sessionId: sessionId,
                includeReviews: true
            )

            jobId = jobResponse.jobId
            showCalculating = true
        } catch {
            self.error = handleNetworkError(error)
        }

        isLoading = false
    }

    var adventurousnessLabel: String {
        preference.adventurousnessLabel
    }

    var spiceLabel: String {
        preference.spiceLabel
    }
}
