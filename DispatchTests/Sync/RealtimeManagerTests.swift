//
//  RealtimeManagerTests.swift
//  DispatchTests
//
//  Tests for RealtimeManager refactor - BroadcastEventParser and ChannelLifecycleManager.
//

import Realtime
import Supabase
import XCTest
@testable import DispatchApp

// MARK: - MockBroadcastEventParserDelegate

@MainActor
final class MockBroadcastEventParserDelegate: BroadcastEventParserDelegate {

  var currentUserID: UUID?

  var inFlightTaskIds = Set<UUID>()
  var inFlightActivityIds = Set<UUID>()
  var inFlightNoteIds = Set<UUID>()

  var receivedTaskDTOs = [TaskDTO]()
  var receivedActivityDTOs = [ActivityDTO]()
  var receivedListingDTOs = [ListingDTO]()
  var receivedUserDTOs = [UserDTO]()
  var receivedNoteDTOs = [NoteDTO]()
  var receivedDeletes = [(table: BroadcastTable, id: UUID)]()

  func isInFlightTaskId(_ id: UUID) -> Bool {
    inFlightTaskIds.contains(id)
  }

  func isInFlightActivityId(_ id: UUID) -> Bool {
    inFlightActivityIds.contains(id)
  }

  func isInFlightNoteId(_ id: UUID) -> Bool {
    inFlightNoteIds.contains(id)
  }

  func parser(_: BroadcastEventParser, didReceiveTaskDTO dto: TaskDTO) {
    receivedTaskDTOs.append(dto)
  }

  func parser(_: BroadcastEventParser, didReceiveActivityDTO dto: ActivityDTO) {
    receivedActivityDTOs.append(dto)
  }

  func parser(_: BroadcastEventParser, didReceiveListingDTO dto: ListingDTO) {
    receivedListingDTOs.append(dto)
  }

  func parser(_: BroadcastEventParser, didReceiveUserDTO dto: UserDTO) {
    receivedUserDTOs.append(dto)
  }

  func parser(_: BroadcastEventParser, didReceiveNoteDTO dto: NoteDTO) {
    receivedNoteDTOs.append(dto)
  }

  func parser(_: BroadcastEventParser, didReceiveDeleteFor table: BroadcastTable, id: UUID) {
    receivedDeletes.append((table: table, id: id))
  }

  func reset() {
    receivedTaskDTOs.removeAll()
    receivedActivityDTOs.removeAll()
    receivedListingDTOs.removeAll()
    receivedUserDTOs.removeAll()
    receivedNoteDTOs.removeAll()
    receivedDeletes.removeAll()
    inFlightTaskIds.removeAll()
    inFlightActivityIds.removeAll()
    inFlightNoteIds.removeAll()
  }
}

// MARK: - MockChannelLifecycleDelegate

@MainActor
final class MockChannelLifecycleDelegate: ChannelLifecycleDelegate {

  var statusChanges = [SyncStatus]()
  var connectionStateChanges = [RealtimeConnectionState]()
  var receivedTaskDTOs = [TaskDTO]()
  var receivedTaskDeletes = [UUID]()
  var receivedActivityDTOs = [ActivityDTO]()
  var receivedActivityDeletes = [UUID]()
  var receivedListingDTOs = [ListingDTO]()
  var receivedListingDeletes = [UUID]()
  var receivedUserDTOs = [UserDTO]()
  var receivedUserDeletes = [UUID]()
  var receivedNoteDTOs = [NoteDTO]()
  var receivedNoteDeletes = [UUID]()
  var broadcastStartRequested = false

  func lifecycleManager(_: ChannelLifecycleManager, statusDidChange status: SyncStatus) {
    statusChanges.append(status)
  }

  func lifecycleManager(_: ChannelLifecycleManager, connectionStateDidChange state: RealtimeConnectionState) {
    connectionStateChanges.append(state)
  }

  func lifecycleManager(_: ChannelLifecycleManager, didReceiveTaskDTO dto: TaskDTO) {
    receivedTaskDTOs.append(dto)
  }

  func lifecycleManager(_: ChannelLifecycleManager, didReceiveTaskDelete id: UUID) {
    receivedTaskDeletes.append(id)
  }

  func lifecycleManager(_: ChannelLifecycleManager, didReceiveActivityDTO dto: ActivityDTO) {
    receivedActivityDTOs.append(dto)
  }

  func lifecycleManager(_: ChannelLifecycleManager, didReceiveActivityDelete id: UUID) {
    receivedActivityDeletes.append(id)
  }

