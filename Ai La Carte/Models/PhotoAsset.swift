//
//  PhotoAsset.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation
import SwiftData
import UIKit

@Model
final class PhotoAsset {
    @Attribute(.unique) var localId: String
    var sessionId: String
    var imageLocalPath: String
    var uploaded: Bool
    var remoteUrl: String?
    var capturedAt: Date

    var session: Session?

    init(
        localId: String = UUID().uuidString,
        sessionId: String,
        imageLocalPath: String,
        uploaded: Bool = false,
        remoteUrl: String? = nil,
        capturedAt: Date = Date()
    ) {
        self.localId = localId
        self.sessionId = sessionId
        self.imageLocalPath = imageLocalPath
        self.uploaded = uploaded
        self.remoteUrl = remoteUrl
        self.capturedAt = capturedAt
    }

    var localURL: URL? {
        URL(fileURLWithPath: imageLocalPath)
    }

    func loadImage() -> UIImage? {
        guard let url = localURL,
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return UIImage(data: data)
    }
}

// MARK: - Photo Response DTO

struct PhotoUploadResponse: Codable {
    let photoId: String
    let url: String

    enum CodingKeys: String, CodingKey {
        case photoId = "photo_id"
        case url
    }
}

// MARK: - Photo Storage Helper

enum PhotoStorage {
    static var photosDirectory: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let photosDir = documentsDirectory.appendingPathComponent("MenuPhotos", isDirectory: true)

        if !FileManager.default.fileExists(atPath: photosDir.path) {
            try? FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)
        }

        return photosDir
    }

    static func savePhoto(_ image: UIImage, sessionId: String) -> String? {
        let photoId = UUID().uuidString
        let fileName = "\(sessionId)_\(photoId).jpg"
        let filePath = photosDirectory.appendingPathComponent(fileName)

        // Compress and resize if needed
        guard let resizedImage = image.resized(maxDimension: AppConstants.Camera.maxImageDimension),
              let data = resizedImage.jpegData(compressionQuality: AppConstants.Camera.compressionQuality) else {
            return nil
        }

        do {
            try data.write(to: filePath)
            return filePath.path
        } catch {
            AppLogger.shared.error("Failed to save photo: \(error)", category: AppLogger.Category.storage)
            return nil
        }
    }

    static func deletePhoto(at path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    static func clearSessionPhotos(sessionId: String) {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(at: photosDirectory, includingPropertiesForKeys: nil) else {
            return
        }

        for file in contents where file.lastPathComponent.hasPrefix(sessionId) {
            try? fileManager.removeItem(at: file)
        }
    }
}

// MARK: - UIImage Extension

extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage? {
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        if ratio >= 1 { return self }

        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }
}
