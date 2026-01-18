//
//  RealtimeManager.swift
//  Dispatch
//
//  Coordinator for Supabase realtime - delegates to BroadcastEventParser and ChannelLifecycleManager.
//

import Foundation
import PostgREST
import Supabase
import SwiftData

// MARK: - RealtimeManagerDelegate

/// Delegate protocol for RealtimeManager to notify of incoming changes.
@MainActor
protocol RealtimeManagerDelegate: AnyObject {
  var currentUserID: UUID? { get }
  var modelContainer: ModelContainer? { get }

  func realtimeManager(_ manager: RealtimeManager, didReceiveTaskDTO dto: TaskDTO)
  func realtimeManager(_ manager: RealtimeManager, didReceiveActivityDTO dto: ActivityDTO)
  func realtimeManager(_ manager: RealtimeManager, didReceiveListingDTO dto: ListingDTO)
  func realtimeManager(_ manager: RealtimeManager, didReceiveUserDTO dto: UserDTO)
  func realtimeManager(_ manager: RealtimeManager, didReceiveNoteDTO dto: NoteDTO)
  func realtimeManager(_ manager: RealtimeManager, didReceiveDeleteFor table: BroadcastTable, id: UUID)
  func realtimeManager(_ manager: RealtimeManager, statusDidChange status: SyncStatus)
  func realtimeManager(_ manager: RealtimeManager, isInFlightTaskId id: UUID) -> Bool
  func realtimeManager(_ manager: RealtimeManager, isInFlightActivityId id: UUID) -> Bool
  func realtimeManager(_ manager: RealtimeManager, isInFlightNoteId id: UUID) -> Bool
}

// MARK: - RealtimeManager

/// Coordinates Supabase realtime channel subscriptions and event routing.
@MainActor
final class RealtimeManager {

  // MARK: Lifecycle

  init(mode: SyncRunMode = .live) {
    self.mode = mode
    channelLifecycleManager = ChannelLifecycleManager(mode: mode)
    broadcastEventParser = BroadcastEventParser()
    channelLifecycleManager.delegate = self
    broadcastEventParser.delegate = self
  }

  // MARK: Internal

  nonisolated let mode: SyncRunMode
  weak var delegate: RealtimeManagerDelegate?
  let useBroadcastRealtime = true
  private(set) var broadcastChannel: RealtimeChannelV2?
  var broadcastTask: Task<Void, Never>?
  var startBroadcastListeningTask: Task<Void, Never>?

  var realtimeChannel: RealtimeChannelV2? { channelLifecycleManager.realtimeChannel }
  var isListening: Bool { channelLifecycleManager.isListening }
  // Task reference forwarding (for testing/shutdown verification)
  var statusTask: Task<Void, Never>? { channelLifecycleManager.statusTask }
  var tasksSubscriptionTask: Task<Void, Never>? { channelLifecycleManager.tasksSubscriptionTask }
  var activitiesSubscriptionTask: Task<Void, Never>? { channelLifecycleManager.activitiesSubscriptionTask }
  var listingsSubscriptionTask: Task<Void, Never>? { channelLifecycleManager.listingsSubscriptionTask }
  var usersSubscriptionTask: Task<Void, Never>? { channelLifecycleManager.usersSubscriptionTask }
  var notesSubscriptionTask: Task<Void, Never>? { channelLifecycleManager.notesSubscriptionTask }

  func startListening() async {
    if mode == .preview || mode == .test { return }
    guard delegate?.currentUserID != nil, delegate?.modelContainer != nil else { return }
    await channelLifecycleManager.startListening(useBroadcastRealtime: useBroadcastRealtime)
  }

  func stopListening() async {
    await channelLifecycleManager.stopListening()
    if let channel = broadcastChannel { await channel.unsubscribe() }
    broadcastChannel = nil
  }

  func cancelAllTasks() {
    channelLifecycleManager.cancelAllTasks()
    broadcastTask?.cancel()
    startBroadcastListeningTask?.cancel()
  }

  func awaitAllTasks() async {
    await channelLifecycleManager.awaitAllTasks()
    _ = await broadcastTask?.result
    _ = await startBroadcastListeningTask?.result
  }

  func clearTaskReferences() {
    channelLifecycleManager.clearTaskReferences()
    broadcastTask = nil
    startBroadcastListeningTask = nil
  }

  func mapRealtimeStatus(_ status: RealtimeChannelStatus) -> SyncStatus {
    channelLifecycleManager.mapRealtimeStatus(status)
  }

  func extractUUID(from record: [String: AnyJSON], key: String) -> UUID? {
    channelLifecycleManager.extractUUID(from: record, key: key)
  }

  // MARK: Private

  private let channelLifecycleManager: ChannelLifecycleManager
  private let broadcastEventParser: BroadcastEventParser

