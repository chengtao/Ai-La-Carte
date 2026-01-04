//
//  NearbyRestaurantCard.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import SwiftUI

struct NearbyRestaurantCard: View {
    let restaurant: RestaurantResponse
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Restaurant name
                Text(restaurant.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // Cuisine
                if let cuisine = restaurant.cuisine {
                    Text(cuisine)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                // Address with icon
                if let address = restaurant.address {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                // Menu badges
                HStack(spacing: 8) {
                    if restaurant.hasFoodMenu {
                        MenuBadge(type: .food, available: true)
                    }

                    if restaurant.hasWineMenu {
                        MenuBadge(type: .wine, available: true)
                    }
                }

                // Last updated at bottom
                if let age = restaurant.menuAgeDescription {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(age)
                            .font(.caption2)
                    }
                    .foregroundStyle(.tertiary)
                }
            }
            .padding(AppConstants.UI.cardPadding)
            .frame(width: 200)
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.defaultCornerRadius))
            .shadow(color: Color.magicPurple.opacity(0.15), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Menu Badge

struct MenuBadge: View {
    enum MenuType {
        case food
        case wine

        var icon: String {
            switch self {
            case .food: return "fork.knife"
            case .wine: return "wineglass"
            }
        }

        var label: String {
            switch self {
            case .food: return "Food"
            case .wine: return "Wine"
            }
        }

        var accentColor: Color {
            switch self {
            case .food: return .magicCoral
            case .wine: return .magicPurple
            }
        }
    }

    let type: MenuType
    let available: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(.caption2)

            Text(type.label)
                .font(.caption2)

            Image(systemName: available ? "checkmark" : "xmark")
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(available ? type.accentColor.opacity(0.12) : Color.gray.opacity(0.15))
        .foregroundStyle(available ? type.accentColor : .gray)
        .clipShape(Capsule())
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        NearbyRestaurantCard(
            restaurant: RestaurantResponse(
                id: "1",
                name: "Golden Dragon",
                cuisine: "Chinese",
                address: "123 Main Street",
                hasFoodMenu: true,
                hasWineMenu: false,
                menuUpdatedAt: ISO8601DateFormatter().string(from: Date())
            )
        ) {}

        NearbyRestaurantCard(
            restaurant: RestaurantResponse(
                id: "2",
                name: "Trattoria Milano",
                cuisine: "Italian",
                address: "456 Oak Avenue",
                hasFoodMenu: true,
                hasWineMenu: true,
                menuUpdatedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400 * 3))
            )
        ) {}
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
