//
//  CalculatingView.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import SwiftUI

struct CalculatingView: View {
    @Environment(\.dependencyContainer) private var dependencyContainer
    @Bindable var viewModel: CalculatingViewModel

    @State private var animatePulse = false
    @State private var animateStep = false
    @State private var currentTip: String = ""

    private let tips = [
        "We analyze public reviews to find the most loved dishes.",
        "Your taste preferences help us personalize recommendations.",
        "We consider spice levels, portion sizes, and more.",
        "Community favorites often have the best reviews.",
        "Chef's signatures are dishes the restaurant is known for."
    ]

    var body: some View {
        ZStack {
            // Magical background
            LinearGradient.magicBackground
                .ignoresSafeArea()

            // Floating particles
            MagicParticlesView(particleCount: 20)
                .ignoresSafeArea()
                .opacity(0.5)

            VStack(spacing: 40) {
                Spacer()

                // Animated illustration
                animatedIllustration

                // Progress section
                progressSection

                // Status text
                statusSection

                Spacer()

                // Fun fact or tip (optional)
                tipSection
            }
            .padding(.horizontal, AppConstants.UI.defaultPadding)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            if currentTip.isEmpty {
                currentTip = tips.randomElement() ?? tips[0]
            }
            viewModel.startPolling()
            startAnimations()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
        .navigationDestination(isPresented: $viewModel.showRecommendations) {
            RecommendationView(
                viewModel: dependencyContainer.makeRecommendationViewModel(
                    sessionId: viewModel.sessionId,
                    foodMenuId: viewModel.foodMenuId,
                    wineMenuId: viewModel.wineMenuId,
                    preferences: viewModel.preferences
                )
            )
        }
        .alert("No Menu Detected", isPresented: $viewModel.noMenusDetected) {
            Button("Try Again") {
                NotificationCenter.default.post(
                    name: AppConstants.Notifications.dismissToMain,
                    object: nil
                )
            }
        } message: {
            Text("We couldn't detect a menu from your photos. Please try again with clearer photos.")
        }
    }

    // MARK: - Animated Illustration

    private var animatedIllustration: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.magicPurple.opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: 60,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .scaleEffect(animatePulse ? 1.15 : 1.0)

            // Outer ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.magicPurple.opacity(0.2), Color.magicPink.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 4
                )
                .frame(width: 160, height: 160)

            // Animated progress ring
            Circle()
                .trim(from: 0, to: viewModel.progress)
                .stroke(
                    LinearGradient.magicPrimary,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(-90))
                .shadow(color: Color.magicPurple.opacity(0.5), radius: 8)

            // Pulsing inner circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.magicPink.opacity(0.2), Color.magicPurple.opacity(0.1)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)
                .scaleEffect(animatePulse ? 1.1 : 1.0)

            // Icon with gradient
            currentStepIcon
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.magicPurple, Color.magicPink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.pulse, options: .repeating)
        }
    }

    private var currentStepIcon: some View {
        Image(systemName: iconForStatus(viewModel.status))
    }

    private func iconForStatus(_ status: SessionStatus) -> String {
        switch status {
        case .created, .photosUploading:
            return "arrow.up.doc"
        case .parsingMenu:
            return "text.viewfinder"
        case .collectingReviews:
            return "star.bubble"
        case .buildingProfile:
            return "person.crop.circle.badge.checkmark"
        case .ranking:
            return "sparkles"
        case .done:
            return "checkmark.circle"
        case .failed:
            return "exclamationmark.triangle"
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: 12) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.magicPurple.opacity(0.15))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient.magicPrimary)
                        .frame(width: geometry.size.width * viewModel.progress, height: 12)
                        .shadow(color: Color.magicPurple.opacity(0.4), radius: 4)
                }
            }
            .frame(height: 12)

            // Percentage with gradient
            Text("\(viewModel.progressPercentage)%")
                .font(.titleMedium)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.magicPurple, Color.magicPink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 8) {
            Text(viewModel.currentStepText)
                .font(.titleMedium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .id(viewModel.status) // Animate on change
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 10)),
                    removal: .opacity.combined(with: .offset(y: -10))
                ))

            // Step dots
            HStack(spacing: 8) {
                ForEach(stepStatuses, id: \.self) { stepStatus in
                    Circle()
                        .fill(dotColor(for: stepStatus))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.status)
    }

    private var stepStatuses: [SessionStatus] {
        [.photosUploading, .parsingMenu, .collectingReviews, .buildingProfile, .ranking]
    }

    private func dotColor(for stepStatus: SessionStatus) -> Color {
        if stepStatus.progress <= viewModel.status.progress {
            return Color.magicPurple
        } else {
            return Color.magicPurple.opacity(0.2)
        }
    }

    // MARK: - Tip Section

    private var tipSection: some View {
        VStack(spacing: 8) {
            Text("Did you know?")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            Text(currentTip)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 50)
    }

    // MARK: - Animations

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            animatePulse = true
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CalculatingView(
            viewModel: CalculatingViewModel(
                mode: .polling(jobId: "job1"),
                preferences: .default,
                menuService: MockMenuAPIService(),
                sessionService: MockSessionAPIService()
            )
        )
    }
}
