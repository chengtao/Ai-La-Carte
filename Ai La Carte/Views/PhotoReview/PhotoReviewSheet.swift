//
//  PhotoReviewSheet.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import SwiftUI

struct PhotoReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: PhotoReviewViewModel

    let onAccept: (UIImage) -> Void
    let onRetake: () -> Void
    let onRecommend: () -> Void

    @State private var showingActions = true

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                // Photo preview
                Image(uiImage: viewModel.photo)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.defaultCornerRadius))
                    .padding()

                // Action buttons overlay
                VStack {
                    Spacer()

                    if showingActions {
                        actionButtons
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onRetake()
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }

                ToolbarItem(placement: .principal) {
                    Text("Review Photo")
                        .font(.titleMedium)
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Hint text
            Text("Make sure the menu is clearly visible")
                .font(.bodyMedium)
                .foregroundStyle(.white.opacity(0.8))

            // Main actions
            HStack(spacing: 16) {
                // Retake
                Button {
                    onRetake()
                    dismiss()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2)
                        Text("Retake")
                            .font(.labelSmall)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Accept & take more
                Button {
                    onAccept(viewModel.photo)
                    dismiss()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                        Text("Add More")
                            .font(.labelSmall)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Accept & get recommendations
                Button {
                    onAccept(viewModel.photo)
                    onRecommend()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.title2)
                        Text("Recommend")
                            .font(.labelSmall)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LinearGradient.magicPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.horizontal, AppConstants.UI.defaultPadding)
        .padding(.bottom, 40)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Preview

#Preview {
    PhotoReviewSheet(
        viewModel: PhotoReviewViewModel(
            sessionId: "test",
            photo: UIImage(systemName: "photo")!,
            sessionService: MockSessionAPIService()
        ),
        onAccept: { _ in },
        onRetake: {},
        onRecommend: {}
    )
}
