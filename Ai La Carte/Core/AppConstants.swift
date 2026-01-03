//
//  AppConstants.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation
import SwiftUI

enum AppConstants {
    enum Storage {
        static let onboardingCompletedKey = "onboarding_completed"
        static let currentUserIdKey = "current_user_id"
        static let deviceIdKey = "device_id"
        static let tasteProfileKey = "taste_profile"

        enum Keychain {
            static let authTokenKey = "auth_token"
            static let deviceIdKey = "device_id"
        }
    }

    enum Validation {
        static let minNameLength = 2
        static let maxNameLength = 50
        static let preferenceMin = 1
        static let preferenceMax = 5

        enum Regex {
            static let email = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
            static let phoneNumber = #"^\+?[1-9]\d{1,14}$"#
        }
    }

    enum UI {
        static let animationDuration: TimeInterval = 0.3
        static let defaultCornerRadius: CGFloat = 16
        static let defaultPadding: CGFloat = 20
        static let cardPadding: CGFloat = 16
        static let buttonHeight: CGFloat = 56
        static let iconSize: CGFloat = 24
        static let largeIconSize: CGFloat = 48
    }

    enum Location {
        static let defaultSearchRadius: Int = 800 // meters
        static let locationTimeout: TimeInterval = 10.0
    }

    enum Camera {
        static let compressionQuality: CGFloat = 0.7
        static let maxImageDimension: CGFloat = 2048
    }

    enum Recommendation {
        static let pollingInterval: TimeInterval = 1.0
        static let maxPollingAttempts = 30
        static let foodRecommendationCount = 5
        static let wineRecommendationCount = 5
    }

    enum Survey {
        static let feedbackDelayHours: Int = 2
    }

    enum Notifications {
        static let dismissToMain = Notification.Name("dismissToMain")
    }
}

// MARK: - Design System Colors

extension Color {
    static let primaryAccent = Color("PrimaryAccent")
    static let secondaryAccent = Color("SecondaryAccent")
    static let backgroundPrimary = Color("BackgroundPrimary")
    static let backgroundSecondary = Color("BackgroundSecondary")
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")

    // Fallback colors if assets not available
    static let appPrimary = Color(red: 0.96, green: 0.62, blue: 0.26)  // Warm orange
    static let appSecondary = Color(red: 0.20, green: 0.20, blue: 0.25) // Dark charcoal
    static let appBackground = Color(red: 0.98, green: 0.97, blue: 0.95) // Warm white
    static let appCardBackground = Color.white
    static let appSuccess = Color(red: 0.30, green: 0.69, blue: 0.31) // Green
    static let appWarning = Color(red: 1.0, green: 0.76, blue: 0.03)  // Amber
    static let appError = Color(red: 0.90, green: 0.30, blue: 0.24)   // Red
}

// MARK: - Design System Fonts

extension Font {
    static let displayLarge = Font.system(size: 32, weight: .bold, design: .rounded)
    static let displayMedium = Font.system(size: 28, weight: .bold, design: .rounded)
    static let titleLarge = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let titleMedium = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let bodyLarge = Font.system(size: 17, weight: .regular)
    static let bodyMedium = Font.system(size: 15, weight: .regular)
    static let labelLarge = Font.system(size: 14, weight: .medium)
    static let labelSmall = Font.system(size: 12, weight: .medium)
    static let caption = Font.system(size: 11, weight: .regular)
}
