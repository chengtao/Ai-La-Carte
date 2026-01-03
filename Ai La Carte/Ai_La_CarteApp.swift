//
//  Ai_La_CarteApp.swift
//  Ai La Carte
//
//  Created by CHENG-TAO CHU on 1/2/26.
//

import SwiftUI
import SwiftData

@main
struct Ai_La_CarteApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            Restaurant.self,
            Session.self,
            PhotoAsset.self,
            RecommendationItem.self,
            TasteProfile.self
        ])

        let isInMemory = ProcessInfo.processInfo.environment["ENV"] == "mock"
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isInMemory)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        // Default to mock for local development
        let env = ProcessInfo.processInfo.environment["ENV"] ?? "mock"

        let dependencyContainer: DependencyContainer = {
            switch env {
            case "production":
                return AppDependencyContainer(modelContext: sharedModelContainer.mainContext)
            case "mock":
                return MockDependencyContainer()
            default:
                return MockDependencyContainer()
            }
        }()

        WindowGroup {
            RootView()
                .environment(\.dependencyContainer, dependencyContainer)
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Root View

struct RootView: View {
    @Environment(\.dependencyContainer) private var dependencyContainer
    @AppStorage(AppConstants.Storage.onboardingCompletedKey) private var onboardingCompleted = false

    var body: some View {
        if onboardingCompleted {
            MainView(viewModel: dependencyContainer.makeMainViewModel())
        } else {
            WelcomeView(viewModel: dependencyContainer.makeWelcomeViewModel())
        }
    }
}
