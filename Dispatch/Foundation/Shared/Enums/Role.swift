//
//  Role.swift
//  Dispatch
//
//  Represents user roles for audience targeting
//

import Foundation

// MARK: - Role

/// Represents a user role for audience-based filtering
enum Role: String, Codable, CaseIterable, Hashable {
  case admin
  case marketing
}

// MARK: - Audience Normalization

/// Normalizes audience arrays to enforce mutual exclusivity.
/// Tasks and activities should only belong to ONE audience type.
///
/// Priority order: admin > marketing > default to admin
///
/// Examples:
/// - `["admin", "marketing"]` -> `["admin"]` (admin takes priority)
/// - `["marketing"]` -> `["marketing"]` (unchanged)
/// - `["admin"]` -> `["admin"]` (unchanged)
/// - `[]` or `nil` -> `["admin"]` (default)
///
/// - Parameter audiences: Optional array of audience strings from DTO or model
/// - Returns: Array containing exactly one valid audience string
func normalizeAudiences(_ audiences: [String]?) -> [String] {
  guard let audiences, !audiences.isEmpty else {
    return ["admin"]
  }
  if audiences.contains("admin") {
    return ["admin"]
  }
  if audiences.contains("marketing") {
    return ["marketing"]
  }
  // Unknown audience values - default to admin
  return ["admin"]
}

/// Normalizes audiences for ActivityTemplates, allowing empty arrays.
/// Templates may intentionally have no audience set (inherits from context).
///
/// - Parameter audiences: Array of audience strings from DTO
/// - Returns: Normalized array - empty if input was empty, otherwise single audience
func normalizeTemplateAudiences(_ audiences: [String]) -> [String] {
  if audiences.isEmpty {
    return []
  }
  if audiences.contains("admin") {
    return ["admin"]
  }
  if audiences.contains("marketing") {
    return ["marketing"]
  }
  // Unknown audience values - default to admin
  return ["admin"]
}