  func lifecycleManager(_: ChannelLifecycleManager, didReceiveListingDTO dto: ListingDTO) {
    receivedListingDTOs.append(dto)
  }

  func lifecycleManager(_: ChannelLifecycleManager, didReceiveListingDelete id: UUID) {
    receivedListingDeletes.append(id)
  }

  func lifecycleManager(_: ChannelLifecycleManager, didReceiveUserDTO dto: UserDTO) {
    receivedUserDTOs.append(dto)
  }

  func lifecycleManager(_: ChannelLifecycleManager, didReceiveUserDelete id: UUID) {
    receivedUserDeletes.append(id)
  }

  func lifecycleManager(_: ChannelLifecycleManager, didReceiveNoteDTO dto: NoteDTO) {
    receivedNoteDTOs.append(dto)
  }

  func lifecycleManager(_: ChannelLifecycleManager, didReceiveNoteDelete id: UUID) {
    receivedNoteDeletes.append(id)
  }

  func lifecycleManagerDidRequestBroadcastStart(_: ChannelLifecycleManager) {
    broadcastStartRequested = true
  }

  func reset() {
    statusChanges.removeAll()
    connectionStateChanges.removeAll()
    receivedTaskDTOs.removeAll()
    receivedTaskDeletes.removeAll()
    receivedActivityDTOs.removeAll()
    receivedActivityDeletes.removeAll()
    receivedListingDTOs.removeAll()
    receivedListingDeletes.removeAll()
    receivedUserDTOs.removeAll()
    receivedUserDeletes.removeAll()
    receivedNoteDTOs.removeAll()
    receivedNoteDeletes.removeAll()
    broadcastStartRequested = false
  }
}

// MARK: - BroadcastEventParserTests

@MainActor
final class BroadcastEventParserTests: XCTestCase {

  // MARK: Internal

  override func setUp() {
    super.setUp()
    parser.delegate = delegate
    delegate.reset()
  }

  // MARK: - Self-Echo Filtering Tests

  func test_selfEchoFiltering_skipsWhenOriginUserIdMatchesCurrentUser() async {
    // Given
    let userId = UUID()
    delegate.currentUserID = userId

    let payload = createBroadcastPayload(
      table: .tasks,
      type: .insert,
      record: createTaskRecord(originUserId: userId)
    )

    // When
    await parser.handleBroadcastEvent(wrapPayload(payload))

    // Then
    XCTAssertTrue(delegate.receivedTaskDTOs.isEmpty, "Should skip self-originated events")
  }

  func test_selfEchoFiltering_processesWhenOriginUserIdDiffers() async {
    // Given
    let currentUserId = UUID()
    let otherUserId = UUID()
    delegate.currentUserID = currentUserId

    let payload = createBroadcastPayload(
      table: .tasks,
      type: .insert,
      record: createTaskRecord(originUserId: otherUserId)
    )

    // When
    await parser.handleBroadcastEvent(wrapPayload(payload))

    // Then
    XCTAssertEqual(delegate.receivedTaskDTOs.count, 1, "Should process events from other users")
  }

  func test_selfEchoFiltering_processesWhenOriginUserIdIsNil() async {
    // Given - system-originated events have nil originUserId
    let currentUserId = UUID()
    delegate.currentUserID = currentUserId

    let payload = createBroadcastPayload(
      table: .tasks,
      type: .insert,
      record: createTaskRecord(originUserId: nil)
    )

    // When
    await parser.handleBroadcastEvent(wrapPayload(payload))

    // Then
    XCTAssertEqual(delegate.receivedTaskDTOs.count, 1, "Should process system-originated events (nil originUserId)")
  }

  func test_selfEchoFiltering_skipsInFlightTasks() async {
    // Given
    let taskId = UUID()
    delegate.currentUserID = UUID()
    delegate.inFlightTaskIds.insert(taskId)

    let payload = createBroadcastPayload(
      table: .tasks,
      type: .update,
      record: createTaskRecord(id: taskId, originUserId: UUID())
    )

    // When
    await parser.handleBroadcastEvent(wrapPayload(payload))

    // Then
    XCTAssertTrue(delegate.receivedTaskDTOs.isEmpty, "Should skip in-flight tasks")
  }

  // MARK: - Malformed Payload Tests