  private func startBroadcastListening() async {
    guard
      useBroadcastRealtime,
      delegate?.currentUserID != nil,
      delegate?.modelContainer != nil
    else { return }

    await supabase.realtimeV2.setAuth()

    let channel = supabase.realtimeV2.channel("dispatch:broadcast") {
      $0.broadcast.receiveOwnBroadcasts = true
    }
    let broadcastStream = channel.broadcastStream(event: "*")

    do {
      try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask { try await channel.subscribeWithError() }
        group.addTask {
          try await Task.sleep(for: .seconds(10))
          throw NSError(
            domain: "Broadcast",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Subscription timed out"]
          )
        }
        try await group.next()
        group.cancelAll()
      }
    } catch {
      debugLog.error("Broadcast subscription failed", error: error)
      return
    }

    broadcastChannel = channel

    broadcastTask = Task { [weak self] in
      guard let self else { return }
      for await event in broadcastStream {
        if Task.isCancelled { break }
        await broadcastEventParser.handleBroadcastEvent(event)
        if let container = delegate?.modelContainer {
          try? container.mainContext.save()
        }
      }
    }
  }
}

// MARK: ChannelLifecycleDelegate

extension RealtimeManager: ChannelLifecycleDelegate {
  func lifecycleManager(_: ChannelLifecycleManager, statusDidChange s: SyncStatus) {
    delegate?.realtimeManager(self, statusDidChange: s)
  }

  func lifecycleManager(_: ChannelLifecycleManager, didReceiveTaskDTO dto: TaskDTO) {
    delegate?.realtimeManager(self, didReceiveTaskDTO: dto)
  }

  func lifecycleManager(_: ChannelLifecycleManager, didReceiveTaskDelete id: UUID) {
    delegate?.realtimeManager(self, didReceiveDeleteFor: .tasks, id: id)
  }

  func lifecycleManager(_: ChannelLifecycleManager, didReceiveActivityDTO dto: ActivityDTO) {
    delegate?.realtimeManager(self, didReceiveActivityDTO: dto)
  }

  func lifecycleManager(_: ChannelLifecycleManager, didReceiveActivityDelete id: UUID) {
    delegate?.realtimeManager(self, didReceiveDeleteFor: .activities, id: id)
  }

  func lifecycleManager(_: ChannelLifecycleManager, didReceiveListingDTO dto: ListingDTO) {
    delegate?.realtimeManager(self, didReceiveListingDTO: dto)
  }

  func lifecycleManager(_: ChannelLifecycleManager, didReceiveListingDelete id: UUID) {
    delegate?.realtimeManager(self, didReceiveDeleteFor: .listings, id: id)
  }

  func lifecycleManager(_: ChannelLifecycleManager, didReceiveUserDTO dto: UserDTO) {
    delegate?.realtimeManager(self, didReceiveUserDTO: dto)
  }

  func lifecycleManager(_: ChannelLifecycleManager, didReceiveUserDelete id: UUID) {
    delegate?.realtimeManager(self, didReceiveDeleteFor: .users, id: id)
  }

  func lifecycleManager(_: ChannelLifecycleManager, didReceiveNoteDTO dto: NoteDTO) {
    delegate?.realtimeManager(self, didReceiveNoteDTO: dto)
  }

  func lifecycleManager(_: ChannelLifecycleManager, didReceiveNoteDelete id: UUID) {
    delegate?.realtimeManager(self, didReceiveDeleteFor: .notes, id: id)
  }

  func lifecycleManagerDidRequestBroadcastStart(_: ChannelLifecycleManager) {
    startBroadcastListeningTask = Task { [weak self] in await self?.startBroadcastListening() }
  }
}

// MARK: BroadcastEventParserDelegate

extension RealtimeManager: BroadcastEventParserDelegate {
  var currentUserID: UUID? { delegate?.currentUserID }

  func isInFlightTaskId(_ id: UUID) -> Bool {
    delegate?.realtimeManager(self, isInFlightTaskId: id) ?? false
  }

  func isInFlightActivityId(_ id: UUID) -> Bool {
    delegate?.realtimeManager(self, isInFlightActivityId: id) ?? false
  }

  func isInFlightNoteId(_ id: UUID) -> Bool {
    delegate?.realtimeManager(self, isInFlightNoteId: id) ?? false
  }

  func parser(_: BroadcastEventParser, didReceiveTaskDTO dto: TaskDTO) {
    delegate?.realtimeManager(self, didReceiveTaskDTO: dto)
  }

  func parser(_: BroadcastEventParser, didReceiveActivityDTO dto: ActivityDTO) {
    delegate?.realtimeManager(self, didReceiveActivityDTO: dto)
  }

  func parser(_: BroadcastEventParser, didReceiveListingDTO dto: ListingDTO) {
    delegate?.realtimeManager(self, didReceiveListingDTO: dto)
  }

  func parser(_: BroadcastEventParser, didReceiveUserDTO dto: UserDTO) {
    delegate?.realtimeManager(self, didReceiveUserDTO: dto)
  }

  func parser(_: BroadcastEventParser, didReceiveNoteDTO dto: NoteDTO) {
    delegate?.realtimeManager(self, didReceiveNoteDTO: dto)
  }

  func parser(_: BroadcastEventParser, didReceiveDeleteFor table: BroadcastTable, id: UUID) {
    delegate?.realtimeManager(self, didReceiveDeleteFor: table, id: id)
  }
}
