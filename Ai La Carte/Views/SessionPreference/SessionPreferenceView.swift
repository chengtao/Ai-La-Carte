//
//  SessionPreferenceView.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import SwiftUI

struct SessionPreferenceView: View {
    @Environment(\.dependencyContainer) private var dependencyContainer
    @Bindable var viewModel: SessionPreferenceViewModel
    @State private var animateIn = false

    init(viewModel: SessionPreferenceViewModel) {
        self.viewModel = viewModel
        // Customize navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.appBackground)
        appearance.titleTextAttributes = [.foregroundColor: UIColor.darkGray]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.darkGray]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerSection
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : -20)

                Spacer()

                // Sliders
                slidersSection
                    .opacity(animateIn ? 1 : 0)

                Spacer()

                // Continue button
                continueButton
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 20)
            }
            .padding(.horizontal, AppConstants.UI.defaultPadding)
            .padding(.bottom, 40)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Your Preferences")
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                animateIn = true
            }
        }
        .navigationDestination(isPresented: $viewModel.showCalculating) {
            if let jobId = viewModel.jobId {
                CalculatingView(
                    viewModel: dependencyContainer.makeCalculatingViewModel(
                        sessionId: viewModel.sessionId,
                        jobId: jobId
                    )
                )
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 48))
                .foregroundStyle(Color.appPrimary)

            Text("Quick Preferences")
                .font(.displayMedium)
                .foregroundColor(.black)

            Text("Help us personalize your recommendations")
                .font(.bodyMedium)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }

    // MARK: - Sliders

    private var slidersSection: some View {
        VStack(spacing: 40) {
            // Adventurous slider
            PreferenceSlider(
                title: "How adventurous today?",
                value: $viewModel.adventurousClassic,
                leftLabel: "Classic",
                rightLabel: "Adventurous",
                leftIcon: "heart.fill",
                rightIcon: "star.fill",
                currentLabel: viewModel.adventurousnessLabel
            )

            // Spice slider
            PreferenceSlider(
                title: "Spice tolerance",
                value: $viewModel.spiceTolerance,
                leftLabel: "Mild",
                rightLabel: "Spicy",
                leftIcon: "leaf.fill",
                rightIcon: "flame.fill",
                currentLabel: viewModel.spiceLabel
            )
        }
        .padding(.vertical, 32)
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button {
            Task {
                await viewModel.submitAndGenerate()
            }
        } label: {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Find My Dishes")
                        .font(.titleMedium)

                    Image(systemName: "sparkles")
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: AppConstants.UI.buttonHeight)
            .background(Color.appPrimary)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.defaultCornerRadius))
        }
        .disabled(viewModel.isLoading)
    }
}

// MARK: - Preference Slider

struct PreferenceSlider: View {
    let title: String
    @Binding var value: Double
    let leftLabel: String
    let rightLabel: String
    let leftIcon: String
    let rightIcon: String
    let currentLabel: String

    var body: some View {
        VStack(spacing: 16) {
            // Title and current value
            HStack {
                Text(title)
                    .font(.titleMedium)
                    .foregroundColor(.black)

                Spacer()

                Text(currentLabel)
                    .font(.labelLarge)
                    .foregroundStyle(Color.appPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.appPrimary.opacity(0.1))
                    .clipShape(Capsule())
            }

            // Slider
            VStack(spacing: 8) {
                Slider(value: $value, in: 1...5, step: 1)
                    .tint(Color.appPrimary)

                // Labels
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: leftIcon)
                            .font(.caption)
                        Text(leftLabel)
                            .font(.labelSmall)
                    }
                    .foregroundColor(.gray)

                    Spacer()

                    HStack(spacing: 4) {
                        Text(rightLabel)
                            .font(.labelSmall)
                        Image(systemName: rightIcon)
                            .font(.caption)
                    }
                    .foregroundColor(.gray)
                }
            }
        }
        .padding(AppConstants.UI.cardPadding)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.defaultCornerRadius))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SessionPreferenceView(
            viewModel: SessionPreferenceViewModel(
                sessionId: "test",
                sessionService: MockSessionAPIService(),
                recommendationService: MockRecommendationAPIService(),
                analyticsService: MockAnalyticsService()
            )
        )
    }
}
