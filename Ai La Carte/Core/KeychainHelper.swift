//
//  KeychainHelper.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation
import Security

class KeychainHelper {
    static func save(key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func save(key: String, string: String) {
        guard let data = string.data(using: .utf8) else { return }
        save(key: key, data: data)
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == noErr, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    static func loadData(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == noErr, let data = dataTypeRef as? Data {
            return data
        }
        return nil
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }

    static func exists(key: String) -> Bool {
        return load(key: key) != nil
    }
}

// MARK: - Device ID Management

extension KeychainHelper {
    static func getOrCreateDeviceId() -> String {
        if let existingId = load(key: AppConstants.Storage.Keychain.deviceIdKey) {
            return existingId
        }

        let newId = UUID().uuidString
        save(key: AppConstants.Storage.Keychain.deviceIdKey, string: newId)
        return newId
    }
}