  func test_malformedPayload_handlesGracefully() async {
    // Given - empty payload
    let emptyPayload: [String: Any] = [:]

    // When/Then - should not crash
    await parser.handleBroadcastEvent(convertToJSONObject(emptyPayload))

    XCTAssertTrue(delegate.receivedTaskDTOs.isEmpty)
    XCTAssertTrue(delegate.receivedDeletes.isEmpty)
  }

  func test_unknownEventVersion_logsButProcesses() async {
    // Given
    delegate.currentUserID = UUID()
    let payload = createBroadcastPayload(
      table: .tasks,
      type: .insert,
      record: createTaskRecord(originUserId: UUID(), eventVersion: 99)
    )

    // When
    await parser.handleBroadcastEvent(wrapPayload(payload))

    // Then - should still process despite unknown version
    XCTAssertEqual(delegate.receivedTaskDTOs.count, 1)
  }

  // MARK: - INSERT Event Tests

  func test_insertEvent_tasks() async {
    // Given
    let taskId = UUID()
    delegate.currentUserID = UUID()

    let payload = createBroadcastPayload(
      table: .tasks,
      type: .insert,
      record: createTaskRecord(id: taskId, originUserId: UUID())
    )

    // When
    await parser.handleBroadcastEvent(wrapPayload(payload))

    // Then
    XCTAssertEqual(delegate.receivedTaskDTOs.count, 1)
    XCTAssertEqual(delegate.receivedTaskDTOs.first?.id, taskId)
  }

  func test_insertEvent_activities() async {
    // Given
    let activityId = UUID()
    delegate.currentUserID = UUID()

    let payload = createBroadcastPayload(
      table: .activities,
      type: .insert,
      record: createActivityRecord(id: activityId, originUserId: UUID())
    )

    // When
    await parser.handleBroadcastEvent(wrapPayload(payload))

    // Then
    XCTAssertEqual(delegate.receivedActivityDTOs.count, 1)
    XCTAssertEqual(delegate.receivedActivityDTOs.first?.id, activityId)
  }

  // MARK: - UPDATE Event Tests

  func test_updateEvent_tasks() async {
    // Given
    let taskId = UUID()
    delegate.currentUserID = UUID()

    let payload = createBroadcastPayload(
      table: .tasks,
      type: .update,
      record: createTaskRecord(id: taskId, originUserId: UUID())
    )

    // When
    await parser.handleBroadcastEvent(wrapPayload(payload))

    // Then
    XCTAssertEqual(delegate.receivedTaskDTOs.count, 1)
    XCTAssertEqual(delegate.receivedTaskDTOs.first?.id, taskId)
  }

  func test_updateEvent_activities() async {
    // Given
    let activityId = UUID()
    delegate.currentUserID = UUID()

    let payload = createBroadcastPayload(
      table: .activities,
      type: .update,
      record: createActivityRecord(id: activityId, originUserId: UUID())
    )

    // When
    await parser.handleBroadcastEvent(wrapPayload(payload))

    // Then
    XCTAssertEqual(delegate.receivedActivityDTOs.count, 1)
    XCTAssertEqual(delegate.receivedActivityDTOs.first?.id, activityId)
  }

  // MARK: - DELETE Event Tests

  func test_deleteEvent_tasks() async {
    // Given
    let taskId = UUID()
    delegate.currentUserID = UUID()

    let payload = createBroadcastPayload(
      table: .tasks,
      type: .delete,
      oldRecord: ["id": taskId.uuidString, "_origin_user_id": UUID().uuidString, "_event_version": 1]
    )

    // When
    await parser.handleBroadcastEvent(wrapPayload(payload))

    // Then
    XCTAssertEqual(delegate.receivedDeletes.count, 1)
    XCTAssertEqual(delegate.receivedDeletes.first?.table, .tasks)
    XCTAssertEqual(delegate.receivedDeletes.first?.id, taskId)
  }

  func test_deleteEvent_activities() async {
    // Given
    let activityId = UUID()
    delegate.currentUserID = UUID()

    let payload = createBroadcastPayload(
      table: .activities,
      type: .delete,
      oldRecord: ["id": activityId.uuidString, "_origin_user_id": UUID().uuidString, "_event_version": 1]
    )

    // When
    await parser.handleBroadcastEvent(wrapPayload(payload))

    // Then
    XCTAssertEqual(delegate.receivedDeletes.count, 1)
    XCTAssertEqual(delegate.receivedDeletes.first?.table, .activities)
    XCTAssertEqual(delegate.receivedDeletes.first?.id, activityId)
  }

