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

// swiftlint:disable force_unwrapping

extension AuditEntry {

  // MARK: Internal

  /// Mock INSERT entry for previews
  static var mockInsert: AuditEntry {
    AuditEntry(
      id: PreviewID.insertEntry,
      action: .insert,
      changedAt: previewReferenceDate.addingTimeInterval(-3600), // 1 hour before reference
      changedBy: PreviewDataFactory.aliceID,
      entityType: .listing,
      entityId: PreviewID.insertEntityId,
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
      id: PreviewID.updateEntry,
      action: .update,
      changedAt: previewReferenceDate.addingTimeInterval(-1800), // 30 min before reference
      changedBy: PreviewDataFactory.bobID,
      entityType: .listing,
      entityId: PreviewID.updateEntityId,
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
      id: PreviewID.deleteEntry,
      action: .delete,
      changedAt: previewReferenceDate.addingTimeInterval(-86_400), // 1 day before reference
      changedBy: PreviewDataFactory.aliceID,
      entityType: .listing,
      entityId: PreviewID.deleteEntityId,
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
      id: PreviewID.restoreEntry,
      action: .restore,
      changedAt: previewReferenceDate.addingTimeInterval(-300), // 5 min before reference
      changedBy: PreviewDataFactory.bobID,
      entityType: .listing,
      entityId: PreviewID.restoreEntityId,
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
      id: PreviewID.deletedTask,
      action: .delete,
      changedAt: previewReferenceDate.addingTimeInterval(-7200), // 2 hours before reference
      changedBy: PreviewDataFactory.aliceID,
      entityType: .task,
      entityId: PreviewID.deletedTaskEntityId,
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
      id: PreviewID.deletedProperty,
      action: .delete,
      changedAt: previewReferenceDate.addingTimeInterval(-172_800), // 2 days before reference
      changedBy: PreviewDataFactory.bobID,
      entityType: .property,
      entityId: PreviewID.deletedPropertyEntityId,
      summary: "Deleted",
      oldRow: [
        "address": AnyCodable("321 Elm Street"),
        "city": AnyCodable("Toronto")
      ],
      newRow: nil
    )
  }

  /// Mock deleted activity entry for Recently Deleted view
  static var mockDeletedActivity: AuditEntry {
    AuditEntry(
      id: PreviewID.deletedActivity,
      action: .delete,
      changedAt: previewReferenceDate.addingTimeInterval(-3600), // 1 hour before reference
      changedBy: PreviewDataFactory.aliceID,
      entityType: .activity,
      entityId: PreviewID.deletedActivityEntityId,
      summary: "Deleted",
      oldRow: [
        "title": AnyCodable("Client follow-up call")
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

  // MARK: Private

  /// Fixed UUIDs for deterministic preview entries
  private enum PreviewID {
    static let insertEntry = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let updateEntry = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let deleteEntry = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    static let restoreEntry = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    static let deletedTask = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
    static let deletedProperty = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
    static let insertEntityId = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
    static let updateEntityId = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
    static let deleteEntityId = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!
    static let restoreEntityId = UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!
    static let deletedTaskEntityId = UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!
    static let deletedPropertyEntityId = UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!
    static let deletedActivity = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
    static let deletedActivityEntityId = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
  }

  // MARK: - Deterministic Preview Data

  /// Fixed reference date for deterministic previews (Jan 15, 2025 12:00 UTC)
  private static let previewReferenceDate = Date(timeIntervalSinceReferenceDate: 758_980_800)

}

// MARK: - AnyCodable

// swiftlint:enable force_unwrapping

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
