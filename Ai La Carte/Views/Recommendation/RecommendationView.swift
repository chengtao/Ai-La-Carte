//
//  RecommendationView.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import SwiftUI

struct RecommendationView: View {
    @Environment(\.dependencyContainer) private var dependencyContainer
    @Bindable var viewModel: RecommendationViewModel
    @State private var animateIn = false

    init(viewModel: RecommendationViewModel) {
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

            if viewModel.isLoading {
                loadingView
            } else if viewModel.foodRecommendations.isEmpty && viewModel.wineRecommendations.isEmpty {
                emptyView
            } else {
                contentView
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("Your Recommendations")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    // TODO: Show survey or dismiss
                } label: {
                    Text("Done")
                        .font(.bodyMedium)
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
                .foregroundColor(.gray)
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
                .foregroundColor(.black)

            Text("Please try again later")
                .font(.subheadline)
                .foregroundColor(.gray)
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
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.title2)
                .foregroundStyle(Color.appPrimary)

            Text(summary)
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(2)
        }
        .padding(AppConstants.UI.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appPrimary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.defaultCornerRadius))
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
                    .foregroundColor(viewModel.selectedTab == tab ? Color.appPrimary : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        viewModel.selectedTab == tab
                            ? Color.appPrimary.opacity(0.1)
                            : Color.clear
                    )
                }
            }
        }
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, AppConstants.UI.defaultPadding)
        .padding(.top, 16)
    }
}

// MARK: - Recommendation Item Card

struct RecommendationItemCard: View {
    let item: RecommendationItemResponse
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(.black)

                    // Reason tags
                    FlowLayout(spacing: 6) {
                        ForEach(item.reasonTags) { tag in
                            ReasonTagView(tag: tag)
                        }
                    }
                }

                Spacer()

                // Confidence indicator
                confidenceIndicator
            }

            // Description (expandable)
            Text(item.description)
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(isExpanded ? nil : 2)

            // Expand indicator
            HStack {
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(AppConstants.UI.cardPadding)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.defaultCornerRadius))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        .onTapGesture(perform: onTap)
    }

    private var confidenceIndicator: some View {
        let percentage = Int(item.confidence * 100)
        return Text("\(percentage)%")
            .font(.labelSmall)
            .foregroundStyle(Color.appSuccess)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.appSuccess.opacity(0.1))
            .clipShape(Capsule())
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
        case "COMMUNITY_FAVORITE": return .orange
        case "CHEF_SIGNATURE": return .red
        case "MATCHES_SPICE": return .green
        case "ADVENTUROUS_PICK": return .purple
        case "PAIRS_WITH_DISH": return .blue
        default: return Color.appPrimary
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
