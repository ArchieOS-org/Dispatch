//
//  ChannelLifecycleManager.swift
//  Dispatch
//
//  Extracted from RealtimeManager - handles channel subscription/unsubscription lifecycle.
//

import Foundation
import PostgREST
import Supabase

// MARK: - ChannelLifecycleDelegate

@MainActor
protocol ChannelLifecycleDelegate: AnyObject {
  func lifecycleManager(_ manager: ChannelLifecycleManager, statusDidChange status: SyncStatus)
  func lifecycleManager(_ manager: ChannelLifecycleManager, connectionStateDidChange state: RealtimeConnectionState)
  func lifecycleManager(_ manager: ChannelLifecycleManager, didReceiveTaskDTO dto: TaskDTO)
  func lifecycleManager(_ manager: ChannelLifecycleManager, didReceiveTaskDelete id: UUID)
  func lifecycleManager(_ manager: ChannelLifecycleManager, didReceiveActivityDTO dto: ActivityDTO)
  func lifecycleManager(_ manager: ChannelLifecycleManager, didReceiveActivityDelete id: UUID)
  func lifecycleManager(_ manager: ChannelLifecycleManager, didReceiveListingDTO dto: ListingDTO)
  func lifecycleManager(_ manager: ChannelLifecycleManager, didReceiveListingDelete id: UUID)
  func lifecycleManager(_ manager: ChannelLifecycleManager, didReceiveUserDTO dto: UserDTO)
  func lifecycleManager(_ manager: ChannelLifecycleManager, didReceiveUserDelete id: UUID)
  func lifecycleManager(_ manager: ChannelLifecycleManager, didReceiveNoteDTO dto: NoteDTO)
  func lifecycleManager(_ manager: ChannelLifecycleManager, didReceiveNoteDelete id: UUID)
  func lifecycleManagerDidRequestBroadcastStart(_ manager: ChannelLifecycleManager)
}

// MARK: - ChannelLifecycleManager

@MainActor
final class ChannelLifecycleManager {

  // MARK: Lifecycle

  init(mode: SyncRunMode = .live) {
    self.mode = mode
  }

  // MARK: Internal

  nonisolated let mode: SyncRunMode
  weak var delegate: ChannelLifecycleDelegate?
  private(set) var realtimeChannel: RealtimeChannelV2?
  private(set) var isListening = false
  private(set) var connectionState: RealtimeConnectionState = .connected
  private(set) var retryAttempt = 0
  var statusTask: Task<Void, Never>?
  var tasksSubscriptionTask: Task<Void, Never>?
  var activitiesSubscriptionTask: Task<Void, Never>?
  var listingsSubscriptionTask: Task<Void, Never>?
  var usersSubscriptionTask: Task<Void, Never>?
  var notesSubscriptionTask: Task<Void, Never>?

