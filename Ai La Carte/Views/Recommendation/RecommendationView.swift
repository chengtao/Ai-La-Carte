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
            } else if viewModel.scoredFoodRecommendations.isEmpty && viewModel.scoredWineRecommendations.isEmpty {
                emptyView
            } else {
                contentView
            }

            // Floating preferences button
            if !viewModel.isLoading && (!viewModel.scoredFoodRecommendations.isEmpty || !viewModel.scoredWineRecommendations.isEmpty) {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        floatingPreferencesButton
                            .padding(.trailing, AppConstants.UI.defaultPadding)
                            .padding(.bottom, 24)
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.isPreferenceSheetPresented) {
            PreferenceSheetView(
                preferences: $viewModel.currentPreferences,
                isPresented: $viewModel.isPreferenceSheetPresented,
                onReset: {
                    viewModel.resetPreferences()
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled)
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

    // MARK: - Floating Preferences Button

    private var floatingPreferencesButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                viewModel.isPreferenceSheetPresented = true
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                Text("Preferences")
                    .font(.labelLarge)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(LinearGradient.magicPrimary)
                    .shadow(color: Color.magicPurple.opacity(0.4), radius: 8, y: 4)
            )
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        VStack(spacing: 0) {
            // Profile summary
            if let summary = viewModel.profileSummary, viewModel.selectedTab != .cart {
                profileSummaryCard(summary)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 10)
            }

            // Tab selector (always show if wine available or cart has items)
            if viewModel.hasWineRecommendations || viewModel.cartItemCount > 0 {
                tabSelector
                    .opacity(animateIn ? 1 : 0)
            }

            // Content based on selected tab
            if viewModel.selectedTab == .cart {
                cartTabContent
            } else if viewModel.selectedTab == .food {
                // Sectioned food recommendations
                foodSectionedContent
            } else {
                // Wine recommendations (flat list)
                wineListContent
            }
        }
    }

    // MARK: - Food Sectioned Content

    private var foodSectionedContent: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                ForEach(viewModel.groupedFoodRecommendations, id: \.category) { group in
                    FoodSectionView(
                        category: group.category,
                        items: group.items,
                        expandedItemId: viewModel.expandedItemId,
                        isInCart: viewModel.isFoodInCart,
                        onTap: { itemId in
                            viewModel.toggleExpanded(itemId)
                        },
                        onCartToggle: { item in
                            viewModel.toggleFoodCart(item)
                        },
                        animateIn: animateIn
                    )
                }
            }
            .padding(.horizontal, AppConstants.UI.defaultPadding)
            .padding(.vertical, 16)
            .padding(.bottom, 80) // Space for floating button
        }
    }

    // MARK: - Wine Sectioned Content

    private var wineListContent: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                ForEach(viewModel.groupedWineRecommendations, id: \.category) { group in
                    WineSectionView(
                        category: group.category,
                        items: group.items,
                        expandedItemId: viewModel.expandedItemId,
                        isInCart: viewModel.isWineInCart,
                        onTap: { itemId in
                            viewModel.toggleExpanded(itemId)
                        },
                        onCartToggle: { item in
                            viewModel.toggleWineCart(item)
                        },
                        animateIn: animateIn
                    )
                }
            }
            .padding(.horizontal, AppConstants.UI.defaultPadding)
            .padding(.vertical, 16)
            .padding(.bottom, 80) // Space for floating button
        }
    }

    // MARK: - Cart Tab Content

    private var cartTabContent: some View {
        Group {
            if viewModel.cartItemCount == 0 {
                emptyCartView
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Cart summary header
                        cartSummaryHeader

                        // Cart items
                        ForEach(viewModel.totalCartItems, id: \.id) { item in
                            CartItemRow(
                                id: item.id,
                                title: item.title,
                                price: item.price,
                                isFood: item.isFood,
                                onRemove: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        viewModel.removeFromCartById(item.id)
                                    }
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                        }
                    }
                    .padding(.horizontal, AppConstants.UI.defaultPadding)
                    .padding(.vertical, 16)
                }
            }
        }
    }

    private var emptyCartView: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.magicPurple.opacity(0.1), Color.magicPink.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "cart")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.magicPurple, Color.magicPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("Your cart is empty")
                .font(.titleMedium)
                .foregroundStyle(.primary)

            Text("Add items from the Food or Wine tabs\nto build your order")
                .font(.bodyMedium)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
    }

    private var cartSummaryHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Order")
                    .font(.titleMedium)
                    .foregroundStyle(.primary)

                Text("\(viewModel.cartItemCount) item\(viewModel.cartItemCount == 1 ? "" : "s") selected")
                    .font(.bodyMedium)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.clearCart()
                }
            } label: {
                Text("Clear All")
                    .font(.labelSmall)
                    .foregroundStyle(Color.appError)
            }
        }
        .padding(AppConstants.UI.cardPadding)
        .magicCard(glowColor: .magicPurple)
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

                        // Cart badge
                        if tab == .cart && viewModel.cartItemCount > 0 {
                            Text("\(viewModel.cartItemCount)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(LinearGradient.magicPrimary)
                                )
                        }
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

