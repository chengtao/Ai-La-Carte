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
                    .foregroundColor(.black)
                    .lineLimit(1)

                // Distance and update time
                HStack {
                    Text(restaurant.formattedDistance)
                        .font(.caption)
                        .foregroundColor(.gray)

                    Spacer()

                    if let age = restaurant.menuAgeDescription {
                        Text("Updated \(age)")
                            .font(.caption)
                            .foregroundColor(.gray)
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

                // Confidence indicator
                if restaurant.confidence >= 80 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.appSuccess)

                        Text("Most likely")
                            .font(.caption)
                            .foregroundStyle(Color.appSuccess)
                    }
                }
            }
            .padding(AppConstants.UI.cardPadding)
            .frame(width: 200)
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.defaultCornerRadius))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
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
        .background(available ? Color.appSuccess.opacity(0.15) : Color.gray.opacity(0.15))
        .foregroundStyle(available ? Color.appSuccess : .gray)
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
                distanceMeters: 42,
                hasFoodMenu: true,
                hasWineMenu: false,
                menuUpdatedAt: ISO8601DateFormatter().string(from: Date()),
                confidence: 95
            )
        ) {}

        NearbyRestaurantCard(
            restaurant: RestaurantResponse(
                id: "2",
                name: "Trattoria Milano",
                distanceMeters: 150,
                hasFoodMenu: true,
                hasWineMenu: true,
                menuUpdatedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400 * 3)),
                confidence: 72
            )
        ) {}
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