  func startListening(useBroadcastRealtime: Bool) async {
    if mode == .preview || mode == .test { return }
    guard !isListening else { return }

    let channel = supabase.realtimeV2.channel("dispatch-sync")

    // Configure streams
    let tasksIns = channel.postgresChange(InsertAction.self, schema: "public", table: "tasks")
    let tasksUpd = channel.postgresChange(UpdateAction.self, schema: "public", table: "tasks")
    let tasksDel = channel.postgresChange(DeleteAction.self, schema: "public", table: "tasks")
    let actIns = channel.postgresChange(InsertAction.self, schema: "public", table: "activities")
    let actUpd = channel.postgresChange(UpdateAction.self, schema: "public", table: "activities")
    let actDel = channel.postgresChange(DeleteAction.self, schema: "public", table: "activities")
    let listIns = channel.postgresChange(InsertAction.self, schema: "public", table: "listings")
    let listUpd = channel.postgresChange(UpdateAction.self, schema: "public", table: "listings")
    let listDel = channel.postgresChange(DeleteAction.self, schema: "public", table: "listings")
    let usersIns = channel.postgresChange(InsertAction.self, schema: "public", table: "users")
    let usersUpd = channel.postgresChange(UpdateAction.self, schema: "public", table: "users")
    let usersDel = channel.postgresChange(DeleteAction.self, schema: "public", table: "users")
    let noteIns = channel.postgresChange(InsertAction.self, schema: "public", table: "notes")
    let noteUpd = channel.postgresChange(UpdateAction.self, schema: "public", table: "notes")
    let noteDel = channel.postgresChange(DeleteAction.self, schema: "public", table: "notes")

    // Set flags BEFORE await to prevent race condition where stopListening() runs during await
    // and then gets overwritten after await completes
    realtimeChannel = channel
    isListening = true

    do {
      try await channel.subscribeWithError()
      // Check if stop was called during await
      if !isListening {
        await channel.unsubscribe()
        realtimeChannel = nil
        return
      }
    } catch {
      debugLog.error("Realtime subscribe failed", error: error)
      realtimeChannel = nil
      isListening = false
      await channel.unsubscribe()
      // Start retry loop on subscription failure
      startRetryLoop(useBroadcastRealtime: useBroadcastRealtime)
      return
    }
    // Subscription succeeded - reset retry state and notify delegate
    retryAttempt = 0
    updateConnectionState(.connected)

    // Status monitoring
    statusTask = Task { [weak self] in
      for await status in channel.statusChange {
        if Task.isCancelled { return }
        await MainActor.run {
          guard let self else { return }
          self.delegate?.lifecycleManager(self, statusDidChange: self.mapRealtimeStatus(status))
        }
      }
    }

    // Tasks
    tasksSubscriptionTask = Task { @MainActor [weak self] in
      guard let self else { return }
      await withTaskGroup(of: Void.self) { group in
        group.addTask { @MainActor in
          for await action in tasksIns {
            if Task.isCancelled { return }
            self.handleDTO(action, TaskDTO.self) {
              self.delegate?.lifecycleManager(self, didReceiveTaskDTO: $0)
            }
          }
        }
        group.addTask { @MainActor in
          for await action in tasksUpd {
            if Task.isCancelled { return }
            self.handleDTO(action, TaskDTO.self) {
              self.delegate?.lifecycleManager(self, didReceiveTaskDTO: $0)
            }
          }
        }
        group.addTask { @MainActor in
          for await action in tasksDel {
            if Task.isCancelled { return }
            self.handleDelete(action) {
              self.delegate?.lifecycleManager(self, didReceiveTaskDelete: $0)
            }
          }
        }
      }
    }

    // Activities
    activitiesSubscriptionTask = Task { @MainActor [weak self] in
      guard let self else { return }
      await withTaskGroup(of: Void.self) { group in
        group.addTask { @MainActor in
          for await action in actIns {
            if Task.isCancelled { return }
            self.handleDTO(action, ActivityDTO.self) {
              self.delegate?.lifecycleManager(self, didReceiveActivityDTO: $0)
            }
          }
        }
        group.addTask { @MainActor in
          for await action in actUpd {
            if Task.isCancelled { return }
            self.handleDTO(action, ActivityDTO.self) {
              self.delegate?.lifecycleManager(self, didReceiveActivityDTO: $0)
            }
          }
        }
        group.addTask { @MainActor in
          for await action in actDel {
            if Task.isCancelled { return }
            self.handleDelete(action) {
              self.delegate?.lifecycleManager(self, didReceiveActivityDelete: $0)
            }
          }
        }
      }
    }

    // Listings
    listingsSubscriptionTask = Task { @MainActor [weak self] in
      guard let self else { return }
      await withTaskGroup(of: Void.self) { group in
        group.addTask { @MainActor in
          for await action in listIns {
            if Task.isCancelled { return }
            self.handleDTO(action, ListingDTO.self) {
              self.delegate?.lifecycleManager(self, didReceiveListingDTO: $0)
            }
          }
        }
        group.addTask { @MainActor in
          for await action in listUpd {
            if Task.isCancelled { return }
            self.handleDTO(action, ListingDTO.self) {
              self.delegate?.lifecycleManager(self, didReceiveListingDTO: $0)
            }
          }
        }
        group.addTask { @MainActor in
          for await action in listDel {
            if Task.isCancelled { return }
            self.handleDelete(action) {
              self.delegate?.lifecycleManager(self, didReceiveListingDelete: $0)
            }
          }
        }
      }
    }

    // Users
    usersSubscriptionTask = Task { @MainActor [weak self] in
      guard let self else { return }
      await withTaskGroup(of: Void.self) { group in
        group.addTask { @MainActor in
          for await action in usersIns {
            if Task.isCancelled { return }
            self.handleDTO(action, UserDTO.self) {
              self.delegate?.lifecycleManager(self, didReceiveUserDTO: $0)
            }
          }
        }
        group.addTask { @MainActor in
          for await action in usersUpd {
            if Task.isCancelled { return }
            self.handleDTO(action, UserDTO.self) {
              self.delegate?.lifecycleManager(self, didReceiveUserDTO: $0)
            }
          }
        }
        group.addTask { @MainActor in
          for await action in usersDel {
            if Task.isCancelled { return }
            self.handleDelete(action) {
              self.delegate?.lifecycleManager(self, didReceiveUserDelete: $0)
            }
          }
        }
      }
    }

    // Notes
    notesSubscriptionTask = Task { @MainActor [weak self] in
      guard let self else { return }
      await withTaskGroup(of: Void.self) { group in
        group.addTask { @MainActor in
          for await action in noteIns {
            if Task.isCancelled { return }
            self.handleDTO(action, NoteDTO.self) {
              self.delegate?.lifecycleManager(self, didReceiveNoteDTO: $0)
            }
          }
        }
        group.addTask { @MainActor in
          for await action in noteUpd {
            if Task.isCancelled { return }
            self.handleDTO(action, NoteDTO.self) {
              self.delegate?.lifecycleManager(self, didReceiveNoteDTO: $0)
            }
          }
        }
        group.addTask { @MainActor in
          for await action in noteDel {
            if Task.isCancelled { return }
            self.handleDelete(action) {
              self.delegate?.lifecycleManager(self, didReceiveNoteDelete: $0)
            }
          }
        }
      }
    }

    if useBroadcastRealtime {
      delegate?.lifecycleManagerDidRequestBroadcastStart(self)
    }
  }

