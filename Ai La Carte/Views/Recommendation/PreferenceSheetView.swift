//
//  PreferenceSheetView.swift
//  AILaCarte
//
//  Created by Claude on 1/3/26.
//

import SwiftUI

// MARK: - Preference Tab

enum PreferenceTab: String, CaseIterable {
    case food = "Food"
    case wine = "Wine"

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .wine: return "wineglass"
        }
    }
}

// MARK: - Preference Sheet View

struct PreferenceSheetView: View {
    @Binding var preferences: UserPreferences
    @Binding var isPresented: Bool
    var onContinue: (() -> Void)?
    var onReset: (() -> Void)?

    @State private var selectedTab: PreferenceTab = .food

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Tab Picker
            tabPicker
                .padding(.horizontal, AppConstants.UI.defaultPadding)
                .padding(.top, 16)

            // Tab Content
            TabView(selection: $selectedTab) {
                FoodPreferencesTab(preferences: $preferences.food)
                    .tag(PreferenceTab.food)

                WinePreferencesTab(preferences: $preferences.wine)
                    .tag(PreferenceTab.wine)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Continue Button (only shown when onContinue is provided)
            if let onContinue = onContinue {
                continueButton(action: onContinue)
            }
        }
        .background(Color.appCardBackground)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            // Drag handle
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 8)

            HStack {
                // Reset button
                Button {
                    preferences = .default
                    onReset?()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.body)
                        .foregroundStyle(Color.magicPurple)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.magicPurple.opacity(0.1))
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Preferences")
                        .font(.headline)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.magicPurple, Color.magicPink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("Help us find the perfect recommendations")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if onContinue == nil {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, AppConstants.UI.defaultPadding)
            .padding(.top, 8)
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(PreferenceTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                        Text(tab.rawValue)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(
                        selectedTab == tab
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
                        selectedTab == tab
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
        .background(Color.appBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Continue Button

    private var isDefaultPreferences: Bool {
        preferences == .default
    }

    private var continueButtonText: String {
        isDefaultPreferences ? "Continue with Default Settings" : "Continue with Your Settings"
    }

    private func continueButton(action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 8) {
                Text(continueButtonText)
                    .font(.headline)
                Image(systemName: "arrow.right")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient.magicPrimary
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.magicPurple.opacity(0.3), radius: 8, y: 4)
        }
        .padding(.horizontal, AppConstants.UI.defaultPadding)
        .padding(.vertical, 16)
    }
}

// MARK: - Food Preferences Tab

struct FoodPreferencesTab: View {
    @Binding var preferences: FoodPreference

    @State private var localRichness: Double
    @State private var localSpicePreference: Double

    init(preferences: Binding<FoodPreference>) {
        self._preferences = preferences
        self._localRichness = State(initialValue: Double(preferences.wrappedValue.richness))
        self._localSpicePreference = State(initialValue: Double(preferences.wrappedValue.spicePreference))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. Ingredient Preference (checkboxes)
                PreferenceCheckboxGroup(
                    title: "Ingredients",
                    icon: "fork.knife",
                    options: FoodIngredient.allCases,
                    selection: $preferences.ingredients,
                    accentColor: .magicPurple
                )

                // 2. Richness Slider
                PreferenceSliderCompact(
                    title: "Richness",
                    value: $localRichness,
                    leftIcon: "drop.fill",
                    leftLabel: "Light",
                    rightIcon: "circle.fill",
                    rightLabel: "Rich",
                    label: preferences.richnessLabel,
                    accentColor: .magicPink
                )
                .onChange(of: localRichness) { _, newValue in
                    preferences.richness = Int(newValue)
                }

                // 3. Spice Preference Slider
                PreferenceSliderCompact(
                    title: "Spice Preference",
                    value: $localSpicePreference,
                    leftIcon: "leaf.fill",
                    leftLabel: "Mild",
                    rightIcon: "flame.fill",
                    rightLabel: "Spicy",
                    label: preferences.spiceLabel,
                    accentColor: .magicCoral
                )
                .onChange(of: localSpicePreference) { _, newValue in
                    preferences.spicePreference = Int(newValue)
                }
            }
            .padding(.horizontal, AppConstants.UI.defaultPadding)
            .padding(.vertical, 20)
        }
        // Sync local state when preferences change externally (e.g., reset button)
        .onChange(of: preferences) { _, newValue in
            localRichness = Double(newValue.richness)
            localSpicePreference = Double(newValue.spicePreference)
        }
    }
}

