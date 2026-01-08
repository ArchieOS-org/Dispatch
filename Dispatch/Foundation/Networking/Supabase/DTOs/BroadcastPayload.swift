//
//  BroadcastPayload.swift
//  Dispatch
//
//  Created for broadcast-from-database migration (postgres_changes → broadcast_changes)
//  Handles payloads from realtime.broadcast_changes() triggers with origin_user_id for self-echo filtering.
//

import Foundation

// MARK: - BroadcastTable

/// Tables that broadcast changes (prevents typos from silently dropping events)
enum BroadcastTable: String, Codable, Sendable {
  case tasks
  case activities
  case listings
  case users
  case claimEvents = "claim_events"
}

// MARK: - BroadcastOp

/// Database operations
enum BroadcastOp: String, Codable, Sendable {
  case insert = "INSERT"
  case update = "UPDATE"
  case delete = "DELETE"
}

// MARK: - BroadcastChangePayload

/// Payload structure for broadcast messages from database triggers.
/// The trigger injects `_origin_user_id` and `_event_version` metadata into the record.
struct BroadcastChangePayload: Decodable, Sendable {

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case table
    case type
    case record
    case oldRecord = "old_record"
  }

  let table: BroadcastTable
  let type: BroadcastOp
  let record: [String: AnyCodableValue]?
  let oldRecord: [String: AnyCodableValue]?

  /// User who originated this change (for self-echo filtering).
  /// NOTE: nil means system-originated (migrations, scripts) - do NOT skip these events.
  var originUserId: UUID? {
    guard
      let record = activeRecord,
      let value = record["_origin_user_id"],
      case .string(let str) = value
    else { return nil }
    return UUID(uuidString: str)
  }

  /// Event version for future payload evolution
  var eventVersion: Int {
    guard
      let record = activeRecord,
      let value = record["_event_version"],
      case .int(let version) = value
    else { return 1 }
    return version
  }

  // MARK: Private

  /// Returns record for INSERT/UPDATE, oldRecord for DELETE
  private var activeRecord: [String: AnyCodableValue]? {
    record ?? oldRecord
  }

}

// MARK: - Metadata Stripping Helper

extension BroadcastChangePayload {

  // MARK: Internal

  /// Returns record with metadata keys removed, ready for DTO decoding.
  /// Centralized to avoid copy-pasting per entity handler.
  func cleanedRecord() -> [String: Any]? {
    guard let record else { return nil }
    var cleaned = [String: Any]()
    for (key, value) in record where !Self.metadataKeys.contains(key) {
      cleaned[key] = value.toAny()
    }
    return cleaned
  }

  /// Returns oldRecord with metadata keys removed
  func cleanedOldRecord() -> [String: Any]? {
    guard let oldRecord else { return nil }
    var cleaned = [String: Any]()
    for (key, value) in oldRecord where !Self.metadataKeys.contains(key) {
      cleaned[key] = value.toAny()
    }
    return cleaned
  }

  // MARK: Private

  /// Metadata keys injected by trigger that must be stripped before DTO decoding
  private static let metadataKeys: Set<String> = ["_origin_user_id", "_event_version"]

}

// MARK: - AnyCodableValue

/// Type-safe wrapper for JSON values that can be decoded from broadcast payloads.
/// Replaces generic AnyCodable with explicit type handling for safety.
enum AnyCodableValue: Decodable, Sendable {
  case string(String)
  case int(Int)
  case double(Double)
  case bool(Bool)
  case null
  case array([AnyCodableValue])
  case dictionary([String: AnyCodableValue])

  // MARK: Lifecycle

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    if container.decodeNil() {
      self = .null
      return
    }

    // Try types in order of specificity
    if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Int.self) {
      self = .int(value)
    } else if let value = try? container.decode(Double.self) {
      self = .double(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([AnyCodableValue].self) {
      self = .array(value)
    } else if let value = try? container.decode([String: AnyCodableValue].self) {
      self = .dictionary(value)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "AnyCodableValue cannot decode value",
      )
    }
  }

  // MARK: Internal

  /// Converts to Any for JSONSerialization compatibility
  func toAny() -> Any {
    switch self {
    case .string(let value): value
    case .int(let value): value
    case .double(let value): value
    case .bool(let value): value
    case .null: NSNull()
    case .array(let value): value.map { $0.toAny() }
    case .dictionary(let value): value.mapValues { $0.toAny() }
    }
  }
}
