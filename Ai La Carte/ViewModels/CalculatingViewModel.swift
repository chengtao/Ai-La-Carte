//
//  CalculatingViewModel.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class CalculatingViewModel: BaseViewModel {
    let sessionId: String
    let jobId: String
    let preferences: UserPreferences

    var status: SessionStatus = .created
    var progress: Double = 0
    var showRecommendations = false
    var pollingAttempts = 0

    private let recommendationService: RecommendationAPIServiceProtocol
    private var pollingTask: Task<Void, Never>?

    init(
        sessionId: String,
        jobId: String,
        preferences: UserPreferences,
        recommendationService: RecommendationAPIServiceProtocol
    ) {
        self.sessionId = sessionId
        self.jobId = jobId
        self.preferences = preferences
        self.recommendationService = recommendationService
        super.init()
    }

    func startPolling() {
        pollingTask?.cancel()

        pollingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled && self.status != .done && self.status != .failed {
                await self.pollStatus()

                if self.status == .done {
                    self.showRecommendations = true
                    break
                }

                if self.status == .failed {
                    break
                }

                self.pollingAttempts += 1
                if self.pollingAttempts >= AppConstants.Recommendation.maxPollingAttempts {
                    self.status = .failed
                    self.error = AppError.network(.serverError("Request timed out"))
                    break
                }

                try? await Task.sleep(nanoseconds: UInt64(AppConstants.Recommendation.pollingInterval * 1_000_000_000))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func pollStatus() async {
        do {
            let response = try await recommendationService.getRecommendationStatus(
                sessionId: sessionId,
                jobId: jobId
            )

            let newStatus = response.sessionStatus
            let newProgress = response.progress ?? newStatus.progress

            AppLogger.shared.debug("Polling update: status=\(newStatus.rawValue), progress=\(newProgress)", category: AppLogger.Category.recommendation)

            withAnimation(.easeInOut(duration: 0.3)) {
                status = newStatus
                progress = newProgress
            }
        } catch {
            AppLogger.shared.error("Polling error: \(error)", category: AppLogger.Category.recommendation)
        }
    }

    var currentStepText: String {
        status.displayText
    }

    var progressPercentage: Int {
        Int(progress * 100)
    }
}