// MARK: - Wine Preferences Tab

struct WinePreferencesTab: View {
    @Binding var preferences: WinePreference

    /// Wine categories excluding "other"
    private var selectableCategories: [WineCategory] {
        WineCategory.allCases.filter { $0 != .other }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Wine Types (Categories)
                PreferenceCheckboxGroup(
                    title: "Wine Types",
                    icon: "wineglass.fill",
                    options: selectableCategories,
                    selection: $preferences.categories,
                    accentColor: .magicTeal
                )

                // Countries
                PreferenceCheckboxGroup(
                    title: "Countries",
                    icon: "globe.americas.fill",
                    options: WineCountry.allCases,
                    selection: $preferences.countries
                )

                // White Grape Varietals
                PreferenceCheckboxGroup(
                    title: "White Grapes",
                    icon: "leaf.fill",
                    options: WhiteGrapeVarietal.allCases,
                    selection: $preferences.whiteVarietals
                )

                // Red Grape Varietals
                PreferenceCheckboxGroup(
                    title: "Red Grapes",
                    icon: "leaf.fill",
                    options: RedGrapeVarietal.allCases,
                    selection: $preferences.redVarietals,
                    accentColor: .magicCoral
                )

                // Flavors
                PreferenceCheckboxGroup(
                    title: "Flavor Profiles",
                    icon: "sparkles",
                    options: WineFlavor.allCases,
                    selection: $preferences.flavors,
                    accentColor: .magicPink
                )
            }
            .padding(.horizontal, AppConstants.UI.defaultPadding)
            .padding(.vertical, 20)
        }
    }
}

// MARK: - Preference Option Protocol

/// Protocol for preference options that can display a user-friendly label
protocol PreferenceOption: RawRepresentable & CaseIterable & Hashable & Identifiable where RawValue == String {
    var displayLabel: String { get }
}

// Default implementation: use rawValue as label
extension PreferenceOption {
    var displayLabel: String { rawValue }
}

// Make all preference enums conform to PreferenceOption
extension FoodIngredient: PreferenceOption {}
extension WineCountry: PreferenceOption {}
extension WhiteGrapeVarietal: PreferenceOption {}
extension RedGrapeVarietal: PreferenceOption {}
extension WineFlavor: PreferenceOption {}

// WineCategory uses displayName instead of rawValue
extension WineCategory: PreferenceOption {
    var displayLabel: String { displayName }
}

// MARK: - Preference Checkbox Group

struct PreferenceCheckboxGroup<T: PreferenceOption>: View {
    let title: String
    let icon: String
    let options: [T]
    @Binding var selection: Set<T>
    var accentColor: Color = .magicPurple

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(accentColor)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                // Select All / Clear All
                Button {
                    if selection.count == options.count {
                        selection.removeAll()
                    } else {
                        selection = Set(options)
                    }
                } label: {
                    Text(selection.count == options.count ? "Clear" : "All")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(accentColor)
                }
            }

            // Checkbox Grid
            FlowLayout(spacing: 8) {
                ForEach(options, id: \.id) { option in
                    PreferenceCheckbox(
                        label: option.displayLabel,
                        isSelected: selection.contains(option),
                        accentColor: accentColor
                    ) {
                        if selection.contains(option) {
                            selection.remove(option)
                        } else {
                            selection.insert(option)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.appBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preference Checkbox

struct PreferenceCheckbox: View {
    let label: String
    let isSelected: Bool
    var accentColor: Color = .magicPurple
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(isSelected ? accentColor : Color.secondary.opacity(0.5))

                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? accentColor.opacity(0.12) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? accentColor.opacity(0.3) : Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
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

#Preview("Initial Preference Collection") {
    struct PreviewWrapper: View {
        @State private var preferences = UserPreferences.default
        @State private var isPresented = true

        var body: some View {
            PreferenceSheetView(
                preferences: $preferences,
                isPresented: $isPresented,
                onContinue: { print("Continue tapped") }
            )
        }
    }

    return PreviewWrapper()
}

#Preview("Adjustment Mode") {
    struct PreviewWrapper: View {
        @State private var preferences = UserPreferences.default
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
                    .frame(height: 500)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(radius: 10)
                    .padding()
                }
            }
        }
    }

    return PreviewWrapper()
}
