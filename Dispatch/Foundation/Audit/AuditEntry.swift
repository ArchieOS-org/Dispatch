//
//  AuditEntry.swift
//  Dispatch
//
//  Plain struct (NOT @Model per Fix 2D) representing an audit log entry.
//  Fetched via RPC and not persisted locally.
//

import Foundation

// MARK: - AuditEntry

struct AuditEntry: Identifiable, Sendable {

  // MARK: Lifecycle

  init(
    id: UUID,
    action: AuditAction,
    changedAt: Date,
    changedBy: UUID?,
    entityType: AuditableEntity,
    entityId: UUID,
    summary: String,
    oldRow: [String: AnyCodable]? = nil,
    newRow: [String: AnyCodable]? = nil
  ) {
    self.id = id
    self.action = action
    self.changedAt = changedAt
    self.changedBy = changedBy
    self.entityType = entityType
    self.entityId = entityId
    self.summary = summary
    self.oldRow = oldRow
    self.newRow = newRow
  }

  // MARK: Internal

  let id: UUID
  let action: AuditAction
  let changedAt: Date
  let changedBy: UUID?
  let entityType: AuditableEntity
  let entityId: UUID
  let summary: String

  /// Row data for summary building and diff display
  var oldRow: [String: AnyCodable]?
  var newRow: [String: AnyCodable]?
}

// MARK: - AuditEntry + displayTitle

extension AuditEntry {
  /// Display title extracted from row data for showing in lists
  var displayTitle: String {
    let row = newRow ?? oldRow
    switch entityType {
    case .listing:
      if let address = row?["address"]?.value as? String, !address.isEmpty { return address }
      return "Listing"

    case .task:
      if let title = row?["title"]?.value as? String, !title.isEmpty { return title }
      return "Task"

    case .property:
      if let address = row?["address"]?.value as? String, !address.isEmpty { return address }
      return "Property"

    case .activity:
      if let activityType = row?["activity_type"]?.value as? String, !activityType.isEmpty {
        return activityType
      }
      return "Activity"

    case .user:
      if let name = row?["name"]?.value as? String, !name.isEmpty { return name }
      return "Realtor"

    case .taskAssignee:
      return "Assignment"

    case .activityAssignee:
      return "Assignment"

    case .note:
      // Show truncated note content if available
      if let content = row?["content"]?.value as? String, !content.isEmpty {
        let truncated = content.prefix(30)
        return truncated.count < content.count ? "\(truncated)..." : String(truncated)
      }
      return "Note"
    }
  }
}

// MARK: - AnyCodable

// MARK: - AuditEntry + Preview Mocks

extension AuditEntry {

  /// Mock INSERT entry for previews
  static var mockInsert: AuditEntry {
    AuditEntry(
      id: UUID(),
      action: .insert,
      changedAt: Date().addingTimeInterval(-3600), // 1 hour ago
      changedBy: PreviewDataFactory.aliceID,
      entityType: .listing,
      entityId: UUID(),
      summary: "Created",
      oldRow: nil,
      newRow: [
        "address": AnyCodable("123 Main St"),
        "price": AnyCodable(500_000),
        "stage": AnyCodable("active")
      ]
    )
  }

  /// Mock UPDATE entry for previews
  static var mockUpdate: AuditEntry {
    AuditEntry(
      id: UUID(),
      action: .update,
      changedAt: Date().addingTimeInterval(-1800), // 30 min ago
      changedBy: PreviewDataFactory.bobID,
      entityType: .listing,
      entityId: UUID(),
      summary: "Updated",
      oldRow: [
        "price": AnyCodable(500_000),
        "stage": AnyCodable("active")
      ],
      newRow: [
        "price": AnyCodable(475_000),
        "stage": AnyCodable("pending")
      ]
    )
  }

