//
//  RecommendationView.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import SwiftUI

struct RecommendationView: View {
    @Environment(\.dependencyContainer) private var dependencyContainer
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: RecommendationViewModel
    @State private var animateIn = false

    var body: some View {
        ZStack {
            // Magical background
            LinearGradient.magicBackground
                .ignoresSafeArea()

            if viewModel.isLoading {
                loadingView
            } else if viewModel.foodRecommendations.isEmpty && viewModel.wineRecommendations.isEmpty {
                emptyView
            } else {
                contentView
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground.opacity(0.95), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Your Recommendations")
                    .font(.titleMedium)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.magicPurple, Color.magicPink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    NotificationCenter.default.post(name: AppConstants.Notifications.dismissToMain, object: nil)
                } label: {
                    Text("Done")
                        .font(.bodyMedium)
                        .foregroundStyle(Color.magicPurple)
                }
            }
        }
        .task {
            await viewModel.loadRecommendations()
            withAnimation(.easeOut(duration: 0.5)) {
                animateIn = true
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading recommendations...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Color.appWarning)

            Text("No recommendations available")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Please try again later")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        VStack(spacing: 0) {
            // Profile summary
            if let summary = viewModel.profileSummary {
                profileSummaryCard(summary)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 10)
            }

            // Tab selector (if wine available)
            if viewModel.hasWineRecommendations {
                tabSelector
                    .opacity(animateIn ? 1 : 0)
            }

            // Recommendations list
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(Array(viewModel.currentItems.enumerated()), id: \.element.id) { index, item in
                        RecommendationItemCard(
                            item: item,
                            isExpanded: viewModel.expandedItemId == item.id,
                            onTap: {
                                viewModel.toggleExpanded(item.id)
                            }
                        )
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)
                        .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.1), value: animateIn)
                    }
                }
                .padding(.horizontal, AppConstants.UI.defaultPadding)
                .padding(.vertical, 16)
            }
        }
    }

    // MARK: - Profile Summary

    private func profileSummaryCard(_ summary: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.magicPurple.opacity(0.2), Color.magicPink.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)

                Image(systemName: "sparkles")
                    .font(.body)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.magicPurple, Color.magicPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text(summary)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(AppConstants.UI.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .magicCard(glowColor: .magicPurple)
        .padding(.horizontal, AppConstants.UI.defaultPadding)
        .padding(.top, 8)
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(RecommendationTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                        Text(tab.rawValue)
                    }
                    .font(.headline)
                    .foregroundStyle(
                        viewModel.selectedTab == tab
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Color.magicPurple, Color.magicPink],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            : AnyShapeStyle(Color.secondary)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        viewModel.selectedTab == tab
                            ? LinearGradient(
                                colors: [Color.magicPurple.opacity(0.1), Color.magicPink.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing)
                    )
                }
            }
        }
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.magicPurple.opacity(0.1), radius: 8, y: 2)
        .padding(.horizontal, AppConstants.UI.defaultPadding)
        .padding(.top, 16)
    }
}

// MARK: - Recommendation Item Card

struct RecommendationItemCard: View {
    let item: RecommendationItemResponse
    let isExpanded: Bool
    let onTap: () -> Void

