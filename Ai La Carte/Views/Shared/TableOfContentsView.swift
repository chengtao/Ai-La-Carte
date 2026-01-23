//
//  TableOfContentsView.swift
//  AILaCarte
//
//  Created by Claude on 1/14/26.
//

import SwiftUI

// MARK: - Table of Contents View

struct TableOfContentsView<Category: Hashable>: View {
    let categories: [(category: Category, itemCount: Int)]
    let activeCategory: Category?
    let onCategoryTap: (Category) -> Void
    let onClose: () -> Void
    let categoryIcon: (Category) -> String
    let categoryName: (Category) -> String

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Drawer content
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Categories")
                            .font(.titleLarge)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)

                        Spacer()

                        Button {
                            onClose()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.appCardBackground)

                    Divider()

                    // Category list
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(Array(categories.enumerated()), id: \.offset) { _, item in
                                CategoryRow(
                                    icon: categoryIcon(item.category),
                                    name: categoryName(item.category),
                                    itemCount: item.itemCount,
                                    isActive: activeCategory.map { $0 == item.category } ?? false,
                                    onTap: {
                                        onCategoryTap(item.category)
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .background(Color.appCardBackground)
                }
                .frame(width: geometry.size.width * 0.6)
                .background(Color.appCardBackground)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 5, y: 0)
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Only allow dragging to the left (closing)
                            if value.translation.width < 0 {
                                dragOffset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            if value.translation.width < -50 || value.predictedEndTranslation.width < -100 {
                                onClose()
                            }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                )

                Spacer()
            }
        }
    }
}

// MARK: - Category Row

private struct CategoryRow: View {
    let icon: String
    let name: String
    let itemCount: Int
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(isActive ? Color.white : Color.appPrimary)
                    .frame(width: 32)

                // Name and count
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.bodyLarge)
                        .fontWeight(isActive ? .semibold : .regular)
                        .foregroundStyle(isActive ? Color.white : Color.primary)

                    Text("\(itemCount) item\(itemCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(isActive ? Color.white.opacity(0.8) : Color.secondary)
                }

                Spacer()

                // Arrow indicator
                if isActive {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive ? AnyShapeStyle(LinearGradient.magicPrimary) : AnyShapeStyle(Color.clear))
            )
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - TOC Peek Indicator

struct TOCPeekIndicator: View {
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<3) { _ in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.appPrimary.opacity(0.6))
                    .frame(width: 20, height: 3)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.appCardBackground.opacity(0.9))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 2, y: 0)
        )
        .scaleEffect(isPulsing ? 1.1 : 1.0)
        .animation(
            .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true),
            value: isPulsing
        )
        .onAppear {
            isPulsing = true
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var activeCategory: FoodCategory? = .appetizer
        @State private var showTOC = true

        let categories: [(category: FoodCategory, itemCount: Int)] = [
            (.appetizer, 5),
            (.entree, 8),
            (.dessert, 4)
        ]

        var body: some View {
            ZStack {
                Color.gray.opacity(0.2)
                    .ignoresSafeArea()

                if showTOC {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation {
                                showTOC = false
                            }
                        }

                    TableOfContentsView(
                        categories: categories,
                        activeCategory: activeCategory,
                        onCategoryTap: { category in
                            activeCategory = category
                        },
                        onClose: {
                            withAnimation {
                                showTOC = false
                            }
                        },
                        categoryIcon: { $0.icon },
                        categoryName: { $0.displayName }
                    )
                    .transition(.move(edge: .leading))
                }

                VStack {
                    Spacer()
                    HStack {
                        TOCPeekIndicator()
                            .padding(.leading, 8)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
    }

    return PreviewWrapper()
}
