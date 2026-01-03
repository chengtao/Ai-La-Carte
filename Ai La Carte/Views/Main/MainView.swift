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
            .sheet(isPresented: $viewModel.showPhotoReview) {
                if let photo = viewModel.pendingPhoto {
                    PhotoReviewSheet(
                        viewModel: dependencyContainer.makePhotoReviewViewModel(
                            sessionId: viewModel.currentSession?.id ?? "",
                            photo: photo
                        ),
                        onAccept: { acceptedPhoto in
                            Task {
                                await viewModel.acceptPhoto(acceptedPhoto)
                            }
                        },
                        onRetake: {
                            viewModel.pendingPhoto = nil
                        },
                        onRecommend: {
                            viewModel.showPhotoReview = false
                            viewModel.showPreferences = true
                        }
                    )
                }
            }
            .navigationDestination(isPresented: $viewModel.showPreferences) {
                if let session = viewModel.currentSession {
                    SessionPreferenceView(
                        viewModel: dependencyContainer.makeSessionPreferenceViewModel(sessionId: session.id)
                    )
                }
            }
            .sheet(isPresented: $viewModel.showAccount) {
                AccountView()
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

            // Account button
            Button {
                viewModel.showAccount = true
            } label: {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, AppConstants.UI.defaultPadding)
        .padding(.top, 60)
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 16) {
            // Nearby Restaurants Overlay
            if !viewModel.nearbyRestaurants.isEmpty {
                nearbyRestaurantsSection
            }

            // Capture Button + Photo Count
            HStack(alignment: .bottom) {
                // Photo thumbnails or placeholder for centering
                if !viewModel.capturedPhotos.isEmpty {
                    photoThumbnails
                } else {
                    // Placeholder to balance the right side
                    Color.clear.frame(width: 80, height: 48)
                }

                Spacer()

                // Capture button
                captureButton

                Spacer()

                // Recommend button (if has photos) or placeholder
                if viewModel.hasPhotosOrRestaurant {
                    recommendButton
                } else {
                    Color.clear.frame(width: 80, height: 48)
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

    // MARK: - Nearby Restaurants

    private var nearbyRestaurantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            if let mostLikely = viewModel.mostLikelyRestaurant {
                Text("Are you at \(mostLikely.name)?")
                    .font(.titleMedium)
                    .foregroundStyle(.white)
            } else {
                Text("Nearby restaurants")
                    .font(.titleMedium)
                    .foregroundStyle(.white)
            }

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

    // MARK: - Photo Thumbnails

    private var photoThumbnails: some View {
        HStack(spacing: -8) {
            ForEach(viewModel.capturedPhotos.prefix(3)) { photo in
                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white, lineWidth: 2)
                    )
            }

            if viewModel.capturedPhotos.count > 3 {
                Text("+\(viewModel.capturedPhotos.count - 3)")
                    .font(.labelSmall)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Recommend Button

    private var recommendButton: some View {
        Button {
            viewModel.proceedToRecommendations()
        } label: {
            Text("Recommend")
                .font(.labelLarge)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.appPrimary)
                .clipShape(Capsule())
        }
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
    MainView(viewModel: MainViewModel(
        restaurantService: MockRestaurantAPIService(),
        sessionService: MockSessionAPIService(),
        locationService: MockLocationService(),
        cameraService: CameraService(),
        analyticsService: MockAnalyticsService()
    ))
}
