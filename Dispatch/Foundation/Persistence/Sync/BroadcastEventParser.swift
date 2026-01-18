//
//  BroadcastEventParser.swift
//  Dispatch
//
//  Extracted from RealtimeManager - handles broadcast event parsing and DTO routing.
//  Part of PATCHSET 1 for RealtimeManager refactor.
//

import Foundation
import PostgREST
import Supabase

// MARK: - BroadcastEventParserDelegate

/// Delegate protocol for BroadcastEventParser to deliver parsed DTOs.
/// RealtimeManager implements this to route DTOs to its own delegate.
@MainActor
protocol BroadcastEventParserDelegate: AnyObject {
  /// Current user ID for self-echo filtering
  var currentUserID: UUID? { get }

  /// Check if an entity is in-flight (being synced up) to skip self-echoes
  func isInFlightTaskId(_ id: UUID) -> Bool
  func isInFlightActivityId(_ id: UUID) -> Bool
  func isInFlightNoteId(_ id: UUID) -> Bool

  /// DTO delivery callbacks
  func parser(_ parser: BroadcastEventParser, didReceiveTaskDTO dto: TaskDTO)
  func parser(_ parser: BroadcastEventParser, didReceiveActivityDTO dto: ActivityDTO)
  func parser(_ parser: BroadcastEventParser, didReceiveListingDTO dto: ListingDTO)
  func parser(_ parser: BroadcastEventParser, didReceiveUserDTO dto: UserDTO)
  func parser(_ parser: BroadcastEventParser, didReceiveNoteDTO dto: NoteDTO)
  func parser(_ parser: BroadcastEventParser, didReceiveDeleteFor table: BroadcastTable, id: UUID)
}

// MARK: - BroadcastEventParser

/// Parses broadcast events and routes them to DTOs.
/// Handles self-echo filtering and in-flight entity checks.
@MainActor
final class BroadcastEventParser {

  // MARK: Lifecycle

  init() {
    debugLog.log("BroadcastEventParser initialized", category: .realtime)
  }

  // MARK: Internal

  weak var delegate: BroadcastEventParserDelegate?

  #if DEBUG
  /// Track recently processed IDs to detect duplicate processing (DEBUG only)
  private(set) var recentlyProcessedIds = Set<UUID>()
  #endif

  /// Handles broadcast events - parses payload and routes to delegate
  func handleBroadcastEvent(_ event: JSONObject) async {
    do {
      // JSONObject is [String: AnyJSON] - use JSONEncoder for AnyJSON (Codable)
      // Defined outside DEBUG block since it's also used for payload encoding below
      let encoder = JSONEncoder()

      #if DEBUG
      // Log raw payload for debugging (DEBUG only to avoid PII exposure in release)
      debugLog.log("", category: .event)
      debugLog.log("RAW BROADCAST EVENT RECEIVED", category: .event)

      encoder.outputFormatting = .prettyPrinted
      if
        let jsonData = try? encoder.encode(event),
        let jsonString = String(data: jsonData, encoding: .utf8)
      {
        debugLog.log("Raw payload:\n\(jsonString)", category: .event)
      } else {
        debugLog.log("Raw payload (keys): \(event.keys.joined(separator: ", "))", category: .event)
      }
      #endif

      // Supabase Realtime wraps our payload in: { event, type, payload, meta }
      // Our BroadcastChangePayload is inside the "payload" field
      guard let innerPayload = event["payload"]?.objectValue else {
        debugLog.log(
          "Missing or invalid 'payload' field in broadcast event - keys: \(event.keys.joined(separator: ", "))",
          category: .event
        )
        return
      }

      // Use PostgrestClient's decoder for consistency with other DTO decoding
      guard
        let payloadData = try? encoder.encode(innerPayload),
        let payload = try? PostgrestClient.Configuration.jsonDecoder.decode(
          BroadcastChangePayload.self,
          from: payloadData
        )
      else {
        debugLog.log(
          "Failed to decode broadcast payload - inner keys: \(innerPayload.keys.joined(separator: ", "))",
          category: .event
        )
        return
      }

      // Version check: log unknown versions for visibility when we bump the version
      if payload.eventVersion != 1 {
        debugLog.log("Unknown event version \(payload.eventVersion) for table \(payload.table)", category: .event)
      }

      // Self-echo filtering: skip if originated from current user
      // NOTE: nil originUserId means system-originated - do NOT skip those
      if
        let originUserId = payload.originUserId,
        let currentUser = delegate?.currentUserID,
        originUserId == currentUser
      {
        debugLog.log("Skipping self-originated broadcast: \(payload.table) \(payload.type)", category: .event)
        return
      }

      debugLog.log("", category: .event)
      debugLog.log("BROADCAST EVENT: \(payload.table) \(payload.type)", category: .event)

      // Route to appropriate handler based on table (type-safe enum switch)
      switch payload.table {
      case .tasks:
        try handleTaskBroadcast(payload: payload)
      case .activities:
        try handleActivityBroadcast(payload: payload)
      case .listings:
        try handleListingBroadcast(payload: payload)
      case .users:
        try handleUserBroadcast(payload: payload)
      case .notes:
        try handleNoteBroadcast(payload: payload)
      }

    } catch {
      debugLog.error("Failed to handle broadcast event", error: error)
    }
  }

