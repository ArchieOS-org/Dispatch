//
//  RealtimeManager.swift
//  Dispatch
//
//  Extracted from SyncManager (PATCHSET 1) - handles Supabase realtime channel lifecycle
//  and event routing. Uses delegate pattern to decouple from sync operations.
//

import Foundation
import PostgREST
import Supabase
import SwiftData

// MARK: - RealtimeManagerDelegate

/// Delegate protocol for RealtimeManager to notify of incoming changes.
/// SyncManager implements this to apply DTOs to the local database.
@MainActor
protocol RealtimeManagerDelegate: AnyObject {
  /// Current user ID for self-echo filtering
  var currentUserID: UUID? { get }

  /// Model container for context access
  var modelContainer: ModelContainer? { get }

  func realtimeManager(_ manager: RealtimeManager, didReceiveTaskDTO dto: TaskDTO)
  func realtimeManager(_ manager: RealtimeManager, didReceiveActivityDTO dto: ActivityDTO)
  func realtimeManager(_ manager: RealtimeManager, didReceiveListingDTO dto: ListingDTO)
  func realtimeManager(_ manager: RealtimeManager, didReceiveUserDTO dto: UserDTO)
  func realtimeManager(_ manager: RealtimeManager, didReceiveNoteDTO dto: NoteDTO)
  func realtimeManager(_ manager: RealtimeManager, didReceiveDeleteFor table: BroadcastTable, id: UUID)
  func realtimeManager(_ manager: RealtimeManager, statusDidChange status: SyncStatus)

  /// Check if an entity is in-flight (being synced up) to skip self-echoes
  func realtimeManager(_ manager: RealtimeManager, isInFlightTaskId id: UUID) -> Bool
  func realtimeManager(_ manager: RealtimeManager, isInFlightActivityId id: UUID) -> Bool
  func realtimeManager(_ manager: RealtimeManager, isInFlightNoteId id: UUID) -> Bool

}

// MARK: - RealtimeManager

/// Manages Supabase realtime channel subscriptions and event routing.
/// Extracted from SyncManager to isolate channel lifecycle from sync operations.
@MainActor
final class RealtimeManager {

  // MARK: Lifecycle

  init(mode: SyncRunMode = .live) {
    self.mode = mode
    debugLog.log("RealtimeManager initialized (mode: \(mode))", category: .realtime)
  }

  // MARK: Internal

  nonisolated let mode: SyncRunMode

  weak var delegate: RealtimeManagerDelegate?

  /// Feature flag: Enable broadcast-based realtime (v2)
  /// When true, subscribes to broadcast channel IN ADDITION to postgres_changes
  let useBroadcastRealtime = true

  /// Channel references
  private(set) var realtimeChannel: RealtimeChannelV2?
  private(set) var broadcastChannel: RealtimeChannelV2?

  /// Listening state
  private(set) var isListening = false

  // MARK: - Task References (for deterministic shutdown)

  /// Status monitoring task
  var statusTask: Task<Void, Never>?
  /// Broadcast event listener task
  var broadcastTask: Task<Void, Never>?
  /// Broadcast setup task
  var startBroadcastListeningTask: Task<Void, Never>?

  // Per-table subscription tasks
  var tasksSubscriptionTask: Task<Void, Never>?
  var activitiesSubscriptionTask: Task<Void, Never>?
  var listingsSubscriptionTask: Task<Void, Never>?
  var usersSubscriptionTask: Task<Void, Never>?
  var notesSubscriptionTask: Task<Void, Never>?

  // MARK: - Public API

  /// Starts listening to realtime channels (postgres_changes + optional broadcast)
  func startListening() async {
    // Strict Preview/Test Guard
    if mode == .preview || mode == .test {
      return
    }

    debugLog.log("", category: .realtime)
    debugLog.log("============================================================", category: .realtime)
    debugLog.log("           startListening() CALLED                          ", category: .realtime)
    debugLog.log("============================================================", category: .realtime)

    guard delegate?.currentUserID != nil else {
      debugLog.log("SKIPPING startListening - not authenticated", category: .realtime)
      return
    }
    guard !isListening else {
      debugLog.log("SKIPPING startListening - already listening", category: .realtime)
      return
    }
    guard delegate?.modelContainer != nil else {
      debugLog.log("SKIPPING startListening - no modelContainer", category: .realtime)
      return
    }

    // 1. Create Channel
    let channelName = "dispatch-sync"
    let channel = supabase.realtimeV2.channel(channelName)

    // 2. Configure Streams (Insert/Update/Delete) for each table
    // --- TASKS ---
    let tasksInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "tasks")
    let tasksUpdates = channel.postgresChange(UpdateAction.self, schema: "public", table: "tasks")
    let tasksDeletes = channel.postgresChange(DeleteAction.self, schema: "public", table: "tasks")