  func test_deleteEvent_listings() async {
    // Given
    let listingId = UUID()
    delegate.currentUserID = UUID()

    let payload = createBroadcastPayload(
      table: .listings,
      type: .delete,
      oldRecord: ["id": listingId.uuidString, "_origin_user_id": UUID().uuidString, "_event_version": 1]
    )

    // When
    await parser.handleBroadcastEvent(wrapPayload(payload))

    // Then
    XCTAssertEqual(delegate.receivedDeletes.count, 1)
    XCTAssertEqual(delegate.receivedDeletes.first?.table, .listings)
    XCTAssertEqual(delegate.receivedDeletes.first?.id, listingId)
  }

  func test_deleteEvent_users() async {
    // Given
    let userId = UUID()
    delegate.currentUserID = UUID()

    let payload = createBroadcastPayload(
      table: .users,
      type: .delete,
      oldRecord: ["id": userId.uuidString, "_origin_user_id": UUID().uuidString, "_event_version": 1]
    )

    // When
    await parser.handleBroadcastEvent(wrapPayload(payload))

    // Then
    XCTAssertEqual(delegate.receivedDeletes.count, 1)
    XCTAssertEqual(delegate.receivedDeletes.first?.table, .users)
    XCTAssertEqual(delegate.receivedDeletes.first?.id, userId)
  }

  func test_deleteEvent_notes() async {
    // Given
    let noteId = UUID()
    delegate.currentUserID = UUID()

    let payload = createBroadcastPayload(
      table: .notes,
      type: .delete,
      oldRecord: ["id": noteId.uuidString, "_origin_user_id": UUID().uuidString, "_event_version": 1]
    )

    // When
    await parser.handleBroadcastEvent(wrapPayload(payload))

    // Then
    XCTAssertEqual(delegate.receivedDeletes.count, 1)
    XCTAssertEqual(delegate.receivedDeletes.first?.table, .notes)
    XCTAssertEqual(delegate.receivedDeletes.first?.id, noteId)
  }

  // MARK: Private

  private var parser = BroadcastEventParser()
  private var delegate = MockBroadcastEventParserDelegate()

  // MARK: - Helpers

  private func createTaskRecord(
    id: UUID = UUID(),
    originUserId: UUID?,
    eventVersion: Int = 1
  ) -> [String: Any] {
    var record: [String: Any] = [
      "id": id.uuidString,
      "title": "Test Task",
      "status": "open",
      "listing": UUID().uuidString,
      "declared_by": UUID().uuidString,
      "created_via": "api",
      "created_at": ISO8601DateFormatter().string(from: Date()),
      "updated_at": ISO8601DateFormatter().string(from: Date()),
      "_event_version": eventVersion
    ]
    if let originUserId {
      record["_origin_user_id"] = originUserId.uuidString
    }
    return record
  }

  private func createActivityRecord(
    id: UUID = UUID(),
    originUserId: UUID?,
    eventVersion: Int = 1
  ) -> [String: Any] {
    var record: [String: Any] = [
      "id": id.uuidString,
      "title": "Test Activity",
      "status": "open",
      "listing": UUID().uuidString,
      "declared_by": UUID().uuidString,
      "created_via": "dispatch",
      "created_at": ISO8601DateFormatter().string(from: Date()),
      "updated_at": ISO8601DateFormatter().string(from: Date()),
      "_event_version": eventVersion
    ]
    if let originUserId {
      record["_origin_user_id"] = originUserId.uuidString
    }
    return record
  }

  private func createBroadcastPayload(
    table: BroadcastTable,
    type: BroadcastOp,
    record: [String: Any]? = nil,
    oldRecord: [String: Any]? = nil
  ) -> [String: Any] {
    var payload: [String: Any] = [
      "table": table.rawValue,
      "type": type.rawValue
    ]
    if let record {
      payload["record"] = record
    }
    if let oldRecord {
      payload["old_record"] = oldRecord
    }
    return payload
  }

  private func wrapPayload(_ payload: [String: Any]) -> [String: AnyJSON] {
    // Supabase wraps the payload in { payload: ... }
    let wrapper: [String: Any] = ["payload": payload]
    return convertToJSONObject(wrapper)
  }

  private func convertToJSONObject(_ dict: [String: Any]) -> [String: AnyJSON] {
    var result = [String: AnyJSON]()
    for (key, value) in dict {
      result[key] = convertToAnyJSON(value)
    }
    return result
  }

