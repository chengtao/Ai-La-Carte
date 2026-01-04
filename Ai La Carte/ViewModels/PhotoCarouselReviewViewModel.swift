//
//  PhotoCarouselReviewViewModel.swift
//  AILaCarte
//
//  Created by Claude on 1/4/26.
//

import Foundation
import UIKit

/// ViewModel managing state for the photo carousel review view
@MainActor
@Observable
final class PhotoCarouselReviewViewModel: BaseViewModel {
    /// Photos being reviewed (copy from pending photos)
    var photos: [CapturedPhoto]

    /// Current carousel position
    var currentIndex: Int = 0

    private let analyticsService: AnalyticsServiceProtocol
    private let sessionId: String?

    init(
        photos: [CapturedPhoto],
        sessionId: String?,
        analyticsService: AnalyticsServiceProtocol
    ) {
        self.photos = photos
        self.sessionId = sessionId
        self.analyticsService = analyticsService
        super.init()

        analyticsService.track(event: .carouselReviewOpened, sessionId: sessionId, meta: ["count": "\(photos.count)"])
    }

    // MARK: - Photo Management

    /// Deletes a photo at the specified index
    func deletePhoto(at index: Int) {
        guard index >= 0 && index < photos.count else { return }

        photos.remove(at: index)

        // Adjust currentIndex if needed
        if currentIndex >= photos.count && photos.count > 0 {
            currentIndex = photos.count - 1
        }

        analyticsService.track(event: .photoDiscarded, sessionId: sessionId, meta: nil)
    }

    /// Deletes a photo by its ID
    func deletePhoto(withId id: String) {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return }
        deletePhoto(at: index)
    }

    /// Deletes the photo at the current index
    func deleteCurrentPhoto() {
        deletePhoto(at: currentIndex)
    }

    // MARK: - Computed Properties

    /// Whether all photos have been deleted
    var isEmpty: Bool {
        photos.isEmpty
    }

    /// Whether more photos can be taken (under the limit)
    var canTakeMore: Bool {
        photos.count < AppConstants.Photo.maxPhotos
    }

    /// Total number of photos
    var photoCount: Int {
        photos.count
    }

    // MARK: - Analytics

    /// Call when user completes review and continues
    func trackReviewCompleted() {
        analyticsService.track(
            event: .carouselReviewCompleted,
            sessionId: sessionId,
            meta: ["finalCount": "\(photos.count)"]
        )
    }
}
