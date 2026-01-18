//
//  NoteSyncHandler.swift
//  Dispatch
//
//  Handles all Note-specific sync operations: syncDown, syncUp, upsert, delete.
//  Extracted from EntitySyncHandler for maintainability.
//

import Foundation
import Supabase
import SwiftData

// MARK: - NoteSyncHandler

/// Handles Note entity sync operations.
/// Includes special handling for parent relationships and reconciliation.
@MainActor
final class NoteSyncHandler: EntitySyncHandlerProtocol {

  // MARK: Lifecycle

  init(dependencies: SyncHandlerDependencies) {
    self.dependencies = dependencies
  }

  // MARK: Internal

  /// Source of remote note changes for logging
  enum RemoteNoteSource: CustomStringConvertible {
    case syncDown
    case broadcast

    var description: String {
      switch self {
      case .syncDown: "syncDown"
      case .broadcast: "broadcast"
      }
    }
  }

  // MARK: - UserDefaults Keys

  static let lastSyncNotesKey = "dispatch.lastSyncNotes"

  let dependencies: SyncHandlerDependencies

  // MARK: - SyncDown Notes

  func syncDown(context: ModelContext, since _: String) async throws {
    // Per-table watermark with 2s overlap window
    let lastSync = (
      dependencies.mode == .live
        ? UserDefaults.standard.object(forKey: Self.lastSyncNotesKey) as? Date
        : nil
    ) ?? Date.distantPast
    let safeDate = lastSync.addingTimeInterval(-2)
    let safeISO = ISO8601DateFormatter().string(from: safeDate)

    debugLog.log("syncDownNotes() - fetching records updated since: \(safeISO)", category: .sync)

    let dtos: [NoteDTO] = try await supabase
      .from("notes")
      .select()
      .gte("updated_at", value: safeISO)
      .execute()
      .value

    debugLog.logSyncOperation(operation: "FETCH", table: "notes", count: dtos.count)

    for dto in dtos {
      try applyRemoteNote(dto: dto, source: .syncDown, context: context)
    }

    // Update per-table watermark
    if dependencies.mode == .live {
      UserDefaults.standard.set(Date(), forKey: Self.lastSyncNotesKey)
    }
  }

  // MARK: - SyncUp Notes

  func syncUp(context: ModelContext) async throws {
    let descriptor = FetchDescriptor<Note>()
    let allNotes = try context.fetch(descriptor)

    let pendingNotes = allNotes.filter { $0.syncState == .pending || $0.syncState == .failed }
    debugLog.logSyncOperation(
      operation: "PENDING",
      table: "notes",
      count: pendingNotes.count,
      details: "of \(allNotes.count) total"
    )

    guard !pendingNotes.isEmpty else { return }

    // Mark in-flight BEFORE any network calls to prevent realtime echo overwrites
    dependencies.conflictResolver.markNotesInFlight(Set(pendingNotes.map { $0.id }))
    defer { dependencies.conflictResolver.clearNotesInFlight() }

    // INSERT-first pattern: Try batch INSERT first (for new notes)
    // This avoids relying on syncedAt which can be unreliable after reinstalls/DB resets
    let insertDTOs = pendingNotes.map { NoteDTO(from: $0) }
    debugLog.log("  Attempting batch INSERT for \(insertDTOs.count) notes...", category: .sync)

    do {
      try await supabase
        .from("notes")
        .insert(insertDTOs)
        .execute()

      // All succeeded as inserts
      for note in pendingNotes {
        note.markSynced()
        note.hasRemoteChangeWhilePending = false
      }
      debugLog.log("  Batch INSERT succeeded for \(pendingNotes.count) notes", category: .sync)
      return
    } catch {
      // Some/all may already exist - fall through to update path
      debugLog.log("  Batch INSERT had conflicts, trying UPDATE path...", category: .sync)
    }

    // Batch UPDATE with mutable-only DTO (NoteUpdateDTO excludes immutable columns)
    // This respects column-level UPDATE grants on: content, edited_at, edited_by, updated_at, deleted_at, deleted_by
    let updateDTOs = pendingNotes.map { NoteUpdateDTO(from: $0) }

    do {
      try await supabase
        .from("notes")
        .upsert(updateDTOs, onConflict: "id")
        .execute()

      for note in pendingNotes {
        note.markSynced()
        note.hasRemoteChangeWhilePending = false
      }
      debugLog.log("  Batch UPDATE succeeded for \(pendingNotes.count) notes", category: .sync)
    } catch {
      // Individual fallback for partial failures
      debugLog.log("Batch note UPDATE failed, trying individually: \(error.localizedDescription)", category: .error)

      for note in pendingNotes {
        do {
          let dto = NoteUpdateDTO(from: note)
          try await supabase
            .from("notes")
            .upsert([dto], onConflict: "id")
            .execute()
          note.markSynced()
          note.hasRemoteChangeWhilePending = false
          debugLog.log("  Note \(note.id) synced", category: .sync)
        } catch {
          let message = dependencies.userFacingMessage(for: error)
          note.markFailed(message)
          debugLog.error("  Note \(note.id) sync failed: \(message)")
        }
      }
    }
  }

  // MARK: - Apply Remote Note