// MARK: - Food Section View

struct FoodSectionView: View {
    let category: FoodCategory
    let items: [ScoredFoodItem]
    let expandedItemId: Int?
    let isInCart: (ScoredFoodItem) -> Bool
    let onTap: (Int) -> Void
    let onCartToggle: (ScoredFoodItem) -> Void
    let animateIn: Bool

    @State private var isCollapsed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCollapsed.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    // Category icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.magicCoral.opacity(0.2), Color.magicPink.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)

                        Image(systemName: category.icon)
                            .font(.body)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.magicCoral, Color.magicPink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    // Category name
                    Text(category.displayName)
                        .font(.titleMedium)
                        .foregroundStyle(.primary)

                    // Item count
                    Text("\(items.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(LinearGradient.magicPrimary)
                        )

                    Spacer()

                    // Collapse indicator
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.magicPurple)
                }
            }
            .buttonStyle(.plain)

            // Section items
            if !isCollapsed {
                VStack(spacing: 12) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        FoodItemCard(
                            item: item,
                            isExpanded: expandedItemId == item.id,
                            isInCart: isInCart(item),
                            onTap: {
                                onTap(item.id)
                            },
                            onCartToggle: {
                                onCartToggle(item)
                            }
                        )
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)
                        .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.05), value: animateIn)
                    }
                }
            }
        }
    }
}

// MARK: - Wine Section View

struct WineSectionView: View {
    let category: WineCategory
    let items: [ScoredWineItem]
    let expandedItemId: Int?
    let isInCart: (ScoredWineItem) -> Bool
    let onTap: (Int) -> Void
    let onCartToggle: (ScoredWineItem) -> Void
    let animateIn: Bool

    @State private var isCollapsed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCollapsed.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    // Category icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.magicPurple.opacity(0.2), Color.magicBlue.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)

                        Image(systemName: category.icon)
                            .font(.body)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.magicPurple, Color.magicBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    // Category name
                    Text(category.displayName)
                        .font(.titleMedium)
                        .foregroundStyle(.primary)

                    // Item count
                    Text("\(items.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [Color.magicPurple, Color.magicBlue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                        )

                    Spacer()

                    // Collapse indicator
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.magicPurple)
                }
            }
            .buttonStyle(.plain)

            // Section items
            if !isCollapsed {
                VStack(spacing: 12) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        WineItemCard(
                            item: item,
                            isExpanded: expandedItemId == item.id,
                            isInCart: isInCart(item),
                            onTap: {
                                onTap(item.id)
                            },
                            onCartToggle: {
                                onCartToggle(item)
                            }
                        )
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)
                        .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.05), value: animateIn)
                    }
                }
            }
        }
    }
}

// MARK: - Cart Item Row

struct CartItemRow: View {
    let id: Int
    let title: String
    let price: String?
    let isFood: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Item icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isFood
                                ? [Color.magicCoral.opacity(0.2), Color.magicPink.opacity(0.15)]
                                : [Color.magicPurple.opacity(0.2), Color.magicBlue.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: isFood ? "fork.knife" : "wineglass")
                    .font(.body)
                    .foregroundStyle(
                        LinearGradient(
                            colors: isFood
                                ? [Color.magicCoral, Color.magicPink]
                                : [Color.magicPurple, Color.magicBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Item details
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let price = price {
                    Text(price)
                        .font(.caption)
                        .foregroundStyle(isFood ? Color.magicCoral : Color.magicPurple)
                }
            }

            Spacer()

            // Remove button
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(AppConstants.UI.cardPadding)
        .magicCard(glowColor: isFood ? .magicCoral : .magicPurple)
    }
}

// MARK: - Food Item Card

struct FoodItemCard: View {
    let item: ScoredFoodItem
    let isExpanded: Bool
    let isInCart: Bool
    let onTap: () -> Void
    let onCartToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Food photo (if available)
            if let photoUrl = item.photoUrl, let url = URL(string: photoUrl) {
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
                    // Title with price
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundColor(.primary)

                        if let priceFormatted = item.priceFormatted {
                            Spacer()
                            Text(priceFormatted)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.magicCoral)
                        }
                    }

