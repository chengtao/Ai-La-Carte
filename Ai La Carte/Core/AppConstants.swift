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

    // MARK: - Magical AI Color Palette

    // Primary gradient colors - vibrant purple to pink to coral
    static let magicPurple = Color(red: 0.56, green: 0.27, blue: 0.92)     // #8F45EB - Deep violet
    static let magicPink = Color(red: 0.91, green: 0.35, blue: 0.60)       // #E85999 - Vibrant pink
    static let magicCoral = Color(red: 1.0, green: 0.45, blue: 0.40)       // #FF7366 - Warm coral
    static let magicBlue = Color(red: 0.40, green: 0.53, blue: 0.98)       // #6687FA - Electric blue
    static let magicTeal = Color(red: 0.29, green: 0.82, blue: 0.80)       // #4AD1CC - Aqua teal

    // App colors using the magical palette - THEME ADAPTIVE
    static let appPrimary = magicPurple
    static let appSecondary = Color(
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.90, green: 0.88, blue: 0.95, alpha: 1.0)  // Light purple-gray for dark mode
                : UIColor(red: 0.15, green: 0.12, blue: 0.22, alpha: 1.0)  // Dark purple-charcoal for light mode
        }
    )

    // Background colors - adaptive for light/dark mode
    static let appBackground = Color(
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.08, green: 0.06, blue: 0.12, alpha: 1.0)  // Dark purple-black
                : UIColor(red: 0.99, green: 0.98, blue: 1.0, alpha: 1.0)   // Soft lavender white
        }
    )

    static let appCardBackground = Color(
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.14, green: 0.12, blue: 0.18, alpha: 1.0)  // Dark card
                : UIColor.white
        }
    )

    // Status colors
    static let appSuccess = Color(red: 0.20, green: 0.78, blue: 0.60)      // Teal green
    static let appWarning = Color(red: 1.0, green: 0.72, blue: 0.30)       // Golden amber
    static let appError = Color(red: 0.95, green: 0.35, blue: 0.45)        // Soft red-pink

    // Accent colors for highlights and interactions
    static let shimmerLight = Color.white.opacity(0.8)
    static let shimmerDark = Color.white.opacity(0.3)
    static let glowPurple = magicPurple.opacity(0.4)
    static let glowPink = magicPink.opacity(0.4)
}

// MARK: - Magical Gradients

extension LinearGradient {
    /// Primary magical gradient - purple to pink to coral
    static let magicPrimary = LinearGradient(
        colors: [Color.magicPurple, Color.magicPink, Color.magicCoral],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Cool magical gradient - purple to blue
    static let magicCool = LinearGradient(
        colors: [Color.magicPurple, Color.magicBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Warm magical gradient - pink to coral
    static let magicWarm = LinearGradient(
        colors: [Color.magicPink, Color.magicCoral],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Background gradient - subtle lavender
    static let magicBackground = LinearGradient(
        colors: [
            Color.magicPurple.opacity(0.08),
            Color.magicPink.opacity(0.05),
            Color.appBackground
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Shimmer effect gradient
    static let shimmer = LinearGradient(
        colors: [
            Color.shimmerDark,
            Color.shimmerLight,
            Color.shimmerDark
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
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

// MARK: - Magical Button Styles

struct MagicButtonStyle: ButtonStyle {
    var isLoading: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: AppConstants.UI.buttonHeight)
            .background(
                ZStack {
                    // Glow effect behind
                    RoundedRectangle(cornerRadius: AppConstants.UI.defaultCornerRadius)
                        .fill(LinearGradient.magicPrimary)
                        .blur(radius: 8)
                        .opacity(configuration.isPressed ? 0.6 : 0.4)
                        .offset(y: 4)

                    // Main gradient background
                    RoundedRectangle(cornerRadius: AppConstants.UI.defaultCornerRadius)
                        .fill(LinearGradient.magicPrimary)
                }
            )
            .foregroundStyle(.white)
            .font(.titleMedium)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct MagicSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: AppConstants.UI.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: AppConstants.UI.defaultCornerRadius)
                    .stroke(LinearGradient.magicPrimary, lineWidth: 2)
            )
            .foregroundStyle(Color.magicPurple)
            .font(.titleMedium)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Magical View Components

/// A view that displays an animated magical glow orb
struct MagicOrbView: View {
    let size: CGFloat
    @State private var animate = false

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.magicPurple.opacity(0.4), Color.clear],
                        center: .center,
                        startRadius: size * 0.2,
                        endRadius: size * 0.6
                    )
                )
                .frame(width: size * 1.4, height: size * 1.4)
                .scaleEffect(animate ? 1.2 : 1.0)

            // Inner gradient circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.magicPink, Color.magicPurple],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size, height: size)

            // Shimmer highlight
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.5), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.4, height: size * 0.4)
                .offset(x: -size * 0.15, y: -size * 0.15)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

/// A card with magical glow effect
struct MagicCardModifier: ViewModifier {
    var glowColor: Color = .magicPurple

    func body(content: Content) -> some View {
        content
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.defaultCornerRadius))
            .shadow(color: glowColor.opacity(0.15), radius: 12, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.UI.defaultCornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [glowColor.opacity(0.3), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    func magicCard(glowColor: Color = .magicPurple) -> some View {
        modifier(MagicCardModifier(glowColor: glowColor))
    }
}

/// Floating particles background effect
struct MagicParticlesView: View {
    let particleCount: Int
    @State private var particles: [Particle] = []

    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        let size: CGFloat
        let color: Color
        let duration: Double
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .blur(radius: particle.size * 0.3)
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onAppear {
                generateParticles(in: geometry.size)
            }
        }
    }

    private func generateParticles(in size: CGSize) {
        let colors: [Color] = [.magicPurple, .magicPink, .magicBlue, .magicCoral]
        particles = (0..<particleCount).map { _ in
            Particle(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                size: CGFloat.random(in: 4...12),
                color: colors.randomElement()!.opacity(Double.random(in: 0.1...0.3)),
                duration: Double.random(in: 3...6)
            )
        }

        // Animate particles floating
        for index in particles.indices {
            animateParticle(at: index, in: size)
        }
    }

    private func animateParticle(at index: Int, in size: CGSize) {
        guard index < particles.count else { return }
        let particle = particles[index]

        withAnimation(
            .easeInOut(duration: particle.duration)
            .repeatForever(autoreverses: true)
        ) {
            particles[index].y = CGFloat.random(in: 0...size.height)
            particles[index].x = CGFloat.random(in: 0...size.width)
        }
    }
}

/// Shimmer overlay effect for loading states
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.4),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: phase * geometry.size.width * 2 - geometry.size.width)
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
