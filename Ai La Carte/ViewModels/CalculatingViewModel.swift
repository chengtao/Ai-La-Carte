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
    let mode: CalculationMode
    let preferences: UserPreferences

    var status: SessionStatus = .created
    var progress: Double = 0
    var showRecommendations = false
    var pollingAttempts = 0

    // Session ID extracted from mode
    var sessionId: String {
        switch mode {
        case .uploadAndPoll(_, let id, _): return id
        case .createAndPoll(let id, _): return id
        case .polling: return "" // Not used in this mode
        }
    }

    // Menu IDs to pass to RecommendationView
    var foodMenuId: Int?
    var wineMenuId: Int?

    // Error state for no menus detected
    var noMenusDetected = false

    private let menuService: MenuAPIServiceProtocol
    private let sessionService: SessionAPIServiceProtocol
    private var pollingTask: Task<Void, Never>?

    init(
        mode: CalculationMode,
        preferences: UserPreferences,
        menuService: MenuAPIServiceProtocol,
        sessionService: SessionAPIServiceProtocol
    ) {
        self.mode = mode
        self.preferences = preferences
        self.menuService = menuService
        self.sessionService = sessionService

        super.init()
    }

    func startPolling() {
        pollingTask?.cancel()

        switch mode {
        case .uploadAndPoll(let photos, let sessionId, let location):
            startUploadAndPollFlow(photos: photos, sessionId: sessionId, location: location)
        case .createAndPoll(let sessionId, let location):
            startCreateAndPollFlow(sessionId: sessionId, location: location)
        case .polling(let jobId):
            startRealPolling(jobId: jobId)
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Upload and Poll Flow (for photo scan)

    private func startUploadAndPollFlow(photos: [CapturedPhoto], sessionId: String, location: LocationCoordinate?) {
        pollingTask = Task { @MainActor [weak self] in
            guard let self else { return }

            // Phase 1: Upload photos (0-20%)
            withAnimation(.easeInOut(duration: 0.3)) {
                self.status = .photosUploading
                self.progress = 0.0
            }

            let uploadSuccess = await self.uploadPhotos(photos, sessionId: sessionId)
            guard uploadSuccess else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.status = .failed
                    self.error = AppError.network(.serverError("Failed to upload photos"))
                }
                return
            }

            // Phase 2: Create menus API (20-30%)
            withAnimation(.easeInOut(duration: 0.3)) {
                self.status = .parsingMenu
                self.progress = 0.20
            }

            do {
                let jobResponse = try await self.menuService.createMenus(
                    sessionId: sessionId,
                    lat: location?.latitude,
                    lon: location?.longitude
                )

                // Phase 3: Poll job (30-100%)
                await self.pollJobUntilComplete(jobId: jobResponse.jobId)
            } catch {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.status = .failed
                    self.error = self.handleNetworkError(error)
                }
            }
        }
    }

    // MARK: - Create and Poll Flow (for restaurant without menus)

    private func startCreateAndPollFlow(sessionId: String, location: LocationCoordinate?) {
        pollingTask = Task { @MainActor [weak self] in
            guard let self else { return }

            withAnimation(.easeInOut(duration: 0.3)) {
                self.status = .parsingMenu
                self.progress = 0.0
            }

            do {
                let jobResponse = try await self.menuService.createMenus(
                    sessionId: sessionId,
                    lat: location?.latitude,
                    lon: location?.longitude
                )
                await self.pollJobUntilComplete(jobId: jobResponse.jobId)
            } catch {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.status = .failed
                    self.error = self.handleNetworkError(error)
                }
            }
        }
    }

    // MARK: - Photo Upload

    private func uploadPhotos(_ photos: [CapturedPhoto], sessionId: String) async -> Bool {
        var successCount = 0
        let totalPhotos = photos.count

        for (index, photo) in photos.enumerated() {
            // Update progress for each photo (0.0 to 0.20)
            let photoProgress = 0.20 * Double(index) / Double(totalPhotos)
            await MainActor.run {
                withAnimation(.linear(duration: 0.2)) {
                    self.progress = photoProgress
                }
            }

            guard let imageData = photo.image.jpegData(compressionQuality: AppConstants.Camera.compressionQuality) else {
                AppLogger.shared.error("Failed to convert photo \(photo.id) to JPEG", category: AppLogger.Category.network)
                continue
            }

            // Retry logic (3 attempts with exponential backoff)
            var uploaded = false
            for attempt in 1...3 {
                do {
                    _ = try await sessionService.uploadPhoto(sessionId: sessionId, imageData: imageData)
                    uploaded = true
                    successCount += 1
                    AppLogger.shared.info("Successfully uploaded photo \(photo.id)", category: AppLogger.Category.network)
                    break
                } catch {
                    AppLogger.shared.error("Upload attempt \(attempt)/3 failed for photo \(photo.id): \(error)", category: AppLogger.Category.network)
                    if attempt < 3 {
                        let delaySeconds = pow(2.0, Double(attempt - 1))
                        try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                    }
                }
            }

            if !uploaded {
                AppLogger.shared.error("Failed to upload photo \(photo.id) after 3 attempts", category: AppLogger.Category.network)
                return false
            }
        }

        // Final progress update to 20%
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.progress = 0.20
            }
        }

        return successCount == totalPhotos
    }

    // MARK: - Job Polling

    private func pollJobUntilComplete(jobId: String) async {
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

    // MARK: - Real Polling Flow (for existing job)

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
