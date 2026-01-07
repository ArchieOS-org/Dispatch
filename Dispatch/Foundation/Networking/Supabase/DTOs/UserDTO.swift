//
//  UserDTO.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

struct UserDTO: Codable, Identifiable {
    let id: UUID
    let name: String
    let email: String
    let avatarPath: String?
    let avatarHash: String?
    let userType: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, email
        case avatarPath = "avatar_path"
        case avatarHash = "avatar_hash"
        case userType = "user_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    func toModel() -> User {
        return User(
            id: id,
            name: name,
            email: email,
            avatarHash: avatarHash,
            userType: UserType(rawValue: userType) ?? .realtor,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension UserDTO {
    init(from user: User, avatarPath: String? = nil, avatarHash: String? = nil) {
        self.id = user.id
        self.name = user.name
        self.email = user.email
        self.avatarPath = avatarPath
        self.avatarHash = avatarHash
        self.userType = user.userType.rawValue
        self.createdAt = user.createdAt
        self.updatedAt = user.updatedAt
    }
}
