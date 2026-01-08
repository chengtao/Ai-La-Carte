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
    let mode: CalculationMode
    let preferences: UserPreferences

    var status: SessionStatus = .created
    var progress: Double = 0
    var showRecommendations = false
    var pollingAttempts = 0

    // Menu IDs to pass to RecommendationView
    var foodMenuId: Int?
    var wineMenuId: Int?

    // Error state for no menus detected
    var noMenusDetected = false

    private let menuService: MenuAPIServiceProtocol
    private var pollingTask: Task<Void, Never>?

    init(
        sessionId: String,
        mode: CalculationMode,
        preferences: UserPreferences,
        menuService: MenuAPIServiceProtocol
    ) {
        self.sessionId = sessionId
        self.mode = mode
        self.preferences = preferences
        self.menuService = menuService

        // Extract menu IDs from mode if available
        if case .artificialDelay(let foodId, let wineId) = mode {
            self.foodMenuId = foodId
            self.wineMenuId = wineId
        }

        super.init()
    }

    func startPolling() {
        pollingTask?.cancel()

        switch mode {
        case .artificialDelay(let foodMenuId, let wineMenuId):
            startArtificialDelay(foodMenuId: foodMenuId, wineMenuId: wineMenuId)
        case .polling(let jobId):
            startRealPolling(jobId: jobId)
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Artificial Delay Flow (for nearby restaurants with existing menus)

    private func startArtificialDelay(foodMenuId: Int?, wineMenuId: Int?) {
        self.foodMenuId = foodMenuId
        self.wineMenuId = wineMenuId

        pollingTask = Task { @MainActor [weak self] in
            guard let self else { return }

            // Simulate 2.5 second "calculating" experience with 5 steps
            let steps: [(SessionStatus, Double, TimeInterval)] = [
                (.photosUploading, 0.15, 0.5),
                (.parsingMenu, 0.35, 0.5),
                (.collectingReviews, 0.55, 0.5),
                (.buildingProfile, 0.75, 0.5),
                (.ranking, 0.90, 0.5),
                (.done, 1.0, 0)
            ]

            for (stepStatus, stepProgress, delay) in steps {
                guard !Task.isCancelled else { return }

                withAnimation(.easeInOut(duration: 0.3)) {
                    self.status = stepStatus
                    self.progress = stepProgress
                }

                if stepStatus == .done {
                    self.showRecommendations = true
                    break
                }

                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    // MARK: - Real Polling Flow (for photo scan)

    private func startRealPolling(jobId: String) {
        pollingTask = Task { @MainActor [weak self] in
            guard let self else { return }

            while !Task.isCancelled && self.status != .done && self.status != .failed {
                await self.pollStatus(jobId: jobId)

                if self.status == .done {
                    // Only show recommendations if menus were detected
                    if !self.noMenusDetected {
                        self.showRecommendations = true
                    }
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

    private func pollStatus(jobId: String) async {
        do {
            let response = try await menuService.getMenusCreationStatus(jobId: jobId)

            let newStatus = response.sessionStatus
            let newProgress = response.progress ?? newStatus.progress

            AppLogger.shared.debug("Polling update: status=\(newStatus.rawValue), progress=\(newProgress)", category: AppLogger.Category.recommendation)

            withAnimation(.easeInOut(duration: 0.3)) {
                status = newStatus
                progress = newProgress
            }

            // Extract menu IDs when job completes
            if newStatus == .done {
                if response.hasMenus {
                    foodMenuId = response.foodMenuId
                    wineMenuId = response.wineMenuId
                    AppLogger.shared.info("Menu creation complete: food=\(response.foodMenuId.map(String.init) ?? "nil"), wine=\(response.wineMenuId.map(String.init) ?? "nil")", category: AppLogger.Category.recommendation)
                } else {
                    // No menus detected - trigger error alert
                    noMenusDetected = true
                    AppLogger.shared.warning("Menu creation complete but no menus detected", category: AppLogger.Category.recommendation)
                }
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
