//
//  Role.swift
//  Dispatch
//
//  Represents user roles for audience targeting
//

import Foundation

/// Represents a user role for audience-based filtering
enum Role: String, Codable, CaseIterable, Hashable {
  case admin
  case marketing
}