  // MARK: Private

  /// Handles task broadcast - converts payload to TaskDTO and notifies delegate
  private func handleTaskBroadcast(payload: BroadcastChangePayload) throws {
    if payload.type == .delete {
      if
        let oldRecord = payload.cleanedOldRecord(),
        let idString = oldRecord["id"] as? String,
        let id = UUID(uuidString: idString)
      {
        delegate?.parser(self, didReceiveDeleteFor: .tasks, id: id)
        debugLog.log("  Broadcast: Deleted task \(id)", category: .event)
      }
    } else {
      guard let cleanRecord = payload.cleanedRecord() else { return }

      let recordData = try JSONSerialization.data(withJSONObject: cleanRecord)
      let dto = try PostgrestClient.Configuration.jsonDecoder.decode(TaskDTO.self, from: recordData)

      // Use in-flight check as backup (will be removed in Phase 3)
      if delegate?.isInFlightTaskId(dto.id) == true {
        debugLog.log("  Broadcast: Skipping in-flight task \(dto.id)", category: .event)
        return
      }

      #if DEBUG
      trackDuplicateProcessing(id: dto.id, entityType: "task")
      #endif

      delegate?.parser(self, didReceiveTaskDTO: dto)
      debugLog.log("  Broadcast: Upserted task \(dto.id)", category: .event)
    }
  }

  /// Handles activity broadcast - converts payload to ActivityDTO and notifies delegate
  private func handleActivityBroadcast(payload: BroadcastChangePayload) throws {
    if payload.type == .delete {
      if
        let oldRecord = payload.cleanedOldRecord(),
        let idString = oldRecord["id"] as? String,
        let id = UUID(uuidString: idString)
      {
        delegate?.parser(self, didReceiveDeleteFor: .activities, id: id)
        debugLog.log("  Broadcast: Deleted activity \(id)", category: .event)
      }
    } else {
      guard let cleanRecord = payload.cleanedRecord() else { return }

      let recordData = try JSONSerialization.data(withJSONObject: cleanRecord)
      let dto = try PostgrestClient.Configuration.jsonDecoder.decode(ActivityDTO.self, from: recordData)

      if delegate?.isInFlightActivityId(dto.id) == true {
        debugLog.log("  Broadcast: Skipping in-flight activity \(dto.id)", category: .event)
        return
      }

      #if DEBUG
      trackDuplicateProcessing(id: dto.id, entityType: "activity")
      #endif

      delegate?.parser(self, didReceiveActivityDTO: dto)
      debugLog.log("  Broadcast: Upserted activity \(dto.id)", category: .event)
    }
  }

