//
//  PhotoCarouselReviewView.swift
//  AILaCarte
//
//  Created by Claude on 1/4/26.
//

import SwiftUI

struct PhotoCarouselReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: PhotoCarouselReviewViewModel

    let onContinue: ([CapturedPhoto]) -> Void
    let onTakeMore: ([CapturedPhoto]) -> Void
    let onDiscardAll: () -> Void
    let launchedFromThumbnails: Bool

    // Track swipe offset for each photo
    @State private var dragOffsets: [String: CGSize] = [:]
    // Track whether a vertical swipe has been committed (vs horizontal for carousel)
    @State private var isVerticalSwipe: [String: Bool] = [:]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if viewModel.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        // Photo carousel
                        photoCarousel

                        // Page indicator
                        pageIndicator
                            .padding(.vertical, 16)

                        // Bottom action bar
                        bottomActionBar
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onTakeMore(viewModel.photos)
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(.white)
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("Review Photos")
                        .font(.titleMedium)
                        .foregroundStyle(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.isEmpty {
                        Text("\(viewModel.currentIndex + 1)/\(viewModel.photoCount)")
                            .font(.labelSmall)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Photo Carousel

    private var photoCarousel: some View {
        TabView(selection: $viewModel.currentIndex) {
            ForEach(Array(viewModel.photos.enumerated()), id: \.element.id) { index, photo in
                photoCard(photo: photo)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .id(viewModel.photos.count) // Force TabView to rebuild when count changes
    }

    private func photoCard(photo: CapturedPhoto) -> some View {
        let offset = dragOffsets[photo.id] ?? .zero
        let photoId = photo.id // Capture the ID for use in closures
        let isVertical = isVerticalSwipe[photo.id] ?? false

        return ZStack {
            // Photo
            Image(uiImage: photo.image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.defaultCornerRadius))
                .padding(.horizontal, AppConstants.UI.defaultPadding)
                .offset(y: isVertical ? offset.height : 0)
                .opacity(isVertical ? 1 - Double(abs(offset.height)) / 300 : 1)
                .rotationEffect(isVertical ? .degrees(Double(offset.height) / 20) : .zero)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { gesture in
                            let horizontal = abs(gesture.translation.width)
                            let vertical = abs(gesture.translation.height)

                            // Determine swipe direction on first significant movement
                            if isVerticalSwipe[photoId] == nil {
                                // Only commit to vertical if clearly upward and more vertical than horizontal
                                if gesture.translation.height < -10 && vertical > horizontal * 1.5 {
                                    isVerticalSwipe[photoId] = true
                                } else if horizontal > 10 {
                                    // It's a horizontal swipe, don't capture it
                                    isVerticalSwipe[photoId] = false
                                }
                            }

                            // Only track if committed to vertical swipe
                            if isVerticalSwipe[photoId] == true && gesture.translation.height < 0 {
                                dragOffsets[photoId] = gesture.translation
                            }
                        }
                        .onEnded { gesture in
                            // Only handle if we committed to a vertical swipe
                            if isVerticalSwipe[photoId] == true {
                                // If swiped up enough, delete the photo
                                if gesture.translation.height < -100 {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        dragOffsets[photoId] = CGSize(width: 0, height: -500)
                                    }
                                    // Delay deletion to allow animation to complete
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        dragOffsets.removeValue(forKey: photoId)
                                        isVerticalSwipe.removeValue(forKey: photoId)
                                        viewModel.deletePhoto(withId: photoId)
                                    }
                                } else {
                                    // Snap back
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        dragOffsets[photoId] = .zero
                                    }
                                    isVerticalSwipe.removeValue(forKey: photoId)
                                }
                            } else {
                                // Reset state for horizontal swipes
                                isVerticalSwipe.removeValue(forKey: photoId)
                            }
                        }
                )

            // Swipe hint indicator (shows when dragging vertically)
            if isVertical && offset.height < -20 {
                VStack {
                    Image(systemName: "trash")
                        .font(.title)
                        .foregroundStyle(.white)
                        .opacity(min(1, Double(abs(offset.height)) / 100))
                    Text("Release to remove")
                        .font(.labelSmall)
                        .foregroundStyle(.white.opacity(0.8))
                        .opacity(offset.height < -60 ? 1 : 0)
                }
                .padding(.top, 60)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<viewModel.photoCount, id: \.self) { index in
                Circle()
                    .fill(index == viewModel.currentIndex ? Color.magicPurple : Color.white.opacity(0.4))
                    .frame(width: index == viewModel.currentIndex ? 10 : 8, height: index == viewModel.currentIndex ? 10 : 8)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.currentIndex)
            }
        }
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        VStack(spacing: 12) {
            // Hint text
            Text("Swipe up to remove unwanted photos")
                .font(.bodyMedium)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            // Action buttons
            if launchedFromThumbnails {
                // Launched from thumbnails - show Take More button only
                Button {
                    onTakeMore(viewModel.photos)
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera")
                            .font(.bodyLarge)
                        Text(viewModel.canTakeMore ? "Take More" : "Limit Reached")
                            .font(.labelLarge)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(viewModel.canTakeMore ? LinearGradient.magicPrimary : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!viewModel.canTakeMore)
            } else {
                // Launched from Recommend button - show Preferences button only
                Button {
                    viewModel.trackReviewCompleted()
                    onContinue(viewModel.photos)
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.bodyLarge)
                        Text("Preferences")
                            .font(.labelLarge)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LinearGradient.magicPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.horizontal, AppConstants.UI.defaultPadding)
        .padding(.bottom, 40)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.5))

            VStack(spacing: 8) {
                Text("No Photos")
                    .font(.titleLarge)
                    .foregroundStyle(.white)

                Text("Take photos of the menu to get recommendations")
                    .font(.bodyMedium)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Take Photos button
            Button {
                onTakeMore(viewModel.photos)
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera")
                        .font(.bodyLarge)
                    Text("Take Photos")
                        .font(.labelLarge)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LinearGradient.magicPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, AppConstants.UI.defaultPadding)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Preview

#Preview {
    PhotoCarouselReviewView(
        viewModel: PhotoCarouselReviewViewModel(
            photos: [
                CapturedPhoto(id: "1", image: UIImage(systemName: "photo")!),
                CapturedPhoto(id: "2", image: UIImage(systemName: "photo.fill")!),
                CapturedPhoto(id: "3", image: UIImage(systemName: "photo.badge.plus")!)
            ],
            sessionId: "test",
            analyticsService: MockAnalyticsService()
        ),
        onContinue: { _ in },
        onTakeMore: { _ in },
        onDiscardAll: {},
        launchedFromThumbnails: false
    )
}
