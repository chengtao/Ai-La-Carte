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
            // Background gradient
            LinearGradient(
                colors: [Color.appPrimary.opacity(0.1), Color.appBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

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
            // App Icon / Illustration
            ZStack {
                Circle()
                    .fill(Color.appPrimary.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.appPrimary)
            }

            VStack(spacing: 8) {
                Text("AI La Carte")
                    .font(.displayLarge)
                    .foregroundStyle(Color.appSecondary)

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

            // Primary Button
            Button {
                Task {
                    if viewModel.currentStep == .welcome {
                        await viewModel.requestPermissions()
                    } else if viewModel.currentStep == .completed {
                        viewModel.completeOnboarding()
                    }
                }
            } label: {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(primaryButtonText)
                            .font(.titleMedium)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: AppConstants.UI.buttonHeight)
                .background(Color.appPrimary)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.defaultCornerRadius))
            }
            .disabled(viewModel.isLoading)

            // Secondary Button (skip)
            if viewModel.currentStep == .welcome {
                Button {
                    viewModel.proceedWithoutPermissions()
                } label: {
                    Text("Maybe later")
                        .font(.bodyMedium)
                        .foregroundStyle(.secondary)
                }
            }
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
        .foregroundStyle(Color.appSecondary)
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
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.appPrimary)
                .frame(width: 44, height: 44)
                .background(Color.appPrimary.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.titleMedium)
                    .foregroundStyle(Color.appSecondary)

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
