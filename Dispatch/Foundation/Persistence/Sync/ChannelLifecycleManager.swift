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
      return
    }

    // Status monitoring
    statusTask = Task { [weak self] in
      for await status in channel.statusChange {
        if Task.isCancelled { return }
        await MainActor.run {
          guard let self else { return }
          delegate?.lifecycleManager(self, statusDidChange: mapRealtimeStatus(status))
        }
      }
    }

    // Tasks
    tasksSubscriptionTask = Task { [weak self] in
      guard let self else { return }
      await withTaskGroup(of: Void.self) { group in
        group.addTask { for await a in tasksIns { if Task.isCancelled { return }
          await self.handleDTO(a, TaskDTO.self) { self.delegate?.lifecycleManager(self, didReceiveTaskDTO: $0) }
        } }
        group.addTask { for await a in tasksUpd { if Task.isCancelled { return }
          await self.handleDTO(a, TaskDTO.self) { self.delegate?.lifecycleManager(self, didReceiveTaskDTO: $0) }
        } }
        group.addTask { for await a in tasksDel { if Task.isCancelled { return }
          await self.handleDelete(a) { self.delegate?.lifecycleManager(self, didReceiveTaskDelete: $0) }
        } }
      }
    }

    // Activities
    activitiesSubscriptionTask = Task { [weak self] in
      guard let self else { return }
      await withTaskGroup(of: Void.self) { group in
        group.addTask { for await a in actIns { if Task.isCancelled { return }
          await self.handleDTO(a, ActivityDTO.self) { self.delegate?.lifecycleManager(self, didReceiveActivityDTO: $0) }
        } }
        group.addTask { for await a in actUpd { if Task.isCancelled { return }
          await self.handleDTO(a, ActivityDTO.self) { self.delegate?.lifecycleManager(self, didReceiveActivityDTO: $0) }
        } }
        group.addTask { for await a in actDel { if Task.isCancelled { return }
          await self.handleDelete(a) { self.delegate?.lifecycleManager(self, didReceiveActivityDelete: $0) }
        } }
      }
    }

    // Listings
    listingsSubscriptionTask = Task { [weak self] in
      guard let self else { return }
      await withTaskGroup(of: Void.self) { group in
        group.addTask { for await a in listIns { if Task.isCancelled { return }
          await self.handleDTO(a, ListingDTO.self) { self.delegate?.lifecycleManager(self, didReceiveListingDTO: $0) }
        } }
        group.addTask { for await a in listUpd { if Task.isCancelled { return }
          await self.handleDTO(a, ListingDTO.self) { self.delegate?.lifecycleManager(self, didReceiveListingDTO: $0) }
        } }
        group.addTask { for await a in listDel { if Task.isCancelled { return }
          await self.handleDelete(a) { self.delegate?.lifecycleManager(self, didReceiveListingDelete: $0) }
        } }
      }
    }

    // Users
    usersSubscriptionTask = Task { [weak self] in
      guard let self else { return }
      await withTaskGroup(of: Void.self) { group in
        group.addTask { for await a in usersIns { if Task.isCancelled { return }
          await self.handleDTO(a, UserDTO.self) { self.delegate?.lifecycleManager(self, didReceiveUserDTO: $0) }
        } }
        group.addTask { for await a in usersUpd { if Task.isCancelled { return }
          await self.handleDTO(a, UserDTO.self) { self.delegate?.lifecycleManager(self, didReceiveUserDTO: $0) }
        } }
        group.addTask { for await a in usersDel { if Task.isCancelled { return }
          await self.handleDelete(a) { self.delegate?.lifecycleManager(self, didReceiveUserDelete: $0) }
        } }
      }
    }

    // Notes
    notesSubscriptionTask = Task { [weak self] in
      guard let self else { return }
      await withTaskGroup(of: Void.self) { group in
        group.addTask { for await a in noteIns { if Task.isCancelled { return }
          await self.handleDTO(a, NoteDTO.self) { self.delegate?.lifecycleManager(self, didReceiveNoteDTO: $0) }
        } }
        group.addTask { for await a in noteUpd { if Task.isCancelled { return }
          await self.handleDTO(a, NoteDTO.self) { self.delegate?.lifecycleManager(self, didReceiveNoteDTO: $0) }
        } }
        group.addTask { for await a in noteDel { if Task.isCancelled { return }
          await self.handleDelete(a) { self.delegate?.lifecycleManager(self, didReceiveNoteDelete: $0) }
        } }
      }
    }

    if useBroadcastRealtime {
      delegate?.lifecycleManagerDidRequestBroadcastStart(self)
    }
  }

  func stopListening() async {
    if let channel = realtimeChannel { await channel.unsubscribe() }
    realtimeChannel = nil
    isListening = false
  }

  func cancelAllTasks() {
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
    _ = await statusTask?.result
    _ = await tasksSubscriptionTask?.result
    _ = await activitiesSubscriptionTask?.result
    _ = await listingsSubscriptionTask?.result
    _ = await usersSubscriptionTask?.result
    _ = await notesSubscriptionTask?.result
  }

  func clearTaskReferences() {
    statusTask = nil
    tasksSubscriptionTask = nil
    activitiesSubscriptionTask = nil
    listingsSubscriptionTask = nil
    usersSubscriptionTask = nil
    notesSubscriptionTask = nil
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

  private func handleDTO<DTO: Decodable>(_ action: some HasRecord, _ type: DTO.Type, _ callback: @MainActor (DTO) -> Void) async {
    if let dto = try? action.decodeRecord(as: type, decoder: PostgrestClient.Configuration.jsonDecoder) {
      await callback(dto)
    }
  }

  private func handleDelete(_ action: DeleteAction, _ callback: @MainActor (UUID) -> Void) async {
    if let id = extractUUID(from: action.oldRecord, key: "id") {
      await callback(id)
    }
  }
}