  /// Single source of truth for applying remote note changes (used by syncDown and broadcast)
  /// Handles in-flight protection, pending protection, and upsert in one place.
  func applyRemoteNote(dto: NoteDTO, source: RemoteNoteSource, context: ModelContext) throws {
    let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == dto.id })
    let existing = try context.fetch(descriptor).first

    // 1. In-flight protection: skip if we're currently syncing this note up
    if dependencies.conflictResolver.isNoteInFlight(dto.id) {
      debugLog.log("  Skipping in-flight note \(dto.id) from \(source)", category: .sync)
      return
    }

    // 2. Pending protection: don't overwrite if we have pending local changes
    if let existing, existing.syncState == .pending || existing.syncState == .failed {
      existing.hasRemoteChangeWhilePending = true
      debugLog.log("  Marked pending note \(dto.id) as having remote change from \(source)", category: .sync)
      return
    }

    // 3. Upsert (handles soft delete via deleted_at field)
    if let existing {
      // UPDATE (or Soft Delete)
      if let deletedAt = dto.deletedAt {
        debugLog.log("    SOFT DELETE existing note: \(dto.id)", category: .sync)
        existing.deletedAt = deletedAt
        existing.deletedBy = dto.deletedBy
        existing.markSynced()
      } else {
        debugLog.log("    UPDATE existing note: \(dto.id)", category: .sync)
        existing.content = dto.content
        existing.editedAt = dto.editedAt
        existing.editedBy = dto.editedBy
        existing.updatedAt = dto.updatedAt ?? existing.updatedAt
        existing.deletedAt = nil // Resurrect if needed
        existing.deletedBy = nil
        existing.markSynced()
      }

      // Parent keys are immutable, but update just in case
      if let pType = ParentType(rawValue: dto.parentType) {
        existing.parentType = pType
      }
      existing.parentId = dto.parentId
    } else {
      // INSERT (even if deleted on server, as tombstone)
      debugLog.log("    INSERT new note: \(dto.id)", category: .sync)
      let newNote = dto.toModel()
      context.insert(newNote)

      // Link note to parent's notes array (required for UI to display it)
      let parentId = dto.parentId
      if let parentType = ParentType(rawValue: dto.parentType) {
        switch parentType {
        case .task:
          let taskDescriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == parentId })
          if let task = try? context.fetch(taskDescriptor).first {
            task.notes.append(newNote)
            debugLog.log("    -> Linked note to task \(parentId)", category: .sync)
          }

        case .activity:
          let activityDescriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.id == parentId })
          if let activity = try? context.fetch(activityDescriptor).first {
            activity.notes.append(newNote)
            debugLog.log("    -> Linked note to activity \(parentId)", category: .sync)
          }

        case .listing:
          let listingDescriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == parentId })
          if let listing = try? context.fetch(listingDescriptor).first {
            listing.notes.append(newNote)
            debugLog.log("    -> Linked note to listing \(parentId)", category: .sync)
          }
        }
      }
    }
  }

  // MARK: - Delete Note

  func deleteLocalNote(id: UUID, context: ModelContext) throws -> Bool {
    let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == id })
    guard let note = try context.fetch(descriptor).first else {
      debugLog.log("deleteLocalNote: Note \(id) not found locally", category: .sync)
      return false
    }
    debugLog.log("deleteLocalNote: Deleting note \(id)", category: .sync)
    context.delete(note)
    return true
  }

  // MARK: - Reconcile Missing Notes

  /// Reconciles missing notes - finds notes on server that don't exist locally and fetches them.
  /// This is a failsafe to catch notes that were missed due to watermark issues or other sync gaps.
  /// Runs on every sync to ensure data consistency.
  func reconcileMissingNotes(context: ModelContext) async throws -> Int {
    // 1. Fetch all note IDs from server (lightweight query)
    let remoteDTOs: [IDOnlyDTO] = try await supabase
      .from("notes")
      .select("id")
      .execute()
      .value
    let remoteIds = Set(remoteDTOs.map { $0.id })
    debugLog.log("  Remote notes: \(remoteIds.count)", category: .sync)

    // 2. Get all local note IDs
    let localDescriptor = FetchDescriptor<Note>()
    let localNotes = try context.fetch(localDescriptor)
    let localIds = Set(localNotes.map { $0.id })
    debugLog.log("  Local notes: \(localIds.count)", category: .sync)

    // 3. Find IDs that exist on server but not locally
    let missingIds = remoteIds.subtracting(localIds)

    guard !missingIds.isEmpty else {
      debugLog.log("  No missing notes", category: .sync)
      return 0
    }

    debugLog.log("  Warning: Found \(missingIds.count) missing notes, fetching...", category: .sync)

    // 4. Fetch full note data for missing IDs (batch query)
    let missingDTOs: [NoteDTO] = try await supabase
      .from("notes")
      .select()
      .in("id", values: Array(missingIds).map { $0.uuidString })
      .execute()
      .value

    // 5. Insert missing notes using unified merge function
    for dto in missingDTOs {
      try applyRemoteNote(dto: dto, source: .syncDown, context: context)
    }

    debugLog.log("  Reconciled \(missingDTOs.count) missing notes", category: .sync)
    return missingDTOs.count
  }

  // MARK: Private

  /// Lightweight DTO for fetching only IDs from Supabase
  private struct IDOnlyDTO: Codable {
    let id: UUID
  }
}
