//
//  SurveyView.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import SwiftUI

struct SurveyView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: SurveyViewModel

    @State private var animateIn = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.magicBackground
                    .ignoresSafeArea()

                if viewModel.isComplete {
                    completionView
                } else if let item = viewModel.currentItem {
                    surveyContent(for: item)
                }
            }
            .navigationTitle("How was it?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip All") {
                        dismiss()
                    }
                    .font(.bodyMedium)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                animateIn = true
            }
        }
    }

    // MARK: - Survey Content

    private func surveyContent(for item: RecommendationItemResponse) -> some View {
        VStack(spacing: 32) {
            // Progress
            progressIndicator

            Spacer()

            // Item info
            itemCard(for: item)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 20)

            // Question
            Text("Did you try this?")
                .font(.titleLarge)
                .foregroundStyle(.primary)

            // Rating buttons
            ratingButtons
                .opacity(animateIn ? 1 : 0)

            Spacer()

            // Skip button
            Button {
                viewModel.skip()
            } label: {
                Text("Skip this one")
                    .font(.bodyMedium)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, AppConstants.UI.defaultPadding)
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.magicPurple.opacity(0.15))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient.magicPrimary)
                        .frame(width: geometry.size.width * viewModel.progress, height: 6)
                }
            }
            .frame(height: 6)

            Text("\(viewModel.currentItemIndex + 1) of \(viewModel.items.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 16)
    }

    // MARK: - Item Card

    private func itemCard(for item: RecommendationItemResponse) -> some View {
        VStack(spacing: 12) {
            // Icon with gradient
            Image(systemName: item.type == "food" ? "fork.knife" : "wineglass")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.magicPurple, Color.magicPink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Title
            Text(item.title)
                .font(.displayMedium)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            // Description
            Text(item.description)
                .font(.bodyMedium)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .padding(AppConstants.UI.cardPadding)
        .frame(maxWidth: .infinity)
        .magicCard(glowColor: .magicPurple)
    }

    // MARK: - Rating Buttons

    private var ratingButtons: some View {
        HStack(spacing: 16) {
            ForEach([FeedbackRating.loved, .disliked, .notOrdered], id: \.self) { rating in
                ratingButton(for: rating)
            }
        }
    }

    private func ratingButton(for rating: FeedbackRating) -> some View {
        Button {
            Task {
                await viewModel.submitRating(rating)
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: rating.emoji)
                    .font(.system(size: 32))

                Text(rating.displayText)
                    .font(.labelSmall)
            }
            .foregroundStyle(colorForRating(rating))
            .frame(width: 100, height: 100)
            .background(colorForRating(rating).opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func colorForRating(_ rating: FeedbackRating) -> Color {
        switch rating {
        case .loved: return Color.appSuccess
        case .disliked: return Color.appError
        case .notOrdered: return .secondary
        }
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.appSuccess)

            Text("Thanks for your feedback!")
                .font(.displayMedium)
                .foregroundStyle(.primary)

            Text("Your ratings help us improve future recommendations.")
                .font(.bodyMedium)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
            }
            .buttonStyle(MagicButtonStyle())
            .padding(.bottom, 40)
        }
        .padding(.horizontal, AppConstants.UI.defaultPadding)
    }
}

// MARK: - Preview

#Preview {
    SurveyView(
        viewModel: SurveyViewModel(
            sessionId: "test",
            items: [
                RecommendationItemResponse(
                    id: "1",
                    type: "food",
                    title: "Kung Pao Chicken",
                    description: "Tender chicken with peanuts and chili peppers",
                    reasons: [],
                    confidence: 0.9,
                    pairingIds: nil,
                    photoUrl: nil,
                    price: "$18.95",
                    category: "entree",
                    grapeVarietal: nil,
                    region: nil,
                    country: nil,
                    priceGlass: nil,
                    priceBottle: nil
                )
            ],
            recommendationService: MockRecommendationAPIService(),
            analyticsService: MockAnalyticsService()
        )
    )
}
