//
//  CalculatingViewModel.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation
import SwiftUI

@Observable
final class CalculatingViewModel: BaseViewModel {
    let sessionId: String
    let jobId: String

    var status: SessionStatus = .created
    var progress: Double = 0
    var showRecommendations = false
    var pollingAttempts = 0

    private let recommendationService: RecommendationAPIServiceProtocol
    private var pollingTask: Task<Void, Never>?

    init(
        sessionId: String,
        jobId: String,
        recommendationService: RecommendationAPIServiceProtocol
    ) {
        self.sessionId = sessionId
        self.jobId = jobId
        self.recommendationService = recommendationService
        super.init()
    }

    @MainActor
    func startPolling() {
        pollingTask?.cancel()

        pollingTask = Task {
            while !Task.isCancelled && status != .done && status != .failed {
                await pollStatus()

                if status == .done {
                    showRecommendations = true
                    break
                }

                if status == .failed {
                    break
                }

                pollingAttempts += 1
                if pollingAttempts >= AppConstants.Recommendation.maxPollingAttempts {
                    status = .failed
                    error = AppError.network(.serverError("Request timed out"))
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

    @MainActor
    private func pollStatus() async {
        do {
            let response = try await recommendationService.getRecommendationStatus(
                sessionId: sessionId,
                jobId: jobId
            )

            withAnimation(.easeInOut(duration: 0.3)) {
                status = response.sessionStatus
                progress = response.progress ?? status.progress
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
