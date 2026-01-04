//
//  PreferenceSheetView.swift
//  AILaCarte
//
//  Created by Claude on 1/3/26.
//

import SwiftUI

/// Floating bottom sheet for adjusting food preferences in RecommendationView
struct PreferenceSheetView: View {
    @Binding var preferences: FoodPreference
    @Binding var isPresented: Bool

    @State private var localAdventurousness: Double
    @State private var localSpiceTolerance: Double

    init(preferences: Binding<FoodPreference>, isPresented: Binding<Bool>) {
        self._preferences = preferences
        self._isPresented = isPresented
        self._localAdventurousness = State(initialValue: Double(preferences.wrappedValue.adventurousness))
        self._localSpiceTolerance = State(initialValue: Double(preferences.wrappedValue.spiceTolerance))
    }

    var body: some View {
        VStack(spacing: 24) {
            // Drag handle
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 8)

            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Adjust Preferences")
                        .font(.headline)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.magicPurple, Color.magicPink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("Recommendations update automatically")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            // Sliders
            VStack(spacing: 24) {
                PreferenceSliderCompact(
                    title: "Adventurousness",
                    value: $localAdventurousness,
                    leftIcon: "heart.fill",
                    leftLabel: "Classic",
                    rightIcon: "star.fill",
                    rightLabel: "Adventurous",
                    label: adventurousnessLabel,
                    accentColor: .magicPurple
                )
                .onChange(of: localAdventurousness) { _, newValue in
                    preferences.adventurousness = Int(newValue)
                }

                PreferenceSliderCompact(
                    title: "Spice Tolerance",
                    value: $localSpiceTolerance,
                    leftIcon: "leaf.fill",
                    leftLabel: "Mild",
                    rightIcon: "flame.fill",
                    rightLabel: "Spicy",
                    label: spiceLabel,
                    accentColor: .magicCoral
                )
                .onChange(of: localSpiceTolerance) { _, newValue in
                    preferences.spiceTolerance = Int(newValue)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .background(Color.appCardBackground)
    }

    private var adventurousnessLabel: String {
        FoodPreference(
            adventurousness: Int(localAdventurousness),
            spiceTolerance: Int(localSpiceTolerance)
        ).adventurousnessLabel
    }

    private var spiceLabel: String {
        FoodPreference(
            adventurousness: Int(localAdventurousness),
            spiceTolerance: Int(localSpiceTolerance)
        ).spiceLabel
    }
}

// MARK: - Compact Preference Slider

struct PreferenceSliderCompact: View {
    let title: String
    @Binding var value: Double
    let leftIcon: String
    let leftLabel: String
    let rightIcon: String
    let rightLabel: String
    let label: String
    let accentColor: Color

    var body: some View {
        VStack(spacing: 12) {
            // Title and current value
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Spacer()
                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(accentColor.opacity(0.12))
                    )
            }

            // Slider with icons
            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Image(systemName: leftIcon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(leftLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(width: 50)

                Slider(value: $value, in: 1...5, step: 1)
                    .tint(accentColor)

                VStack(spacing: 2) {
                    Image(systemName: rightIcon)
                        .font(.caption)
                        .foregroundStyle(accentColor)
                    Text(rightLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(width: 50)
            }

            // Step indicators
            HStack {
                ForEach(1...5, id: \.self) { step in
                    Circle()
                        .fill(Int(value) >= step ? accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                    if step < 5 {
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 62)
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var preferences = FoodPreference.default
        @State private var isPresented = true

        var body: some View {
            ZStack {
                Color.gray.opacity(0.3)
                    .ignoresSafeArea()

                VStack {
                    Spacer()
                    PreferenceSheetView(
                        preferences: $preferences,
                        isPresented: $isPresented
                    )
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(radius: 10)
                    .padding()
                }
            }
        }
    }

    return PreviewWrapper()
}
