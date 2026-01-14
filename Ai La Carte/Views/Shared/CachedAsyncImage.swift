//
//  CachedAsyncImage.swift
//  AILaCarte
//
//  Created by Claude on 1/11/26.
//

import SwiftUI

/// A view that displays an image loaded from a URL with intelligent caching
/// Uses ImageCacheService for 2-tier memory + disk caching
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    @Environment(\.dependencyContainer) private var dependencyContainer

    let url: URL
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var loadFailed = false
    @State private var currentURL: URL?
    @State private var loadTask: Task<Void, Never>?

    init(
        url: URL,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let uiImage = loadedImage {
                content(Image(uiImage: uiImage))
            } else if loadFailed {
                placeholder()
            } else {
                placeholder()
            }
        }
        .onAppear {
            // Only load if we haven't loaded this URL yet
            if currentURL != url {
                currentURL = url
                loadTask?.cancel()
                loadTask = Task {
                    await loadImage()
                }
            }
        }
        .onDisappear {
            // Cancel ongoing load if view disappears
            loadTask?.cancel()
            loadTask = nil
        }
    }

    private func loadImage() async {
        // Prevent redundant loads
        guard !isLoading, currentURL == url else { return }

        isLoading = true
        loadFailed = false

        // Use ImageCacheService for loading
        let cacheService = dependencyContainer.imageCacheService

        // Check if task was cancelled
        guard !Task.isCancelled else {
            isLoading = false
            return
        }

        if let image = await cacheService.loadImage(from: url) {
            // Only update state if task wasn't cancelled and URL hasn't changed
            guard !Task.isCancelled, currentURL == url else {
                isLoading = false
                return
            }
            loadedImage = image
            loadFailed = false
        } else {
            // Only update state if task wasn't cancelled and URL hasn't changed
            guard !Task.isCancelled, currentURL == url else {
                isLoading = false
                return
            }
            loadFailed = true
        }

        isLoading = false
    }
}

// MARK: - Convenience Initializer with Phase-like API

extension CachedAsyncImage where Content == AnyView, Placeholder == AnyView {
    /// Initializer with phase-based content similar to AsyncImage
    init(
        url: URL,
        @ViewBuilder content: @escaping (CachedImagePhase) -> some View
    ) {
        self.url = url
        self.content = { image in
            AnyView(content(.success(image)))
        }
        self.placeholder = {
            AnyView(content(.empty))
        }
    }
}

/// Phase of image loading, similar to AsyncImagePhase
enum CachedImagePhase {
    case empty
    case success(Image)
    case failure
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Example 1: Using custom content and placeholder
        CachedAsyncImage(
            url: URL(string: "https://example.com/image.jpg")!,
            content: { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            },
            placeholder: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .overlay(ProgressView())
            }
        )
        .padding()
    }
}
