//
//  DeviceIdentifierService.swift
//  AILaCarte
//
//  Created by Claude on 1/4/26.
//

import Foundation

/// Protocol for device identifier management
/// Abstracts device ID retrieval for better testability
protocol DeviceIdentifierServiceProtocol: Sendable {
    /// Returns the unique device identifier, creating one if necessary
    func getDeviceId() -> String
}

/// Production implementation using KeychainHelper
final class DeviceIdentifierService: DeviceIdentifierServiceProtocol, Sendable {
    func getDeviceId() -> String {
        KeychainHelper.getOrCreateDeviceId()
    }
}

/// Mock implementation for testing
final class MockDeviceIdentifierService: DeviceIdentifierServiceProtocol, Sendable {
    private let mockDeviceId: String

    init(deviceId: String = "mock-device-id-12345") {
        self.mockDeviceId = deviceId
    }

    func getDeviceId() -> String {
        mockDeviceId
    }
}