    private var isFood: Bool { item.type == "food" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Food photo (if available)
            if isFood, let photoUrl = item.photoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.magicPurple.opacity(0.1))
                            .frame(height: 140)
                            .overlay(
                                ProgressView()
                                    .tint(Color.magicPurple)
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.magicPurple.opacity(0.1))
                            .frame(height: 140)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(Color.magicPurple.opacity(0.4))
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
            }

            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    // Title with price for food
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundColor(.primary)

                        if isFood, let price = item.price {
                            Spacer()
                            Text(price)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.magicCoral)
                        }
                    }

                    // Wine details
                    if !isFood {
                        wineDetailsView
                    }

                    // Reason tags
                    FlowLayout(spacing: 6) {
                        ForEach(item.reasonTags) { tag in
                            ReasonTagView(tag: tag)
                        }
                    }
                }

                if isFood {
                    // Confidence indicator for food (wine shows it differently)
                    confidenceIndicator
                }
            }

            // Description (expandable)
            Text(item.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(isExpanded ? nil : 2)

            // Wine pricing row
            if !isFood && item.hasWinePricing {
                winePricingView
            }

            // Expand indicator
            HStack {
                if !isFood {
                    confidenceIndicator
                }
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(Color.magicPurple.opacity(0.6))
            }
        }
        .padding(AppConstants.UI.cardPadding)
        .magicCard(glowColor: isFood ? .magicCoral : .magicPurple)
        .onTapGesture(perform: onTap)
    }

    // MARK: - Wine Details

    @ViewBuilder
    private var wineDetailsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Grape varietal
            if let varietal = item.grapeVarietal {
                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.magicPurple)
                    Text(varietal)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }

            // Origin (region, country)
            if let origin = item.wineOrigin {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.magicPink)
                    Text(origin)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Wine Pricing

    @ViewBuilder
    private var winePricingView: some View {
        HStack(spacing: 16) {
            if let glassPrice = item.priceGlass {
                HStack(spacing: 4) {
                    Image(systemName: "wineglass")
                        .font(.caption)
                        .foregroundStyle(Color.magicPurple)
                    Text("Glass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(glassPrice)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.magicPurple)
                }
            }

            if let bottlePrice = item.priceBottle {
                HStack(spacing: 4) {
                    Image(systemName: "bottle.wine.fill")
                        .font(.caption)
                        .foregroundStyle(Color.magicPink)
                    Text("Bottle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(bottlePrice)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.magicPink)
                }
            }

            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - Confidence Indicator

    private var confidenceIndicator: some View {
        let percentage = Int(item.confidence * 100)
        return Text("\(percentage)%")
            .font(.labelSmall)
            .fontWeight(.semibold)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.magicTeal, Color.appSuccess],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.appSuccess.opacity(0.12))
            )
    }
}

// MARK: - Reason Tag View

struct ReasonTagView: View {
    let tag: ReasonTag

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconForTag(tag.code))
                .font(.caption2)

            Text(tag.label)
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(colorForTag(tag.code).opacity(0.15))
        .foregroundStyle(colorForTag(tag.code))
        .clipShape(Capsule())
    }

    private func iconForTag(_ code: String) -> String {
        switch code {
        case "COMMUNITY_FAVORITE": return "star.fill"
        case "CHEF_SIGNATURE": return "flame.fill"
        case "MATCHES_SPICE": return "leaf.fill"
        case "ADVENTUROUS_PICK": return "sparkles"
        case "CROWD_PLEASER": return "hand.thumbsup.fill"
        case "GREAT_VALUE": return "dollarsign.circle.fill"
        case "PAIRS_WITH_DISH": return "link"
        case "HOUSE_SPECIALTY": return "house.fill"
        case "LIGHT_FRESH": return "drop.fill"
        case "RICH_BOLD": return "circle.fill"
        default: return "checkmark"
        }
    }

    private func colorForTag(_ code: String) -> Color {
        switch code {
        case "COMMUNITY_FAVORITE": return .magicCoral
        case "CHEF_SIGNATURE": return .magicPink
        case "MATCHES_SPICE": return .magicTeal
        case "ADVENTUROUS_PICK": return .magicPurple
        case "PAIRS_WITH_DISH": return .magicBlue
        default: return Color.magicPurple
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)

        for (index, subview) in subviews.enumerated() {
            let point = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            height = y + rowHeight
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RecommendationView(
            viewModel: RecommendationViewModel(
                sessionId: "test",
                recommendationService: MockRecommendationAPIService(),
                analyticsService: MockAnalyticsService()
            )
        )
    }
}
