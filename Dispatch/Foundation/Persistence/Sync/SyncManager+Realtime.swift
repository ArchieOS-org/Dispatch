//
//  SyncManager+Realtime.swift
//  Dispatch
//
//  Extracted from SyncManager.swift for cohesion.
//  Contains RealtimeManagerDelegate implementation for handling realtime events.
//

import Foundation
import SwiftData

// MARK: - SyncManager + RealtimeManagerDelegate

extension SyncManager: RealtimeManagerDelegate {

  func realtimeManager(_: RealtimeManager, didReceiveTaskDTO dto: TaskDTO) {
    guard let context = modelContainer?.mainContext else { return }
    do {
      try entitySyncHandler.upsertTask(dto: dto, context: context)
    } catch {
      debugLog.error("Failed to upsert task from realtime", error: error)
    }
  }

  func realtimeManager(_: RealtimeManager, didReceiveActivityDTO dto: ActivityDTO) {
    guard let context = modelContainer?.mainContext else { return }
    do {
      try entitySyncHandler.upsertActivity(dto: dto, context: context)
    } catch {
      debugLog.error("Failed to upsert activity from realtime", error: error)
    }
  }

  func realtimeManager(_: RealtimeManager, didReceiveListingDTO dto: ListingDTO) {
    guard let context = modelContainer?.mainContext else { return }
    do {
      try entitySyncHandler.upsertListing(dto: dto, context: context)
    } catch {
      debugLog.error("Failed to upsert listing from realtime", error: error)
    }
  }

  func realtimeManager(_: RealtimeManager, didReceiveUserDTO dto: UserDTO) {
    guard let context = modelContainer?.mainContext else { return }
    Task {
      do {
        try await entitySyncHandler.upsertUser(dto: dto, context: context)
      } catch {
        debugLog.error("Failed to upsert user from realtime", error: error)
      }
    }
  }

  func realtimeManager(_: RealtimeManager, didReceiveNoteDTO dto: NoteDTO) {
    guard let context = modelContainer?.mainContext else { return }

    // Check pending protection before applying
    let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == dto.id })
    if let existing = try? context.fetch(descriptor).first {
      if existing.syncState == .pending || existing.syncState == .failed {
        debugLog.log("RT: Ignoring remote note for .pending Note \(dto.id)", category: .realtime)
        existing.hasRemoteChangeWhilePending = true
        return
      }
    }

    do {
      try entitySyncHandler.applyRemoteNote(dto: dto, source: .broadcast, context: context)
    } catch {
      debugLog.error("Failed to apply note from realtime", error: error)
    }
  }

  func realtimeManager(_: RealtimeManager, didReceiveDeleteFor table: BroadcastTable, id: UUID) {
    guard let context = modelContainer?.mainContext else { return }
    do {
      switch table {
      case .tasks:
        _ = try entitySyncHandler.deleteLocalTask(id: id, context: context)
      case .activities:
        _ = try entitySyncHandler.deleteLocalActivity(id: id, context: context)
      case .listings:
        _ = try entitySyncHandler.deleteLocalListing(id: id, context: context)
      case .users:
        _ = try entitySyncHandler.deleteLocalUser(id: id, context: context)
      case .notes:
        // Hard delete from server = hard delete locally for notes
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == id })
        if let existing = try? context.fetch(descriptor).first {
          context.delete(existing)
          debugLog.log("RT: Hard deleted note \(id)", category: .realtime)
        }
      }
    } catch {
      debugLog.error("Failed to delete \(table) from realtime", error: error)
    }
  }

  func realtimeManager(_: RealtimeManager, statusDidChange status: SyncStatus) {
    syncStatus = status
  }

  func realtimeManager(_: RealtimeManager, isInFlightTaskId id: UUID) -> Bool {
    conflictResolver.isTaskInFlight(id)
  }

  func realtimeManager(_: RealtimeManager, isInFlightActivityId id: UUID) -> Bool {
    conflictResolver.isActivityInFlight(id)
  }

  func realtimeManager(_: RealtimeManager, isInFlightNoteId id: UUID) -> Bool {
    conflictResolver.isNoteInFlight(id)
  }
}
