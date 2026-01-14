//
//  ImageCacheService.swift
//  AILaCarte
//
//  Created by Claude on 1/11/26.
//

import Foundation
import UIKit
import SwiftUI
import CryptoKit

// MARK: - Supporting Actors

/// Actor for managing cache metadata with thread safety
private actor MetadataActor {
    private var metadata: CacheMetadata
    private let cacheDirectory: URL
    private let metadataFileName: String

    init(cacheDirectory: URL, metadataFileName: String) {
        self.cacheDirectory = cacheDirectory
        self.metadataFileName = metadataFileName
        self.metadata = Self.loadMetadata(from: cacheDirectory, fileName: metadataFileName) ?? CacheMetadata(entries: [:])
    }

    func getEntry(for key: String) -> CacheMetadata.CacheEntry? {
        return metadata.entries[key]
    }

    func setEntry(_ entry: CacheMetadata.CacheEntry, for key: String) {
        metadata.entries[key] = entry
    }

    func removeEntry(for key: String) {
        metadata.entries.removeValue(forKey: key)
    }

    func getAllEntries() -> [String: CacheMetadata.CacheEntry] {
        return metadata.entries
    }

    func clearAll() {
        metadata = CacheMetadata(entries: [:])
    }

    func getTotalSize() -> Int64 {
        return metadata.entries.values.reduce(0) { $0 + $1.size }
    }

    func saveMetadata() async {
        let metadataURL = cacheDirectory.appendingPathComponent(metadataFileName)
        let metadataToSave = self.metadata // Capture before Task.detached

        await Task.detached {
            do {
                let data = try JSONEncoder().encode(metadataToSave)
                try data.write(to: metadataURL)
            } catch {
                AppLogger.shared.error("Error saving cache metadata: \(error.localizedDescription)", category: AppLogger.Category.storage)
            }
        }.value
    }

    func saveMetadataSync() {
        let metadataURL = cacheDirectory.appendingPathComponent(metadataFileName)

        do {
            let data = try JSONEncoder().encode(metadata)
            try data.write(to: metadataURL)
        } catch {
            AppLogger.shared.error("Error saving cache metadata: \(error.localizedDescription)", category: AppLogger.Category.storage)
        }
    }

    private static func loadMetadata(from directory: URL, fileName: String) -> CacheMetadata? {
        let metadataURL = directory.appendingPathComponent(fileName)

        guard let data = try? Data(contentsOf: metadataURL),
              let metadata = try? JSONDecoder().decode(CacheMetadata.self, from: data) else {
            return nil
        }

        return metadata
    }
}

/// Actor for managing in-flight downloads with thread safety
private actor InFlightActor {
    private var downloads: [URL: Task<UIImage?, Never>] = [:]

    func getTask(for url: URL) -> Task<UIImage?, Never>? {
        return downloads[url]
    }

    func setTask(_ task: Task<UIImage?, Never>, for url: URL) {
        downloads[url] = task
    }

    func removeTask(for url: URL) {
        downloads.removeValue(forKey: url)
    }
}

// MARK: - Cache Metadata Types

private struct CacheMetadata: Codable, Sendable {
    var entries: [String: CacheEntry]

    struct CacheEntry: Codable, Sendable {
        let url: String
        let fileName: String
        let size: Int64
        let createdAt: Date
    }
}

// MARK: - Implementation
// Protocol definition is in DependencyContainer.swift

final class ImageCacheService: ImageCacheServiceProtocol, Sendable {
    // MARK: - Properties

    private nonisolated(unsafe) let memoryCache = NSCache<NSString, UIImage>() // NSCache is thread-safe
    private nonisolated(unsafe) let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let metadataFileName = "metadata.json"

    // Configuration
    private let maxMemoryCacheCount = 100
    private let maxDiskCacheSize: Int64 = 100 * 1024 * 1024 // 100 MB
    private let cacheExpirationDays = 7

    // Thread-safe state management via actors
    private let metadataActor: MetadataActor
    private let inFlightActor = InFlightActor()

    // MARK: - Initialization

    init() {
        // Setup cache directory
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = cachesDirectory.appendingPathComponent("MenuImages", isDirectory: true)

        // Create directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Configure memory cache
        memoryCache.countLimit = maxMemoryCacheCount

        // Initialize metadata actor
        self.metadataActor = MetadataActor(cacheDirectory: cacheDirectory, metadataFileName: metadataFileName)

        // Clean up expired cache on init
        Task {
            await self.clearExpiredCache()
        }
    }

    // MARK: - Public Methods

    func loadImage(from url: URL) async -> UIImage? {
        let cacheKey = Self.cacheKey(for: url)

        // 1. Check memory cache (fastest - synchronous, safe on NSCache)
        if let cachedImage = memoryCache.object(forKey: cacheKey as NSString) {
            return cachedImage
        }

        // 2. Check disk cache (fast - async to avoid blocking)
        if let diskImage = await loadImageFromDiskAsync(for: url, cacheKey: cacheKey) {
            // Cache in memory for next time
            memoryCache.setObject(diskImage, forKey: cacheKey as NSString)
            return diskImage
        }

        // 3. Check if download is already in progress
        if let existingTask = await inFlightActor.getTask(for: url) {
            return await existingTask.value
        }

        // 4. Download from network (slow - but deduplicated)
        let downloadTask = Task<UIImage?, Never> {
            if let downloadedImage = await downloadImage(from: url) {
                // Cache in both memory and disk
                await cacheImage(downloadedImage, for: url)

                // Remove from in-flight
                await inFlightActor.removeTask(for: url)

                return downloadedImage
            }

            // Remove from in-flight on failure too
            await inFlightActor.removeTask(for: url)

            return nil
        }

        // Register the task
        await inFlightActor.setTask(downloadTask, for: url)

        return await downloadTask.value
    }

