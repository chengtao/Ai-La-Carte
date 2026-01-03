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

    var body: some View {
        ZStack {
            // Background
            Color.appBackground.ignoresSafeArea()

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
            viewModel.startPolling()
            startAnimations()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
        .navigationDestination(isPresented: $viewModel.showRecommendations) {
            RecommendationView(
                viewModel: dependencyContainer.makeRecommendationViewModel(sessionId: viewModel.sessionId)
            )
        }
    }

    // MARK: - Animated Illustration

    private var animatedIllustration: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.appPrimary.opacity(0.2), lineWidth: 4)
                .frame(width: 160, height: 160)

            // Animated ring
            Circle()
                .trim(from: 0, to: viewModel.progress)
                .stroke(Color.appPrimary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(-90))

            // Pulsing inner circle
            Circle()
                .fill(Color.appPrimary.opacity(0.1))
                .frame(width: 120, height: 120)
                .scaleEffect(animatePulse ? 1.1 : 1.0)

            // Icon
            currentStepIcon
                .font(.system(size: 48))
                .foregroundStyle(Color.appPrimary)
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
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appPrimary.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appPrimary)
                        .frame(width: geometry.size.width * viewModel.progress, height: 8)
                }
            }
            .frame(height: 8)

            // Percentage
            Text("\(viewModel.progressPercentage)%")
                .font(.labelLarge)
                .foregroundStyle(Color.appPrimary)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 8) {
            Text(viewModel.currentStepText)
                .font(.titleMedium)
                .foregroundStyle(Color.appSecondary)
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
            return Color.appPrimary
        } else {
            return Color.appPrimary.opacity(0.2)
        }
    }

    // MARK: - Tip Section

    private var tipSection: some View {
        VStack(spacing: 12) {
            Text("Did you know?")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.gray)

            Text(randomTip)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 50)
    }

    private var randomTip: String {
        let tips = [
            "We analyze public reviews to find the most loved dishes.",
            "Your taste preferences help us personalize recommendations.",
            "We consider spice levels, portion sizes, and more.",
            "Community favorites often have the best reviews.",
            "Chef's signatures are dishes the restaurant is known for."
        ]
        return tips.randomElement() ?? tips[0]
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
                sessionId: "test",
                jobId: "job1",
                recommendationService: MockRecommendationAPIService()
            )
        )
    }
}