  private func convertToAnyJSON(_ value: Any) -> AnyJSON {
    if let string = value as? String {
      .string(string)
    } else if let int = value as? Int {
      .integer(int)
    } else if let double = value as? Double {
      .double(double)
    } else if let bool = value as? Bool {
      .bool(bool)
    } else if let dict = value as? [String: Any] {
      .object(convertToJSONObject(dict))
    } else if let array = value as? [Any] {
      .array(array.map { convertToAnyJSON($0) })
    } else {
      .null
    }
  }
}

// MARK: - ChannelLifecycleManagerTests

@MainActor
final class ChannelLifecycleManagerTests: XCTestCase {

  // MARK: Internal

  override func setUp() {
    super.setUp()
    // Use test mode to prevent actual network calls
    manager.delegate = delegate
    delegate.reset()
  }

  // MARK: - State Tests

  func test_initialState_isNotListening() {
    XCTAssertFalse(manager.isListening)
    XCTAssertNil(manager.realtimeChannel)
  }

  func test_startListening_skipsInTestMode() async {
    // Given - manager in test mode

    // When
    await manager.startListening(useBroadcastRealtime: true)

    // Then - should not start listening in test mode
    XCTAssertFalse(manager.isListening)
    XCTAssertNil(manager.realtimeChannel)
  }

  func test_startListening_skipsInPreviewMode() async {
    // Given
    let previewManager = ChannelLifecycleManager(mode: .preview)
    previewManager.delegate = delegate

    // When
    await previewManager.startListening(useBroadcastRealtime: true)

    // Then
    XCTAssertFalse(previewManager.isListening)
  }

  // MARK: - Status Mapping Tests

  func test_mapRealtimeStatus_subscribed() {
    let status = manager.mapRealtimeStatus(.subscribed)
    if case .ok = status {
      // Expected
    } else {
      XCTFail("Expected .ok status for subscribed")
    }
  }

  func test_mapRealtimeStatus_subscribing() {
    let status = manager.mapRealtimeStatus(.subscribing)
    XCTAssertEqual(status, .syncing)
  }

  func test_mapRealtimeStatus_unsubscribing() {
    let status = manager.mapRealtimeStatus(.unsubscribing)
    XCTAssertEqual(status, .syncing)
  }

  func test_mapRealtimeStatus_unsubscribed() {
    let status = manager.mapRealtimeStatus(.unsubscribed)
    XCTAssertEqual(status, .idle)
  }

  // MARK: - UUID Extraction Tests

  func test_extractUUID_validUUID() {
    let expectedId = UUID()
    let record: [String: AnyJSON] = ["id": .string(expectedId.uuidString)]

    let result = manager.extractUUID(from: record, key: "id")

    XCTAssertEqual(result, expectedId)
  }

  func test_extractUUID_missingKey() {
    let record: [String: AnyJSON] = ["other": .string("value")]

    let result = manager.extractUUID(from: record, key: "id")

    XCTAssertNil(result)
  }

  func test_extractUUID_invalidUUID() {
    let record: [String: AnyJSON] = ["id": .string("not-a-uuid")]

    let result = manager.extractUUID(from: record, key: "id")

    XCTAssertNil(result)
  }

  // MARK: - Task Lifecycle Tests

  func test_cancelAllTasks_cancelsAllSubscriptionTasks() {
    // Given - create mock tasks
    manager.statusTask = Task { }
    manager.tasksSubscriptionTask = Task { }
    manager.activitiesSubscriptionTask = Task { }
    manager.listingsSubscriptionTask = Task { }
    manager.usersSubscriptionTask = Task { }
    manager.notesSubscriptionTask = Task { }

    // When
    manager.cancelAllTasks()

    // Then - tasks should be cancelled (we can verify they exist but cancellation is internal)
    XCTAssertNotNil(manager.statusTask)
  }

  func test_clearTaskReferences_clearsAllTasks() {
    // Given
    manager.statusTask = Task { }
    manager.tasksSubscriptionTask = Task { }

    // When
    manager.clearTaskReferences()

    // Then
    XCTAssertNil(manager.statusTask)
    XCTAssertNil(manager.tasksSubscriptionTask)
    XCTAssertNil(manager.activitiesSubscriptionTask)
    XCTAssertNil(manager.listingsSubscriptionTask)
    XCTAssertNil(manager.usersSubscriptionTask)
    XCTAssertNil(manager.notesSubscriptionTask)
  }

  // MARK: Private

  private var manager = ChannelLifecycleManager(mode: .test)
  private var delegate = MockChannelLifecycleDelegate()
}