  /// Handles listing broadcast - converts payload to ListingDTO and notifies delegate
  private func handleListingBroadcast(payload: BroadcastChangePayload) throws {
    if payload.type == .delete {
      if
        let oldRecord = payload.cleanedOldRecord(),
        let idString = oldRecord["id"] as? String,
        let id = UUID(uuidString: idString)
      {
        delegate?.parser(self, didReceiveDeleteFor: .listings, id: id)
        debugLog.log("  Broadcast: Deleted listing \(id)", category: .event)
      }
    } else {
      guard let cleanRecord = payload.cleanedRecord() else { return }

      let recordData = try JSONSerialization.data(withJSONObject: cleanRecord)
      let dto = try PostgrestClient.Configuration.jsonDecoder.decode(ListingDTO.self, from: recordData)

      #if DEBUG
      trackDuplicateProcessing(id: dto.id, entityType: "listing")
      #endif

      delegate?.parser(self, didReceiveListingDTO: dto)
      debugLog.log("  Broadcast: Upserted listing \(dto.id)", category: .event)
    }
  }

  /// Handles user broadcast - converts payload to UserDTO and notifies delegate
  private func handleUserBroadcast(payload: BroadcastChangePayload) throws {
    if payload.type == .delete {
      if
        let oldRecord = payload.cleanedOldRecord(),
        let idString = oldRecord["id"] as? String,
        let id = UUID(uuidString: idString)
      {
        delegate?.parser(self, didReceiveDeleteFor: .users, id: id)
        debugLog.log("  Broadcast: Deleted user \(id)", category: .event)
      }
    } else {
      guard let cleanRecord = payload.cleanedRecord() else { return }

      let recordData = try JSONSerialization.data(withJSONObject: cleanRecord)
      let dto = try PostgrestClient.Configuration.jsonDecoder.decode(UserDTO.self, from: recordData)

      #if DEBUG
      trackDuplicateProcessing(id: dto.id, entityType: "user")
      #endif

      delegate?.parser(self, didReceiveUserDTO: dto)
      debugLog.log("  Broadcast: Upserted user \(dto.id)", category: .event)
    }
  }

  /// Handles note broadcast - converts payload to NoteDTO and notifies delegate
  private func handleNoteBroadcast(payload: BroadcastChangePayload) throws {
    if payload.type == .delete {
      // Hard delete on server = notify delegate to hard delete locally
      if
        let oldRecord = payload.cleanedOldRecord(),
        let idString = oldRecord["id"] as? String,
        let id = UUID(uuidString: idString)
      {
        delegate?.parser(self, didReceiveDeleteFor: .notes, id: id)
        debugLog.log("  Broadcast: Hard deleted note \(id)", category: .event)
      }
    } else {
      // INSERT or UPDATE (soft deletes come through as UPDATE with deleted_at set)
      guard let cleanRecord = payload.cleanedRecord() else {
        debugLog.log("  Broadcast: Failed to get cleanedRecord for note", category: .event)
        return
      }

      let recordData = try JSONSerialization.data(withJSONObject: cleanRecord)
      let dto = try PostgrestClient.Configuration.jsonDecoder.decode(NoteDTO.self, from: recordData)

      #if DEBUG
      trackDuplicateProcessing(id: dto.id, entityType: "note")
      #endif

      delegate?.parser(self, didReceiveNoteDTO: dto)
      debugLog.log("  Broadcast: Processed note \(dto.id)", category: .event)
    }
  }

  #if DEBUG
  /// Track recently processed IDs to detect duplicate processing
  private func trackDuplicateProcessing(id: UUID, entityType: String) {
    if recentlyProcessedIds.contains(id) {
      debugLog.log("  Broadcast: Duplicate processing detected for \(entityType) \(id)", category: .event)
    }
    recentlyProcessedIds.insert(id)
  }
  #endif
}
