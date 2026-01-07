//
//  UserDTO.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

// MARK: - UserDTO

struct UserDTO: Codable, Identifiable {
  enum CodingKeys: String, CodingKey {
    case id
    case name
    case email
    case avatarPath = "avatar_path"
    case avatarHash = "avatar_hash"
    case userType = "user_type"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }

  let id: UUID
  let name: String
  let email: String
  let avatarPath: String?
  let avatarHash: String?
  let userType: String
  let createdAt: Date
  let updatedAt: Date

  func toModel() -> User {
    User(
      id: id,
      name: name,
      email: email,
      avatarHash: avatarHash,
      userType: UserType(rawValue: userType) ?? .realtor,
      createdAt: createdAt,
      updatedAt: updatedAt,
    )
  }
}

extension UserDTO {
  init(from user: User, avatarPath: String? = nil, avatarHash: String? = nil) {
    id = user.id
    name = user.name
    email = user.email
    self.avatarPath = avatarPath
    self.avatarHash = avatarHash
    userType = user.userType.rawValue
    createdAt = user.createdAt
    updatedAt = user.updatedAt
  }
}
