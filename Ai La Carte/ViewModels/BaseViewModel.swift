//
//  BaseViewModel.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation

@Observable
class BaseViewModel {
    var isLoading = false
    var error: AppError?

    func handleNetworkError(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        if let networkError = error as? NetworkError {
            return AppError.network(networkError)
        }
        if let cameraError = error as? CameraError {
            return AppError.camera(cameraError)
        }
        if let locationError = error as? LocationError {
            return AppError.location(locationError)
        }
        return AppError.unknown(error)
    }

    @MainActor
    func performNetworkOperation<T>(
        operation: () async throws -> T
    ) async -> T? {
        isLoading = true
        error = nil

        do {
            let result = try await operation()
            isLoading = false
            return result
        } catch {
            self.error = handleNetworkError(error)
            isLoading = false
            return nil
        }
    }

    func clearError() {
        error = nil
    }
}