  /// Mock DELETE entry for previews
  static var mockDelete: AuditEntry {
    AuditEntry(
      id: UUID(),
      action: .delete,
      changedAt: Date().addingTimeInterval(-86_400), // 1 day ago
      changedBy: PreviewDataFactory.aliceID,
      entityType: .listing,
      entityId: UUID(),
      summary: "Deleted",
      oldRow: [
        "address": AnyCodable("456 Oak Ave"),
        "price": AnyCodable(350_000)
      ],
      newRow: nil
    )
  }

  /// Mock RESTORE entry for previews
  static var mockRestore: AuditEntry {
    AuditEntry(
      id: UUID(),
      action: .restore,
      changedAt: Date().addingTimeInterval(-300), // 5 min ago
      changedBy: PreviewDataFactory.bobID,
      entityType: .listing,
      entityId: UUID(),
      summary: "Restored",
      oldRow: nil,
      newRow: [
        "address": AnyCodable("789 Pine Rd"),
        "price": AnyCodable(425_000)
      ]
    )
  }

  /// Mock deleted task entry for Recently Deleted view
  static var mockDeletedTask: AuditEntry {
    AuditEntry(
      id: UUID(),
      action: .delete,
      changedAt: Date().addingTimeInterval(-7200), // 2 hours ago
      changedBy: PreviewDataFactory.aliceID,
      entityType: .task,
      entityId: UUID(),
      summary: "Deleted",
      oldRow: [
        "title": AnyCodable("Update lockbox code"),
        "status": AnyCodable("open")
      ],
      newRow: nil
    )
  }

  /// Mock deleted property entry for Recently Deleted view
  static var mockDeletedProperty: AuditEntry {
    AuditEntry(
      id: UUID(),
      action: .delete,
      changedAt: Date().addingTimeInterval(-172_800), // 2 days ago
      changedBy: PreviewDataFactory.bobID,
      entityType: .property,
      entityId: UUID(),
      summary: "Deleted",
      oldRow: [
        "address": AnyCodable("321 Elm Street"),
        "city": AnyCodable("Toronto")
      ],
      newRow: nil
    )
  }

  /// Sample history entries for preview lists
  static var sampleHistory: [AuditEntry] {
    [mockInsert, mockUpdate, mockDelete, mockRestore]
  }

  /// Sample deleted entries for Recently Deleted view
  static var sampleDeleted: [AuditEntry] {
    [mockDelete, mockDeletedTask, mockDeletedProperty]
  }

}

// MARK: - AnyCodable

/// Type-erased wrapper for JSON values from RPC responses.
struct AnyCodable: Codable, Sendable {

  // MARK: Lifecycle

  init(_ value: Any?) {
    self.value = value ?? NSNull()
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    if container.decodeNil() {
      value = NSNull()
    } else if let bool = try? container.decode(Bool.self) {
      value = bool
    } else if let int = try? container.decode(Int.self) {
      value = int
    } else if let double = try? container.decode(Double.self) {
      value = double
    } else if let string = try? container.decode(String.self) {
      value = string
    } else if let array = try? container.decode([AnyCodable].self) {
      value = array.map { $0.value }
    } else if let dictionary = try? container.decode([String: AnyCodable].self) {
      value = dictionary.mapValues { $0.value }
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "AnyCodable cannot decode value"
      )
    }
  }

  // MARK: Internal

  let value: Any

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    switch value {
    case is NSNull:
      try container.encodeNil()
    case let bool as Bool:
      try container.encode(bool)
    case let int as Int:
      try container.encode(int)
    case let double as Double:
      try container.encode(double)
    case let string as String:
      try container.encode(string)
    case let array as [Any]:
      try container.encode(array.map { AnyCodable($0) })
    case let dictionary as [String: Any]:
      try container.encode(dictionary.mapValues { AnyCodable($0) })
    default:
      let context = EncodingError.Context(
        codingPath: container.codingPath,
        debugDescription: "AnyCodable cannot encode value"
      )
      throw EncodingError.invalidValue(value, context)
    }
  }
}
