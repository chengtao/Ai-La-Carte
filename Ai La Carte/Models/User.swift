//
//  User.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation
import SwiftData

@Model
final class User {
    @Attribute(.unique) var id: UUID
    var name: String
    var email: String?
    var phoneNumber: String?
    var deviceId: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade) var tasteProfile: TasteProfile?
    @Relationship(deleteRule: .cascade, inverse: \Session.user) var sessions: [Session] = []

    init(
        id: UUID = UUID(),
        name: String = "",
        email: String? = nil,
        phoneNumber: String? = nil,
        deviceId: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.phoneNumber = phoneNumber
        self.deviceId = deviceId
        self.createdAt = createdAt
    }
}

// MARK: - User Response DTO

struct UserResponse: Codable {
    let id: String
    let name: String?
    let email: String?
    let phoneNumber: String?
    let deviceId: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case phoneNumber = "phone_number"
        case deviceId = "device_id"
        case createdAt = "created_at"
    }
}
