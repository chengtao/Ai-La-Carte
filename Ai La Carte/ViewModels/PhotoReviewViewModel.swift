//
//  PhotoReviewViewModel.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation
import UIKit

@Observable
final class PhotoReviewViewModel: BaseViewModel {
    let sessionId: String
    let photo: UIImage
    var isUploading = false

    private let sessionService: SessionAPIServiceProtocol

    init(sessionId: String, photo: UIImage, sessionService: SessionAPIServiceProtocol) {
        self.sessionId = sessionId
        self.photo = photo
        self.sessionService = sessionService
        super.init()
    }
}
