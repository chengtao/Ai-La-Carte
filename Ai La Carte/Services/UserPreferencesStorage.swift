//
//  UserPreferencesStorage.swift
//  AILaCarte
//
//  Created by Claude on 1/4/26.
//

import Foundation

// MARK: - User Preferences Storage Protocol

protocol UserPreferencesStorageProtocol: Sendable {
    /// Loads user preferences from local storage
    func loadPreferences() -> UserPreferences

    /// Saves user preferences to local storage
    func savePreferences(_ preferences: UserPreferences)

    /// Resets preferences to defaults and clears storage
    func resetPreferences()
}

// MARK: - User Preferences Storage Implementation

final class UserPreferencesStorage: UserPreferencesStorageProtocol, Sendable {
    private let key = AppConstants.Storage.userPreferencesKey

    func loadPreferences() -> UserPreferences {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            AppLogger.shared.info("[Preferences] No saved preferences found, using defaults", category: AppLogger.Category.session)
            return .default
        }

        do {
            let preferences = try JSONDecoder().decode(UserPreferences.self, from: data)
            AppLogger.shared.info("[Preferences] Loaded preferences: ingredients=\(preferences.food.ingredients.count), spice=\(preferences.food.spicePreference), richness=\(preferences.food.richness)", category: AppLogger.Category.session)
            return preferences
        } catch {
            AppLogger.shared.error("[Preferences] Failed to decode preferences: \(error)", category: AppLogger.Category.session)
            return .default
        }
    }

    func savePreferences(_ preferences: UserPreferences) {
        do {
            let data = try JSONEncoder().encode(preferences)
            UserDefaults.standard.set(data, forKey: key)
            AppLogger.shared.info("[Preferences] Saved preferences: ingredients=\(preferences.food.ingredients.count), spice=\(preferences.food.spicePreference), richness=\(preferences.food.richness)", category: AppLogger.Category.session)
        } catch {
            AppLogger.shared.error("[Preferences] Failed to encode preferences: \(error)", category: AppLogger.Category.session)
        }
    }

    func resetPreferences() {
        UserDefaults.standard.removeObject(forKey: key)
        AppLogger.shared.info("[Preferences] Reset preferences to defaults", category: AppLogger.Category.session)
    }
}