    func cacheImage(_ image: UIImage, for url: URL) async {
        let cacheKey = Self.cacheKey(for: url)

        // Cache in memory
        memoryCache.setObject(image, forKey: cacheKey as NSString)

        // Cache on disk
        await saveImageToDisk(image, for: url, cacheKey: cacheKey)
    }

    func clearCache() async {
        // Clear memory cache
        memoryCache.removeAllObjects()

        // Clear disk cache
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try? fileManager.removeItem(at: file)
            }
            await metadataActor.clearAll()
            await metadataActor.saveMetadata()
        } catch {
            AppLogger.shared.error("Error clearing cache: \(error.localizedDescription)", category: AppLogger.Category.storage)
        }
    }

    func clearExpiredCache() async {
        let expirationDate = Calendar.current.date(byAdding: .day, value: -cacheExpirationDays, to: Date()) ?? Date()

        var expiredKeys: [String] = []

        let allEntries = await metadataActor.getAllEntries()
        for (key, entry) in allEntries {
            if entry.createdAt < expirationDate {
                expiredKeys.append(key)

                // Delete file
                let fileURL = cacheDirectory.appendingPathComponent(entry.fileName)
                try? fileManager.removeItem(at: fileURL)
            }
        }

        // Remove from metadata
        for key in expiredKeys {
            await metadataActor.removeEntry(for: key)
        }

        if !expiredKeys.isEmpty {
            await metadataActor.saveMetadata()
        }

        // Check if cache size exceeds limit and evict oldest entries
        await evictOldestEntriesIfNeeded()
    }

    func getCacheSize() async -> Int64 {
        return await metadataActor.getTotalSize()
    }

    // MARK: - Private Methods

    /// Async disk loading to avoid blocking the caller thread
    private func loadImageFromDiskAsync(for url: URL, cacheKey: String) async -> UIImage? {
        // Get metadata entry
        guard let entry = await metadataActor.getEntry(for: cacheKey) else {
            return nil
        }

        let fileURL = cacheDirectory.appendingPathComponent(entry.fileName)

        // Perform I/O on background thread
        return await Task.detached {
            guard FileManager.default.fileExists(atPath: fileURL.path),
                  let data = try? Data(contentsOf: fileURL),
                  let image = UIImage(data: data) else {
                // File missing or corrupted, remove from metadata
                await self.removeFromMetadata(cacheKey: cacheKey)
                return nil
            }
            return image
        }.value
    }

    /// Helper to remove entry from metadata
    private func removeFromMetadata(cacheKey: String) async {
        await metadataActor.removeEntry(for: cacheKey)
        await metadataActor.saveMetadata()
    }

    private func downloadImage(from url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            AppLogger.shared.error("Error downloading image from \(url): \(error.localizedDescription)", category: AppLogger.Category.network)
            return nil
        }
    }

    private func saveImageToDisk(_ image: UIImage, for url: URL, cacheKey: String) async {
        // Prepare image data on current thread (CPU work)
        let data: Data?
        let fileExtension: String

        if image.hasAlpha {
            data = image.pngData()
            fileExtension = "png"
        } else {
            data = image.jpegData(compressionQuality: 0.8)
            fileExtension = "jpg"
        }

        guard let imageData = data else {
            return
        }

        let fileName = "\(cacheKey).\(fileExtension)"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)

        // Perform file I/O on background thread
        await Task.detached {
            do {
                try imageData.write(to: fileURL)

                // Update metadata
                let entry = CacheMetadata.CacheEntry(
                    url: url.absoluteString,
                    fileName: fileName,
                    size: Int64(imageData.count),
                    createdAt: Date()
                )
                await self.metadataActor.setEntry(entry, for: cacheKey)
                await self.metadataActor.saveMetadata()

                // Check cache size and evict if needed
                await self.evictOldestEntriesIfNeeded()
            } catch {
                AppLogger.shared.error("Error saving image to disk: \(error.localizedDescription)", category: AppLogger.Category.storage)
            }
        }.value
    }

    private func evictOldestEntriesIfNeeded() async {
        var currentSize = await getCacheSize()

        guard currentSize > maxDiskCacheSize else {
            return
        }

        // Sort entries by creation date (oldest first)
        let sortedEntries = await metadataActor.getAllEntries().sorted { $0.value.createdAt < $1.value.createdAt }

        // Perform eviction on background thread
        await Task.detached {
            for (key, entry) in sortedEntries {
                guard currentSize > self.maxDiskCacheSize else {
                    break
                }

                // Delete file
                let fileURL = self.cacheDirectory.appendingPathComponent(entry.fileName)
                try? FileManager.default.removeItem(at: fileURL)

                // Remove from metadata
                await self.metadataActor.removeEntry(for: key)
                currentSize -= entry.size
            }
        }.value

        await metadataActor.saveMetadata()
    }

    private static func cacheKey(for url: URL) -> String {
        // Use SHA256 hash of URL as cache key
        let data = Data(url.absoluteString.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - UIImage Extension

extension UIImage {
    /// Check if image has alpha channel
    var hasAlpha: Bool {
        guard let cgImage = self.cgImage else { return false }
        let alphaInfo = cgImage.alphaInfo
        return alphaInfo == .first || alphaInfo == .last || alphaInfo == .premultipliedFirst || alphaInfo == .premultipliedLast
    }
}
