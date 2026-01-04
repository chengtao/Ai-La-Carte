//
//  PreferenceManager.swift
//  AILaCarte
//
//  Created by Claude on 1/4/26.
//

import Foundation

/// Protocol for centralized preference management
/// Single source of truth for user preferences across all ViewModels
@MainActor
protocol PreferenceManagerProtocol: Sendable {
    /// The current user preferences
    var currentPreferences: UserPreferences { get }

    /// Updates preferences and persists them
    func updatePreferences(_ preferences: UserPreferences)

    /// Resets preferences to defaults
    func resetPreferences()

    /// Loads preferences from storage (call on app launch)
    func loadPreferences()
}

/// Implementation of PreferenceManager that wraps UserPreferencesStorage
/// and provides reactive updates to preferences
@MainActor
@Observable
final class PreferenceManager: PreferenceManagerProtocol, @unchecked Sendable {
    private(set) var currentPreferences: UserPreferences = .default

    private let storage: UserPreferencesStorageProtocol

    nonisolated init(storage: UserPreferencesStorageProtocol) {
        self.storage = storage
    }

    func loadPreferences() {
        currentPreferences = storage.loadPreferences()
    }

    func updatePreferences(_ preferences: UserPreferences) {
        guard preferences != currentPreferences else { return }
        currentPreferences = preferences
        storage.savePreferences(preferences)
    }

    func resetPreferences() {
        storage.resetPreferences()
        currentPreferences = .default
    }
}