    // --- ACTIVITIES ---
    let actInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "activities")
    let actUpdates = channel.postgresChange(UpdateAction.self, schema: "public", table: "activities")
    let actDeletes = channel.postgresChange(DeleteAction.self, schema: "public", table: "activities")

    // --- LISTINGS ---
    let listInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "listings")
    let listUpdates = channel.postgresChange(UpdateAction.self, schema: "public", table: "listings")
    let listDeletes = channel.postgresChange(DeleteAction.self, schema: "public", table: "listings")

    // --- USERS ---
    let usersInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "users")
    let usersUpdates = channel.postgresChange(UpdateAction.self, schema: "public", table: "users")
    let usersDeletes = channel.postgresChange(DeleteAction.self, schema: "public", table: "users")

    // --- NOTES ---
    let noteInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "notes")
    let noteUpdates = channel.postgresChange(UpdateAction.self, schema: "public", table: "notes")
    let noteDeletes = channel.postgresChange(DeleteAction.self, schema: "public", table: "notes")

    // PHASE A: Prepare (Create channel + stream refs, no global state writes)
    // Subscribe to channel
    do {
      try await channel.subscribeWithError()
    } catch {
      debugLog.error("Realtime subscribe failed", error: error)
      return
    }

    // PHASE B: Publish (Commit state + spawn tasks)
    // Only set this AFTER successful subscribe
    realtimeChannel = channel
    isListening = true

    // PHASE C: Spawn Consumption Tasks
    // Now it is safe to spawn tasks because we are committed.

    statusTask = Task { [weak self] in
      for await status in channel.statusChange {
        if Task.isCancelled { return }
        debugLog.log("Realtime Status: \(status)", category: .realtime)
        await MainActor.run {
          let mappedStatus = self?.mapRealtimeStatus(status) ?? .idle
          guard let self else { return }
          self.delegate?.realtimeManager(self, statusDidChange: mappedStatus)
        }
      }
    }

    tasksSubscriptionTask = Task { [weak self] in
      guard let self else { return }
      await withTaskGroup(of: Void.self) { group in
        group.addTask {
          for await e in tasksInserts {
            if Task.isCancelled { return }
            await self.handleTaskInsert(e)
          }
        }
        group.addTask {
          for await e in tasksUpdates {
            if Task.isCancelled { return }
            await self.handleTaskUpdate(e)
          }
        }
        group.addTask {
          for await e in tasksDeletes {
            if Task.isCancelled { return }
            await self.handleTaskDelete(e)
          }
        }
      }
    }

    activitiesSubscriptionTask = Task { [weak self] in
      guard let self else { return }
      await withTaskGroup(of: Void.self) { group in
        group.addTask {
          for await e in actInserts {
            if Task.isCancelled { return }
            await self.handleActivityInsert(e)
          }
        }
        group.addTask {
          for await e in actUpdates {
            if Task.isCancelled { return }
            await self.handleActivityUpdate(e)
          }
        }
        group.addTask {
          for await e in actDeletes {
            if Task.isCancelled { return }
            await self.handleActivityDelete(e)
          }
        }
      }
    }

    listingsSubscriptionTask = Task { [weak self] in
      guard let self else { return }
      await withTaskGroup(of: Void.self) { group in
        group.addTask {
          for await e in listInserts {
            if Task.isCancelled { return }
            await self.handleListingInsert(e)
          }
        }
        group.addTask {
          for await e in listUpdates {
            if Task.isCancelled { return }
            await self.handleListingUpdate(e)
          }
        }
        group.addTask {
          for await e in listDeletes {
            if Task.isCancelled { return }
            await self.handleListingDelete(e)
          }
        }
      }
    }

    usersSubscriptionTask = Task { [weak self] in
      guard let self else { return }
      await withTaskGroup(of: Void.self) { group in
        group.addTask {
          for await e in usersInserts {
            if Task.isCancelled { return }
            await self.handleUserInsert(e)
          }
        }
        group.addTask {
          for await e in usersUpdates {
            if Task.isCancelled { return }
            await self.handleUserUpdate(e)
          }
        }
        group.addTask {
          for await e in usersDeletes {
            if Task.isCancelled { return }
            await self.handleUserDelete(e)
          }
        }
      }
    }

    notesSubscriptionTask = Task { [weak self] in
      guard let self else { return }
      await withTaskGroup(of: Void.self) { group in
        group.addTask {
          for await e in noteInserts {
            if Task.isCancelled { return }
            await self.handleNoteInsert(e)
          }
        }
        group.addTask {
          for await e in noteUpdates {
            if Task.isCancelled { return }
            await self.handleNoteUpdate(e)
          }
        }
        group.addTask {
          for await e in noteDeletes {
            if Task.isCancelled { return }
            await self.handleNoteDelete(e)
          }
        }
      }
    }

    // Start broadcast listening if enabled
    if useBroadcastRealtime {
      startBroadcastListeningTask = Task { [weak self] in
        await self?.startBroadcastListening()
      }
    }
  }

  /// Stops listening to all realtime channels
  func stopListening() async {
    debugLog.log("stopListening() called", category: .realtime)

    if let channel = realtimeChannel {
      debugLog.log("  Unsubscribing from postgres_changes channel...", category: .realtime)
      await channel.unsubscribe()
      debugLog.log("  postgres_changes channel unsubscribed", category: .realtime)
    }
    realtimeChannel = nil

    // Cleanup broadcast channel
    if let channel = broadcastChannel {
      debugLog.log("  Unsubscribing from broadcast channel...", category: .realtime)
      await channel.unsubscribe()
      debugLog.log("  Broadcast channel unsubscribed", category: .realtime)
    }
    broadcastChannel = nil

    isListening = false
    debugLog.log("Realtime stopped. isListening = false", category: .realtime)
  }

  /// Cancels all tasks and clears references (called from SyncManager.shutdown)
  func cancelAllTasks() {
    statusTask?.cancel()
    broadcastTask?.cancel()
    startBroadcastListeningTask?.cancel()
    tasksSubscriptionTask?.cancel()
    activitiesSubscriptionTask?.cancel()
    listingsSubscriptionTask?.cancel()
    usersSubscriptionTask?.cancel()
    notesSubscriptionTask?.cancel()
  }

  /// Awaits completion of all tasks (called from SyncManager.shutdown)
  func awaitAllTasks() async {
    _ = await statusTask?.result
    _ = await broadcastTask?.result
    _ = await startBroadcastListeningTask?.result
    _ = await tasksSubscriptionTask?.result
    _ = await activitiesSubscriptionTask?.result
    _ = await listingsSubscriptionTask?.result
    _ = await usersSubscriptionTask?.result
    _ = await notesSubscriptionTask?.result
  }

  /// Clears all task references (called from SyncManager.shutdown)
  func clearTaskReferences() {
    statusTask = nil
    broadcastTask = nil
    startBroadcastListeningTask = nil
    tasksSubscriptionTask = nil
    activitiesSubscriptionTask = nil
    listingsSubscriptionTask = nil
    usersSubscriptionTask = nil
    notesSubscriptionTask = nil
  }

  // MARK: Private

  #if DEBUG
  /// Track recently processed IDs to detect duplicate processing (DEBUG only)
  /// Used during Phase 1 to log when both postgres_changes and broadcast process same event
  private var recentlyProcessedIds = Set<UUID>()
  #endif

  // MARK: - Private: Broadcast Listening

  /// Starts listening to broadcast channel (v2 pattern).
  /// Coexists with postgres_changes during Phase 1 migration.
  private func startBroadcastListening() async {
    guard useBroadcastRealtime else {
      debugLog.log("Broadcast realtime disabled (useBroadcastRealtime = false)", category: .channel)
      return
    }
    guard delegate?.currentUserID != nil, delegate?.modelContainer != nil else {
      debugLog.log("Skipping broadcast listener - not authenticated or no container", category: .channel)
      return
    }

    debugLog.log("", category: .channel)
    debugLog.log("============================================================", category: .channel)
    debugLog.log("       BROADCAST REALTIME (v2) STARTING                     ", category: .channel)
    debugLog.log("============================================================", category: .channel)

    // CRITICAL: Set auth token for Realtime Authorization (RLS on realtime.messages)
    // This must be called BEFORE subscribing to private channels
    debugLog.log("Setting Realtime auth token...", category: .channel)
    await supabase.realtimeV2.setAuth()
    debugLog.log("Realtime auth token set", category: .channel)

    // Create broadcast channel
    debugLog.log("Creating channel 'dispatch:broadcast' (testing without isPrivate)...", category: .channel)
    let channel = supabase.realtimeV2.channel("dispatch:broadcast") {
      $0.broadcast.receiveOwnBroadcasts = true // We filter by origin_user_id instead
    }

    // Subscribe to all broadcast events
    let broadcastStream = channel.broadcastStream(event: "*")

    debugLog.log("Calling channel.subscribeWithError() for broadcast...", category: .channel)
    do {
      // Add timeout to detect hanging subscriptions
      try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
          try await channel.subscribeWithError()
        }
        group.addTask {
          try await Task.sleep(for: .seconds(10))
          throw NSError(
            domain: "Broadcast",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Subscription timed out after 10s"]
          )
        }
        // Wait for first to complete (subscription or timeout)
        try await group.next()
        group.cancelAll()
      }
      debugLog.log("Broadcast channel subscribed successfully", category: .channel)
    } catch {
      debugLog.error("Broadcast subscription failed", error: error)
      return
    }

    broadcastChannel = channel

    // Create listener task for broadcast events
    broadcastTask = Task { [weak self] in
      guard let self else { return }
      guard let container = delegate?.modelContainer else { return }

      debugLog.log("Broadcast listener task STARTED", category: .event)
      for await event in broadcastStream {
        if Task.isCancelled { break }
        await handleBroadcastEvent(event, container: container)
      }
      debugLog.log("Broadcast listener task ENDED", category: .event)
    }

    debugLog.log("", category: .channel)
    debugLog.log("Broadcast channel ready - listening for events on 'dispatch:broadcast'", category: .channel)
  }

  // MARK: - Private: Broadcast Event Handling

  /// Handles broadcast events - routes to existing upsert/delete methods
  private func handleBroadcastEvent(_ event: JSONObject, container: ModelContainer) async {
    do {
      // Log raw payload for debugging
      debugLog.log("", category: .event)
      debugLog.log("RAW BROADCAST EVENT RECEIVED", category: .event)

      // JSONObject is [String: AnyJSON] - use JSONEncoder for AnyJSON (Codable)
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      if
        let jsonData = try? encoder.encode(event),
        let jsonString = String(data: jsonData, encoding: .utf8)
      {
        debugLog.log("Raw payload:\n\(jsonString)", category: .event)
      } else {
        debugLog.log("Raw payload (keys): \(event.keys.joined(separator: ", "))", category: .event)
      }

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

      let context = container.mainContext

      // Route to appropriate handler based on table (type-safe enum switch)
      switch payload.table {
      case .tasks:
        try await handleTaskBroadcast(payload: payload, context: context)
      case .activities:
        try await handleActivityBroadcast(payload: payload, context: context)
      case .listings:
        try await handleListingBroadcast(payload: payload, context: context)
      case .users:
        try await handleUserBroadcast(payload: payload, context: context)
      case .notes:
        try await handleNoteBroadcast(payload: payload, context: context)
      }

      try context.save()

    } catch {
      debugLog.error("Failed to handle broadcast event", error: error)
    }
  }

  /// Handles task broadcast - converts payload to TaskDTO and notifies delegate
  private func handleTaskBroadcast(payload: BroadcastChangePayload, context _: ModelContext) async throws {
    if payload.type == .delete {
      if
        let oldRecord = payload.cleanedOldRecord(),
        let idString = oldRecord["id"] as? String,
        let id = UUID(uuidString: idString)
      {
        delegate?.realtimeManager(self, didReceiveDeleteFor: .tasks, id: id)
        debugLog.log("  Broadcast: Deleted task \(id)", category: .event)
      }
    } else {
      guard let cleanRecord = payload.cleanedRecord() else { return }

      let recordData = try JSONSerialization.data(withJSONObject: cleanRecord)
      let dto = try PostgrestClient.Configuration.jsonDecoder.decode(TaskDTO.self, from: recordData)

      // Use in-flight check as backup (will be removed in Phase 3)
      if delegate?.realtimeManager(self, isInFlightTaskId: dto.id) == true {
        debugLog.log("  Broadcast: Skipping in-flight task \(dto.id)", category: .event)
        return
      }

      #if DEBUG
      trackDuplicateProcessing(id: dto.id, entityType: "task")
      #endif

      delegate?.realtimeManager(self, didReceiveTaskDTO: dto)
      debugLog.log("  Broadcast: Upserted task \(dto.id)", category: .event)
    }
  }

  /// Handles activity broadcast - converts payload to ActivityDTO and notifies delegate
  private func handleActivityBroadcast(payload: BroadcastChangePayload, context _: ModelContext) async throws {
    if payload.type == .delete {
      if
        let oldRecord = payload.cleanedOldRecord(),
        let idString = oldRecord["id"] as? String,
        let id = UUID(uuidString: idString)
      {
        delegate?.realtimeManager(self, didReceiveDeleteFor: .activities, id: id)
        debugLog.log("  Broadcast: Deleted activity \(id)", category: .event)
      }
    } else {
      guard let cleanRecord = payload.cleanedRecord() else { return }

      let recordData = try JSONSerialization.data(withJSONObject: cleanRecord)
      let dto = try PostgrestClient.Configuration.jsonDecoder.decode(ActivityDTO.self, from: recordData)

      if delegate?.realtimeManager(self, isInFlightActivityId: dto.id) == true {
        debugLog.log("  Broadcast: Skipping in-flight activity \(dto.id)", category: .event)
        return
      }

      #if DEBUG
      trackDuplicateProcessing(id: dto.id, entityType: "activity")
      #endif

      delegate?.realtimeManager(self, didReceiveActivityDTO: dto)
      debugLog.log("  Broadcast: Upserted activity \(dto.id)", category: .event)
    }
  }

  /// Handles listing broadcast - converts payload to ListingDTO and notifies delegate
  private func handleListingBroadcast(payload: BroadcastChangePayload, context _: ModelContext) async throws {
    if payload.type == .delete {
      if
        let oldRecord = payload.cleanedOldRecord(),
        let idString = oldRecord["id"] as? String,
        let id = UUID(uuidString: idString)
      {
        delegate?.realtimeManager(self, didReceiveDeleteFor: .listings, id: id)
        debugLog.log("  Broadcast: Deleted listing \(id)", category: .event)
      }
    } else {
      guard let cleanRecord = payload.cleanedRecord() else { return }

      let recordData = try JSONSerialization.data(withJSONObject: cleanRecord)
      let dto = try PostgrestClient.Configuration.jsonDecoder.decode(ListingDTO.self, from: recordData)

      #if DEBUG
      trackDuplicateProcessing(id: dto.id, entityType: "listing")
      #endif

      delegate?.realtimeManager(self, didReceiveListingDTO: dto)
      debugLog.log("  Broadcast: Upserted listing \(dto.id)", category: .event)
    }
  }

  /// Handles user broadcast - converts payload to UserDTO and notifies delegate
  private func handleUserBroadcast(payload: BroadcastChangePayload, context _: ModelContext) async throws {
    if payload.type == .delete {
      if
        let oldRecord = payload.cleanedOldRecord(),
        let idString = oldRecord["id"] as? String,
        let id = UUID(uuidString: idString)
      {
        delegate?.realtimeManager(self, didReceiveDeleteFor: .users, id: id)
        debugLog.log("  Broadcast: Deleted user \(id)", category: .event)
      }
    } else {
      guard let cleanRecord = payload.cleanedRecord() else { return }

      let recordData = try JSONSerialization.data(withJSONObject: cleanRecord)
      let dto = try PostgrestClient.Configuration.jsonDecoder.decode(UserDTO.self, from: recordData)

      #if DEBUG
      trackDuplicateProcessing(id: dto.id, entityType: "user")
      #endif

      delegate?.realtimeManager(self, didReceiveUserDTO: dto)
      debugLog.log("  Broadcast: Upserted user \(dto.id)", category: .event)
    }
  }

  /// Handles note broadcast - converts payload to NoteDTO and notifies delegate
  private func handleNoteBroadcast(payload: BroadcastChangePayload, context _: ModelContext) async throws {
    if payload.type == .delete {
      // Hard delete on server = notify delegate to hard delete locally
      if
        let oldRecord = payload.cleanedOldRecord(),
        let idString = oldRecord["id"] as? String,
        let id = UUID(uuidString: idString)
      {
        delegate?.realtimeManager(self, didReceiveDeleteFor: .notes, id: id)
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

      delegate?.realtimeManager(self, didReceiveNoteDTO: dto)
      debugLog.log("  Broadcast: Processed note \(dto.id)", category: .event)
    }
  }

  // MARK: - Private: Postgres Change Handlers

  private func handleTaskInsert(_ action: InsertAction) async {
    debugLog.log("[Realtime] Task INSERT event received", category: .realtime)
    do {
      let dto = try action.decodeRecord(as: TaskDTO.self, decoder: PostgrestClient.Configuration.jsonDecoder)
      debugLog.log("  Decoded task: \(dto.id) - \(dto.title)", category: .realtime)
      delegate?.realtimeManager(self, didReceiveTaskDTO: dto)
      debugLog.log("  Upserted task successfully", category: .realtime)
    } catch {
      debugLog.error("Failed to handle Task INSERT", error: error)
    }
  }

  private func handleTaskUpdate(_ action: UpdateAction) async {
    debugLog.log("[Realtime] Task UPDATE event received", category: .realtime)
    do {
      let dto = try action.decodeRecord(as: TaskDTO.self, decoder: PostgrestClient.Configuration.jsonDecoder)
      debugLog.log("  Decoded task: \(dto.id) - \(dto.title)", category: .realtime)
      delegate?.realtimeManager(self, didReceiveTaskDTO: dto)
      debugLog.log("  Upserted task successfully", category: .realtime)
    } catch {
      debugLog.error("Failed to handle Task UPDATE", error: error)
    }
  }

  private func handleTaskDelete(_ action: DeleteAction) async {
    debugLog.log("[Realtime] Task DELETE event received", category: .realtime)
    if let id = extractUUID(from: action.oldRecord, key: "id") {
      debugLog.log("  Deleting task: \(id)", category: .realtime)
      delegate?.realtimeManager(self, didReceiveDeleteFor: .tasks, id: id)
      debugLog.log("  Deleted task successfully", category: .realtime)
    } else {
      debugLog.log("  Could not extract ID from oldRecord", category: .realtime)
    }
  }

  private func handleActivityInsert(_ action: InsertAction) async {
    do {
      let dto = try action.decodeRecord(as: ActivityDTO.self, decoder: PostgrestClient.Configuration.jsonDecoder)
      delegate?.realtimeManager(self, didReceiveActivityDTO: dto)
    } catch {
      debugLog.error("Failed to handle Activity INSERT", error: error)
    }
  }

  private func handleActivityUpdate(_ action: UpdateAction) async {
    do {
      let dto = try action.decodeRecord(as: ActivityDTO.self, decoder: PostgrestClient.Configuration.jsonDecoder)
      delegate?.realtimeManager(self, didReceiveActivityDTO: dto)
    } catch {
      debugLog.error("Failed to handle Activity UPDATE", error: error)
    }
  }

  private func handleActivityDelete(_ action: DeleteAction) async {
    if let id = extractUUID(from: action.oldRecord, key: "id") {
      delegate?.realtimeManager(self, didReceiveDeleteFor: .activities, id: id)
    }
  }

  private func handleListingInsert(_ action: InsertAction) async {
    debugLog.log("[Realtime] Listing INSERT event received", category: .realtime)
    do {
      let dto = try action.decodeRecord(as: ListingDTO.self, decoder: PostgrestClient.Configuration.jsonDecoder)
      debugLog.log("  Decoded listing: \(dto.id) - \(dto.address)", category: .realtime)
      delegate?.realtimeManager(self, didReceiveListingDTO: dto)
      debugLog.log("  Upserted listing successfully", category: .realtime)
    } catch {
      debugLog.error("Failed to handle Listing INSERT", error: error)
    }
  }

  private func handleListingUpdate(_ action: UpdateAction) async {
    debugLog.log("[Realtime] Listing UPDATE event received", category: .realtime)
    do {
      let dto = try action.decodeRecord(as: ListingDTO.self, decoder: PostgrestClient.Configuration.jsonDecoder)
      debugLog.log("  Decoded listing: \(dto.id) - \(dto.address)", category: .realtime)
      delegate?.realtimeManager(self, didReceiveListingDTO: dto)
      debugLog.log("  Upserted listing successfully", category: .realtime)
    } catch {
      debugLog.error("Failed to handle Listing UPDATE", error: error)
    }
  }

  private func handleListingDelete(_ action: DeleteAction) async {
    debugLog.log("[Realtime] Listing DELETE event received", category: .realtime)
    if let id = extractUUID(from: action.oldRecord, key: "id") {
      debugLog.log("  Deleting listing: \(id)", category: .realtime)
      delegate?.realtimeManager(self, didReceiveDeleteFor: .listings, id: id)
      debugLog.log("  Deleted listing successfully", category: .realtime)
    } else {
      debugLog.log("  Could not extract ID from oldRecord", category: .realtime)
    }
  }

  private func handleUserInsert(_ action: InsertAction) async {
    do {
      let dto = try action.decodeRecord(as: UserDTO.self, decoder: PostgrestClient.Configuration.jsonDecoder)
      delegate?.realtimeManager(self, didReceiveUserDTO: dto)
    } catch {
      debugLog.error("Failed to handle User INSERT", error: error)
    }
  }

  private func handleUserUpdate(_ action: UpdateAction) async {
    do {
      let dto = try action.decodeRecord(as: UserDTO.self, decoder: PostgrestClient.Configuration.jsonDecoder)
      delegate?.realtimeManager(self, didReceiveUserDTO: dto)
    } catch {
      debugLog.error("Failed to handle User UPDATE", error: error)
    }
  }

  private func handleUserDelete(_ action: DeleteAction) async {
    if let id = extractUUID(from: action.oldRecord, key: "id") {
      delegate?.realtimeManager(self, didReceiveDeleteFor: .users, id: id)
    }
  }

  private func handleNoteInsert(_ action: InsertAction) async {
    guard
      let dto = try? action.decodeRecord(as: NoteDTO.self, decoder: PostgrestClient.Configuration.jsonDecoder)
    else { return }
    delegate?.realtimeManager(self, didReceiveNoteDTO: dto)
    debugLog.log("RT: Inserted Note \(dto.id)", category: .realtime)
  }

  private func handleNoteUpdate(_ action: UpdateAction) async {
    guard
      let dto = try? action.decodeRecord(as: NoteDTO.self, decoder: PostgrestClient.Configuration.jsonDecoder)
    else { return }
    delegate?.realtimeManager(self, didReceiveNoteDTO: dto)
    debugLog.log("RT: Updated Note \(dto.id) (Deleted: \(dto.deletedAt != nil))", category: .realtime)
  }

  private func handleNoteDelete(_ action: DeleteAction) async {
    guard let id = extractUUID(from: action.oldRecord, key: "id") else { return }
    delegate?.realtimeManager(self, didReceiveDeleteFor: .notes, id: id)
    debugLog.log("RT: Hard DELETE for Note \(id)", category: .realtime)
  }

  // MARK: - Private: Helpers

  /// Maps Supabase RealtimeChannelStatus to our global SyncStatus
  private func mapRealtimeStatus(_ status: RealtimeChannelStatus) -> SyncStatus {
    switch status {
    case .subscribed:
      return .ok(Date()) // Connected and healthy
    case .subscribing:
      return .syncing // Connecting...
    case .unsubscribing:
      return .syncing // Disconnecting in progress
    case .unsubscribed:
      return .idle // Stopped
    @unknown default:
      return .idle
    }
  }

  /// Extract a UUID from an AnyJSON dictionary (used for realtime DELETE event handling)
  private func extractUUID(from record: [String: AnyJSON], key: String) -> UUID? {
    guard let value = record[key] else { return nil }

    // Try direct string extraction using description
    let stringValue = String(describing: value)

    // Clean up the string - it might be wrapped in quotes or have "string(" prefix
    let cleanedValue = stringValue
      .replacingOccurrences(of: "string(\"", with: "")
      .replacingOccurrences(of: "\")", with: "")
      .replacingOccurrences(of: "\"", with: "")
      .trimmingCharacters(in: .whitespaces)

    return UUID(uuidString: cleanedValue)
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
