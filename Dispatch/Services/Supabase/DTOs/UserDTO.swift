//
//  UserDTO.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

struct UserDTO: Codable, Sendable {
    let id: UUID
    let name: String
    let email: String
    let avatarUrl: String?
    let userType: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, email
        case avatarUrl = "avatar_url"
        case userType = "user_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func toModel() -> User {
        let resolvedUserType: UserType
        if let type = UserType(rawValue: userType) {
            resolvedUserType = type
        } else {
            debugLog.log("⚠️ Invalid userType '\(userType)' for User \(id), defaulting to .realtor", category: .sync)
            resolvedUserType = .realtor
        }

        return User(
            id: id,
            name: name,
            email: email,
            avatar: nil, // Avatar loaded separately
            userType: resolvedUserType,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