                    // Food tags
                    FlowLayout(spacing: 6) {
                        ForEach(item.foodTags) { tag in
                            FoodTagView(tag: tag)
                        }
                    }
                }

                // Confidence indicator
                confidenceIndicator
            }

            // Description (expandable)
            Text(item.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(isExpanded ? nil : 2)

            // Bottom row with expand indicator and cart button
            HStack {
                Spacer()

                // Cart button
                Button {
                    onCartToggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isInCart ? "checkmark" : "plus")
                            .font(.caption.weight(.semibold))
                        Text(isInCart ? "Added" : "Add")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(isInCart ? Color.white : Color.magicPurple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isInCart
                                ? LinearGradient.magicPrimary
                                : LinearGradient(colors: [Color.magicPurple.opacity(0.15)], startPoint: .leading, endPoint: .trailing)
                            )
                    )
                }
                .buttonStyle(.plain)

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(Color.magicPurple.opacity(0.6))
            }
        }
        .padding(AppConstants.UI.cardPadding)
        .magicCard(glowColor: .magicCoral)
        .onTapGesture(perform: onTap)
    }

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

// MARK: - Wine Item Card

struct WineItemCard: View {
    let item: ScoredWineItem
    let isExpanded: Bool
    let isInCart: Bool
    let onTap: () -> Void
    let onCartToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(.primary)

                // Wine details
                wineDetailsView

                // Wine tags
                FlowLayout(spacing: 6) {
                    ForEach(item.wineTags) { tag in
                        WineTagView(tag: tag)
                    }
                }
            }

            // Description (expandable)
            Text(item.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(isExpanded ? nil : 2)

            // Wine pricing row
            if item.hasWinePricing {
                winePricingView
            }

            // Bottom row with confidence, expand indicator, and cart button
            HStack {
                confidenceIndicator

                Spacer()

                // Cart button
                Button {
                    onCartToggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isInCart ? "checkmark" : "plus")
                            .font(.caption.weight(.semibold))
                        Text(isInCart ? "Added" : "Add")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(isInCart ? Color.white : Color.magicPurple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isInCart
                                ? LinearGradient.magicPrimary
                                : LinearGradient(colors: [Color.magicPurple.opacity(0.15)], startPoint: .leading, endPoint: .trailing)
                            )
                    )
                }
                .buttonStyle(.plain)

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(Color.magicPurple.opacity(0.6))
            }
        }
        .padding(AppConstants.UI.cardPadding)
        .magicCard(glowColor: .magicPurple)
        .onTapGesture(perform: onTap)
    }

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

    @ViewBuilder
    private var winePricingView: some View {
        HStack(spacing: 16) {
            if let glassPriceFormatted = item.priceGlassFormatted {
                HStack(spacing: 4) {
                    Image(systemName: "wineglass")
                        .font(.caption)
                        .foregroundStyle(Color.magicPurple)
                    Text("Glass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(glassPriceFormatted)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.magicPurple)
                }
            }

            if let bottlePriceFormatted = item.priceBottleFormatted {
                HStack(spacing: 4) {
                    Image(systemName: "bottle.wine.fill")
                        .font(.caption)
                        .foregroundStyle(Color.magicPink)
                    Text("Bottle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(bottlePriceFormatted)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.magicPink)
                }
            }

            Spacer()
        }
        .padding(.top, 4)
    }

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

// MARK: - Displayable Tag Protocol

protocol DisplayableTag: Identifiable {
    var code: String { get }
    var label: String { get }
}

extension FoodTag: DisplayableTag {}
extension WineTag: DisplayableTag {}

// MARK: - Food Tag View

struct FoodTagView: View {
    let tag: FoodTag

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
        case "SIMILAR_TO_PAST": return "heart.fill"
        case "VEGETARIAN": return "leaf.circle.fill"
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
        case "GREAT_VALUE": return .appSuccess
        case "VEGETARIAN": return .magicTeal
        default: return Color.magicPurple
        }
    }
}

// MARK: - Wine Tag View

struct WineTagView: View {
    let tag: WineTag

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
        case "HIGH_CP_VALUE": return "chart.line.uptrend.xyaxis"
        case "RISING_STAR": return "star.leadinghalf.filled"
        case "FINE_AND_RARE": return "diamond.fill"
        case "AWARD_WINNING": return "medal.fill"
        case "FAMOUS": return "crown.fill"
        case "HIGH_SCORE": return "gauge.with.needle.fill"
        default: return "checkmark"
        }
    }

    private func colorForTag(_ code: String) -> Color {
        switch code {
        case "HIGH_CP_VALUE": return .appSuccess
        case "RISING_STAR": return .magicCoral
        case "FINE_AND_RARE": return .magicPink
        case "AWARD_WINNING": return .magicPurple
        case "FAMOUS": return .magicBlue
        case "HIGH_SCORE": return .magicTeal
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
    let container = MockDependencyContainer()
    return NavigationStack {
        RecommendationView(
            viewModel: container.makeRecommendationViewModel(
                sessionId: "test",
                foodMenuId: 999,
                wineMenuId: 998,
                preferences: .default
            )
        )
    }
}
