//
//  AppError.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation

enum AppError: LocalizedError, @unchecked Sendable {
    // Note: @unchecked because of unknown(Error) case - Error is not Sendable
    case network(NetworkError)
    case authentication(AuthError)
    case validation(ValidationError)
    case storage(StorageError)
    case camera(CameraError)
    case location(LocationError)
    case invalidURL
    case notFound(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .network(let networkError):
            return networkError.errorDescription
        case .authentication(let authError):
            return authError.errorDescription
        case .validation(let validationError):
            return validationError.errorDescription
        case .storage(let storageError):
            return storageError.errorDescription
        case .camera(let cameraError):
            return cameraError.errorDescription
        case .location(let locationError):
            return locationError.errorDescription
        case .invalidURL:
            return "Invalid URL"
        case .notFound(let message):
            return message
        case .unknown(let error):
            return error.localizedDescription
        }
    }

    var recoveryMessage: String {
        switch self {
        case .network:
            return "Please check your internet connection and try again."
        case .authentication:
            return "Please sign in again."
        case .validation:
            return "Please check your input and try again."
        case .storage:
            return "There was a problem saving your data. Please try again."
        case .camera:
            return "Please check your camera permissions and try again."
        case .location:
            return "Please check your location permissions and try again."
        case .invalidURL:
            return "There was a problem with the request. Please try again."
        case .notFound:
            return "The requested item was not found."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}

enum ValidationError: LocalizedError, Sendable {
    case invalidEmail
    case invalidPhoneNumber
    case fieldRequired(String)
    case fieldTooShort(String, minimum: Int)
    case fieldTooLong(String, maximum: Int)
    case invalidPreferenceValue

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address"
        case .invalidPhoneNumber:
            return "Please enter a valid phone number"
        case .fieldRequired(let field):
            return "\(field) is required"
        case .fieldTooShort(let field, let minimum):
            return "\(field) must be at least \(minimum) characters"
        case .fieldTooLong(let field, let maximum):
            return "\(field) must be no more than \(maximum) characters"
        case .invalidPreferenceValue:
            return "Please select a valid preference value"
        }
    }
}

enum StorageError: LocalizedError, Sendable {
    case saveFailed
    case loadFailed
    case deleteFailed
    case migrationFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Failed to save data"
        case .loadFailed:
            return "Failed to load data"
        case .deleteFailed:
            return "Failed to delete data"
        case .migrationFailed:
            return "Failed to migrate data"
        }
    }
}

enum AuthError: Error, LocalizedError, Sendable {
    case notAuthenticated
    case userNotFound
    case networkError
    case tokenExpired
    case appleSignInFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You are not signed in"
        case .userNotFound:
            return "User not found"
        case .networkError:
            return "Network connection error"
        case .tokenExpired:
            return "Your session has expired"
        case .appleSignInFailed:
            return "Sign in with Apple failed"
        }
    }
}

enum CameraError: Error, LocalizedError, Sendable {
    case accessDenied
    case notAvailable
    case captureSessionFailed
    case captureFailed
    case compressionFailed

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Camera access denied"
        case .notAvailable:
            return "Camera is not available"
        case .captureSessionFailed:
            return "Failed to start camera session"
        case .captureFailed:
            return "Failed to capture photo"
        case .compressionFailed:
            return "Failed to compress photo"
        }
    }
}

enum LocationError: Error, LocalizedError, Sendable {
    case accessDenied
    case notAvailable
    case locationNotFound
    case timeout

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Location access denied"
        case .notAvailable:
            return "Location services are not available"
        case .locationNotFound:
            return "Unable to determine your location"
        case .timeout:
            return "Location request timed out"
        }
    }
}