  func stopListening() async {
    // Cancel any active retry loop
    retryTask?.cancel()
    retryTask = nil
    if let channel = realtimeChannel { await channel.unsubscribe() }
    realtimeChannel = nil
    isListening = false
  }

  func cancelAllTasks() {
    retryTask?.cancel()
    [
      statusTask,
      tasksSubscriptionTask,
      activitiesSubscriptionTask,
      listingsSubscriptionTask,
      usersSubscriptionTask,
      notesSubscriptionTask
    ].forEach { $0?.cancel() }
  }

  func awaitAllTasks() async {
    _ = await retryTask?.result
    _ = await statusTask?.result
    _ = await tasksSubscriptionTask?.result
    _ = await activitiesSubscriptionTask?.result
    _ = await listingsSubscriptionTask?.result
    _ = await usersSubscriptionTask?.result
    _ = await notesSubscriptionTask?.result
  }

  func clearTaskReferences() {
    retryTask = nil
    statusTask = nil
    tasksSubscriptionTask = nil
    activitiesSubscriptionTask = nil
    listingsSubscriptionTask = nil
    usersSubscriptionTask = nil
    notesSubscriptionTask = nil
  }

  /// Reset retry state and attempt immediate reconnection.
  /// Called when network is restored or user triggers manual reconnect.
  func resetAndReconnect(useBroadcastRealtime: Bool) {
    // Cancel any existing retry loop
    retryTask?.cancel()
    retryTask = nil
    // Reset retry state (connection state will be set by startListening on success)
    retryAttempt = 0
    // Attempt fresh connection - startListening will set .connected on success (lines 103-104)
    Task { [weak self] in
      await self?.startListening(useBroadcastRealtime: useBroadcastRealtime)
    }
  }

