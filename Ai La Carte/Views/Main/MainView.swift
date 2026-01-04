//
//  MainView.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import SwiftUI
import AVFoundation

struct MainView: View {
    @Environment(\.dependencyContainer) private var dependencyContainer
    @Bindable var viewModel: MainViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                // Camera Preview
                Color.black
                    .ignoresSafeArea()

                if viewModel.cameraState == .running {
                    CameraPreviewRepresentable(cameraService: viewModel.cameraService)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                } else if viewModel.cameraState == .starting {
                    ProgressView()
                        .tint(.white)
                } else if viewModel.cameraState == .permissionDenied {
                    cameraPermissionView
                }

                // Overlay UI
                VStack {
                    // Top Bar
                    topBar

                    Spacer()

                    // Bottom Section
                    bottomSection
                }
            }
            .task {
                await viewModel.startCamera()
                await viewModel.fetchNearbyRestaurants()
            }
            .onDisappear {
                viewModel.stopCamera()
            }
            .fullScreenCover(isPresented: $viewModel.showPhotoCarouselReview) {
                PhotoCarouselReviewView(
                    viewModel: dependencyContainer.makePhotoCarouselReviewViewModel(
                        photos: viewModel.pendingPhotos,
                        sessionId: viewModel.currentSession?.id
                    ),
                    onContinue: { reviewedPhotos in
                        Task {
                            await viewModel.completeReview(withPhotos: reviewedPhotos)
                        }
                    },
                    onTakeMore: {
                        viewModel.returnToCamera()
                    },
                    onDiscardAll: {
                        viewModel.discardAllPendingPhotos()
                    },
                    launchedFromThumbnails: viewModel.reviewLaunchedFromThumbnails
                )
            }
            .navigationDestination(isPresented: $viewModel.showCalculating) {
                if let calculatingViewModel = viewModel.calculatingViewModel {
                    CalculatingView(viewModel: calculatingViewModel)
                }
            }
            .sheet(isPresented: $viewModel.showPreferenceSheet) {
                PreferenceSheetView(
                    preferences: $viewModel.userPreferences,
                    isPresented: $viewModel.showPreferenceSheet,
                    onContinue: {
                        Task {
                            await viewModel.confirmPreferencesAndProceed()
                        }
                    },
                    onReset: {
                        viewModel.resetPreferences()
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .onReceive(NotificationCenter.default.publisher(for: AppConstants.Notifications.dismissToMain)) { _ in
                viewModel.resetSession()
            }
        }
    }

    // MARK: - Camera Permission View

    private var cameraPermissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.6))

            Text("Camera Access Required")
                .font(.titleMedium)
                .foregroundStyle(.white)

            Text("Enable camera access in Settings to scan menus")
                .font(.bodyMedium)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .tint(.white)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Spacer()

            // Torch toggle button
            if viewModel.isTorchAvailable && viewModel.cameraState == .running {
                Button {
                    viewModel.toggleTorch()
                } label: {
                    Image(systemName: viewModel.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.title2)
                        .foregroundStyle(viewModel.isTorchOn ? .yellow : .white)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .padding(.trailing, AppConstants.UI.defaultPadding)
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 16) {
            // Nearby Restaurants Overlay or Loading State
            if viewModel.isLoadingRestaurants && viewModel.nearbyRestaurants.isEmpty {
                loadingRestaurantsView
            } else if !viewModel.nearbyRestaurants.isEmpty {
                nearbyRestaurantsSection
            }

            // Capture Button + Photo Thumbnails + Recommend Button
            // Use ZStack to ensure capture button stays centered
            ZStack {
                // Capture button - always centered
                captureButton

                // Side elements
                HStack {
                    // Photo thumbnails - left aligned with fixed width
                    if !viewModel.pendingPhotos.isEmpty {
                        photoThumbnails
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Spacer()
                    }

                    // Spacing for capture button area
                    Spacer()
                        .frame(width: 100)

                    // Recommend button - right aligned with fixed width
                    if !viewModel.pendingPhotos.isEmpty {
                        recommendButton
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, AppConstants.UI.defaultPadding)
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Loading Restaurants View

    private var loadingRestaurantsView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text("Take menu photos to start your personalized recommendations")
                    .font(.titleMedium)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, AppConstants.UI.defaultPadding)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Nearby Restaurants

    private var nearbyRestaurantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text("Or pick where you are at")
                .font(.titleMedium)
                .foregroundStyle(.white)

            // Restaurant cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.nearbyRestaurants) { restaurant in
                        NearbyRestaurantCard(restaurant: restaurant) {
                            Task {
                                await viewModel.selectRestaurant(restaurant)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, AppConstants.UI.defaultPadding)
        .padding(.vertical, 16)
    }

    // MARK: - Capture Button

    private var captureButton: some View {
        Button {
            Task {
                await viewModel.capturePhoto()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 72, height: 72)

                Circle()
                    .stroke(.white, lineWidth: 4)
                    .frame(width: 80, height: 80)
            }
        }
        .disabled(viewModel.cameraState != .running)
    }

    // MARK: - Recommend Button

    private var recommendButton: some View {
        Button {
            viewModel.showReviewFromRecommend()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.subheadline.weight(.semibold))
                Text("Next")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.leading, 4)
            .padding(.trailing, 4)
            .padding(.vertical, 10)
            .background(
                LinearGradient.magicPrimary
            )
            .clipShape(Capsule())
            .shadow(color: Color.magicPurple.opacity(0.4), radius: 6, y: 2)
        }
    }

    // MARK: - Photo Thumbnails

    private var photoThumbnails: some View {
        Button {
            viewModel.showReviewFromThumbnails()
        } label: {
            HStack(spacing: -20) {
                ForEach(viewModel.pendingPhotos.prefix(3)) { photo in
                    Image(uiImage: photo.image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.white, lineWidth: 2)
                        )
                }

                if viewModel.pendingPhotos.count > 3 {
                    Text("+\(viewModel.pendingPhotos.count - 3)")
                        .font(.labelSmall)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .buttonStyle(.plain)
    }

}

// MARK: - Camera Preview Representable

struct CameraPreviewRepresentable: UIViewRepresentable {
    let cameraService: CameraServiceProtocol

    func makeUIView(context: Context) -> CameraPreviewUIView {
        AppLogger.shared.info("CameraPreviewRepresentable: makeUIView called", category: AppLogger.Category.camera)
        let view = CameraPreviewUIView()
        view.backgroundColor = .black

        // Set up session immediately if available
        if let realService = cameraService as? CameraService {
            AppLogger.shared.info("CameraPreviewRepresentable: cast succeeded, session: \(realService.session != nil)", category: AppLogger.Category.camera)
            if let session = realService.session {
                view.updateSession(session)
            }
        } else {
            AppLogger.shared.error("CameraPreviewRepresentable: cast to CameraService FAILED", category: AppLogger.Category.camera)
        }

        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        AppLogger.shared.debug("CameraPreviewRepresentable: updateUIView called", category: AppLogger.Category.camera)
        // Update session when view updates
        if let realService = cameraService as? CameraService,
           let session = realService.session {
            uiView.updateSession(session)
        }
    }
}

// MARK: - Preview

#Preview {
    let container = MockDependencyContainer()
    return MainView(viewModel: container.makeMainViewModel())
}
