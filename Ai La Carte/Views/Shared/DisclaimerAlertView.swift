//
//  DisclaimerAlertView.swift
//  AILaCarte
//
//  Created by Claude on 1/14/26.
//

import SwiftUI

struct DisclaimerAlertView: View {
    @Binding var isPresented: Bool
    let onDontShowAgain: () -> Void

    @State private var dontShowAgain = false

    var body: some View {
        ZStack {
            // Semi-transparent backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissAlert()
                }

            // Alert card
            VStack(spacing: 20) {
                // Icon
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.magicPurple, .magicPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Title
                Text("Important Notice")
                    .font(.titleLarge)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                // Message
                Text("Dish photos are for illustrative purposes only and are not from the restaurant.")
                    .font(.bodyMedium)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                // Don't show again checkbox
                Toggle(isOn: $dontShowAgain) {
                    Text("Don't show this again")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .toggleStyle(.checkbox)
                .padding(.horizontal)

                // Got it button
                Button {
                    dismissAlert()
                } label: {
                    Text("Got it")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LinearGradient.magicPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(24)
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            .frame(maxWidth: 340)
            .padding(.horizontal, 32)
        }
    }

    private func dismissAlert() {
        if dontShowAgain {
            onDontShowAgain()
        }
        withAnimation(.easeOut(duration: 0.2)) {
            isPresented = false
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var isPresented = true

        var body: some View {
            ZStack {
                Color.gray.opacity(0.2)
                    .ignoresSafeArea()

                if isPresented {
                    DisclaimerAlertView(
                        isPresented: $isPresented,
                        onDontShowAgain: {
                            print("Don't show again selected")
                        }
                    )
                }
            }
        }
    }

    return PreviewWrapper()
}
