//
//  WelcomeView.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import SwiftUI

struct WelcomeView: View {
    @Bindable var viewModel: WelcomeViewModel
    @State private var animateIn = false

    var body: some View {
        ZStack {
            // Magical background gradient
            LinearGradient.magicBackground
                .ignoresSafeArea()

            // Floating particles
            MagicParticlesView(particleCount: 15)
                .ignoresSafeArea()
                .opacity(0.6)

            VStack(spacing: 0) {
                Spacer()

                // Hero Section
                heroSection
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 20)

                Spacer()

                // Feature List
                featureList
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 20)

                Spacer()

                // Bottom Buttons
                bottomSection
                    .opacity(animateIn ? 1 : 0)
            }
            .padding(.horizontal, AppConstants.UI.defaultPadding)
            .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                animateIn = true
            }
        }
        .onChange(of: viewModel.currentStep) { _, newStep in
            if newStep == .completed {
                viewModel.completeOnboarding()
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            // Magical App Icon
            ZStack {
                MagicOrbView(size: 100)

                Image(systemName: "sparkles")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text("AI La Carte")
                    .font(.displayLarge)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.magicPurple, Color.magicPink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("Your personal dining companion")
                    .font(.bodyLarge)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Feature List

    private var featureList: some View {
        VStack(spacing: 20) {
            FeatureRow(
                icon: "camera.fill",
                title: "Scan Any Menu",
                description: "Just point your camera at the menu"
            )

            FeatureRow(
                icon: "location.fill",
                title: "Nearby Restaurants",
                description: "Skip the scan if we already have the menu"
            )

            FeatureRow(
                icon: "sparkles",
                title: "Personalized Picks",
                description: "Recommendations tailored to your taste"
            )
        }
        .padding(.vertical, 24)
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 16) {
            // Permissions info
            if viewModel.currentStep == .welcome {
                permissionInfo
            } else if viewModel.currentStep == .completed {
                completionInfo
            }

            // Primary Button with magical style
            Button {
                Task {
                    if viewModel.currentStep == .welcome {
                        await viewModel.requestPermissions()
                    } else if viewModel.currentStep == .completed {
                        viewModel.completeOnboarding()
                    }
                }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(primaryButtonText)
                }
            }
            .buttonStyle(MagicButtonStyle())
            .disabled(viewModel.isLoading)
        }
    }

    private var primaryButtonText: String {
        switch viewModel.currentStep {
        case .welcome:
            return "Get Started"
        case .requestingLocation, .requestingCamera:
            return "Setting up..."
        case .completed:
            return "Let's Go!"
        }
    }

    private var permissionInfo: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.caption)
                Text("Location")
                    .font(.labelSmall)
                Text("to suggest nearby menus")
                    .font(.labelSmall)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                Image(systemName: "camera.fill")
                    .font(.caption)
                Text("Camera")
                    .font(.labelSmall)
                Text("to read menus")
                    .font(.labelSmall)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
    }

    private var completionInfo: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                permissionStatusIcon(granted: viewModel.locationPermissionStatus.isAuthorized)
                Text("Location")
                    .font(.labelSmall)
            }

            HStack(spacing: 8) {
                permissionStatusIcon(granted: viewModel.cameraPermissionStatus.isAuthorized)
                Text("Camera")
                    .font(.labelSmall)
            }
        }
    }

    private func permissionStatusIcon(granted: Bool) -> some View {
        Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
            .foregroundStyle(granted ? Color.appSuccess : Color.appWarning)
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.magicPurple.opacity(0.15), Color.magicPink.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.magicPurple, Color.magicPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.titleMedium)
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.bodyMedium)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    WelcomeView(viewModel: WelcomeViewModel(
        locationService: MockLocationService(),
        cameraService: CameraService()
    ))
}