  func mapRealtimeStatus(_ status: RealtimeChannelStatus) -> SyncStatus {
    switch status {
    case .subscribed: .ok(Date())
    case .subscribing, .unsubscribing: .syncing
    case .unsubscribed: .idle
    @unknown default: .idle
    }
  }

  func extractUUID(from record: [String: AnyJSON], key: String) -> UUID? {
    guard let value = record[key] else { return nil }
    let cleaned = String(describing: value)
      .replacingOccurrences(of: "string(\"", with: "")
      .replacingOccurrences(of: "\")", with: "")
      .replacingOccurrences(of: "\"", with: "")
      .trimmingCharacters(in: .whitespaces)
    return UUID(uuidString: cleaned)
  }

  // MARK: Private

  private var retryTask: Task<Void, Never>?

  private func handleDTO<DTO: Decodable>(_ action: some HasRecord, _ type: DTO.Type, _ callback: (DTO) -> Void) {
    do {
      let dto = try action.decodeRecord(as: type, decoder: PostgrestClient.Configuration.jsonDecoder)
      callback(dto)
    } catch {
      debugLog.error("Failed to decode \(String(describing: type))", error: error)
    }
  }

  private func handleDelete(_ action: DeleteAction, _ callback: (UUID) -> Void) {
    if let id = extractUUID(from: action.oldRecord, key: "id") {
      callback(id)
    } else {
      debugLog.error("Failed to extract UUID from delete event, record: \(action.oldRecord)")
    }
  }

  /// Start retry loop with exponential backoff.
  /// Uses RetryPolicy constants: 1s, 2s, 4s, 8s, 16s, capped at 30s.
  /// After maxRetries (5), enters degraded state but continues background retries.
  private func startRetryLoop(useBroadcastRealtime: Bool) {
    // Cancel any existing retry task
    retryTask?.cancel()
    retryTask = Task { [weak self] in
      guard let self else { return }
      await performRetryLoop(useBroadcastRealtime: useBroadcastRealtime)
    }
  }

  private func performRetryLoop(useBroadcastRealtime: Bool) async {
    // Skip retries in test mode for deterministic behavior
    if mode == .test { return }

    while !Task.isCancelled {
      retryAttempt += 1
      let maxAttempts = RetryPolicy.maxRetries

      if retryAttempt <= maxAttempts {
        // Still within retry limit - show reconnecting state
        updateConnectionState(.reconnecting(attempt: retryAttempt, maxAttempts: maxAttempts))
      } else if retryAttempt == maxAttempts + 1 {
        // Just exceeded limit - transition to degraded
        updateConnectionState(.degraded)
      }
      // If already degraded, continue background retries silently

      // Calculate delay: 1s, 2s, 4s, 8s, 16s, capped at 30s
      let delay = RetryPolicy.delay(for: retryAttempt - 1)
      debugLog.log(
        "Realtime retry attempt \(retryAttempt), delay: \(delay)s",
        category: .sync
      )

      do {
        try await Task.sleep(for: .seconds(delay))
      } catch {
        // Task was cancelled - exit retry loop
        debugLog.log("Realtime retry loop cancelled during sleep", category: .sync)
        return
      }

      // Attempt reconnection
      let success = await attemptReconnection(useBroadcastRealtime: useBroadcastRealtime)
      if success {
        // Success - reset state and exit retry loop
        retryAttempt = 0
        updateConnectionState(.connected)
        debugLog.log("Realtime reconnection successful", category: .sync)
        return
      }
    }
  }

  /// Attempt a single reconnection. Returns true on success.
  /// Simplified to avoid race conditions from subscribe/unsubscribe dance.
  private func attemptReconnection(useBroadcastRealtime: Bool) async -> Bool {
    await startListening(useBroadcastRealtime: useBroadcastRealtime)
    return isListening
  }

  private func updateConnectionState(_ newState: RealtimeConnectionState) {
    connectionState = newState
    delegate?.lifecycleManager(self, connectionStateDidChange: newState)
  }
}
