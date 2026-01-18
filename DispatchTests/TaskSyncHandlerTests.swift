//
//  TaskSyncHandlerTests.swift
//  DispatchTests
//
//  Unit tests for TaskSyncHandler entity-specific sync operations.
//  Tests upsertTask and upsertTaskAssignee logic including in-flight and pending protection.
//

import SwiftData
import XCTest
@testable import DispatchApp

// MARK: - TaskSyncHandlerTests

@MainActor
final class TaskSyncHandlerTests: XCTestCase {

  // MARK: Internal

  override func setUp() {
    super.setUp()

    // Create in-memory SwiftData container with ALL required models
    let schema = Schema([
      TaskItem.self,
      TaskAssignee.self,
      Activity.self,
      ActivityAssignee.self,
      Note.self,
      Listing.self,
      User.self,
      ListingTypeDefinition.self,
      ActivityTemplate.self,
      Property.self,
      Subtask.self,
      StatusChange.self
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    // swiftlint:disable:next force_try
    container = try! ModelContainer(for: schema, configurations: [config])
    context = ModelContext(container)

    // Create dependencies for test mode
    conflictResolver = ConflictResolver()
    let deps = SyncHandlerDependencies(
      mode: .test,
      conflictResolver: conflictResolver,
      getCurrentUserID: { nil },
      getCurrentUser: { nil },
      fetchCurrentUser: { _ in },
      updateListingConfigReady: { _ in }
    )
    handler = TaskSyncHandler(dependencies: deps)
  }

  override func tearDown() {
    context = nil
    container = nil
    handler = nil
    conflictResolver = nil
    super.tearDown()
  }

  // MARK: - Initialization Tests

  func test_init_setsModeProperly() {
    XCTAssertEqual(handler.dependencies.mode, .test)
  }

  func test_init_setsConflictResolver() {
    XCTAssertNotNil(handler.dependencies.conflictResolver)
  }

  // MARK: - upsertTask: Insert New Task Tests

  func test_upsertTask_insertsNewTask() throws {
    // Given: A new task DTO that doesn't exist locally
    let taskId = UUID()
    let dto = makeTaskDTO(id: taskId, title: "Test Task")

    // When: Upsert the task
    try handler.upsertTask(dto: dto, context: context)

    // Then: Task should be inserted
    let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == taskId })
    let tasks = try context.fetch(descriptor)
    XCTAssertEqual(tasks.count, 1)
    XCTAssertEqual(tasks.first?.title, "Test Task")
    XCTAssertEqual(tasks.first?.syncState, .synced)
  }

  func test_upsertTask_setsAllFieldsFromDTO() throws {
    // Given: A DTO with all fields populated
    let taskId = UUID()
    let declaredBy = UUID()
    let listingId = UUID()
    let dueDate = Date(timeIntervalSince1970: 1_700_000_000) // Fixed date for reliable comparison
    let dto = makeTaskDTO(
      id: taskId,
      title: "Full Task",
      description: "Task description",
      dueDate: dueDate,
      status: "in_progress",
      declaredBy: declaredBy,
      listing: listingId
    )

    // When: Upsert the task
    try handler.upsertTask(dto: dto, context: context)

    // Then: All fields should be set correctly
    let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == taskId })
    let tasks = try context.fetch(descriptor)
    let task = tasks.first
    XCTAssertNotNil(task)
    XCTAssertEqual(task?.title, "Full Task")
    XCTAssertEqual(task?.taskDescription, "Task description")
    XCTAssertNotNil(task?.dueDate)
    XCTAssertEqual(task?.status, .inProgress)
    XCTAssertEqual(task?.declaredBy, declaredBy)
    XCTAssertEqual(task?.listingId, listingId)
    // Note: completedAt is not passed through TaskDTO.toModel() initializer
    // so it remains nil on insert. This is a known limitation.
  }

  // MARK: - upsertTask: Update Existing Task Tests

  func test_upsertTask_updatesExistingSyncedTask() throws {
    // Given: An existing synced task
    let taskId = UUID()
    let existingTask = makeTask(id: taskId, title: "Old Title")
    existingTask.markSynced()
    context.insert(existingTask)
    try context.save()

    // When: Upsert with new title
    let dto = makeTaskDTO(id: taskId, title: "Updated Title")
    try handler.upsertTask(dto: dto, context: context)

    // Then: Task should be updated
    let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == taskId })
    let tasks = try context.fetch(descriptor)
    XCTAssertEqual(tasks.first?.title, "Updated Title")
    XCTAssertEqual(tasks.first?.syncState, .synced)
  }

  func test_upsertTask_updatesAllFieldsOnExistingTask() throws {
    // Given: An existing synced task with old values
    let taskId = UUID()
    let existingTask = makeTask(id: taskId, title: "Old Title")
    existingTask.taskDescription = "Old description"
    existingTask.status = .open
    existingTask.markSynced()
    context.insert(existingTask)
    try context.save()

    // When: Upsert with all new values
    let newDueDate = Date()
    let newListingId = UUID()
    let dto = makeTaskDTO(
      id: taskId,
      title: "New Title",
      description: "New description",
      dueDate: newDueDate,
      status: "completed",
      listing: newListingId
    )
    try handler.upsertTask(dto: dto, context: context)

    // Then: All fields should be updated
    let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == taskId })
    let tasks = try context.fetch(descriptor)
    let task = tasks.first
    XCTAssertEqual(task?.title, "New Title")
    XCTAssertEqual(task?.taskDescription, "New description")
    XCTAssertEqual(task?.dueDate, newDueDate)
    XCTAssertEqual(task?.status, .completed)
    XCTAssertEqual(task?.listingId, newListingId)
  }

  // MARK: - upsertTask: In-Flight Protection Tests

  func test_upsertTask_skipsInFlightTask() throws {
    // Given: A task that is currently being synced up (in-flight)
    let taskId = UUID()
    let existingTask = makeTask(id: taskId, title: "Local Title")
    existingTask.markSynced()
    context.insert(existingTask)
    try context.save()

    // Mark as in-flight
    conflictResolver.markTasksInFlight([taskId])

    // When: Upsert with remote update while in-flight
    let dto = makeTaskDTO(id: taskId, title: "Remote Title")
    try handler.upsertTask(dto: dto, context: context)

    // Then: Local content should be preserved (in-flight protection)
    let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == taskId })
    let tasks = try context.fetch(descriptor)
    XCTAssertEqual(tasks.first?.title, "Local Title")

    // Cleanup
    conflictResolver.clearTasksInFlight()
  }

  func test_upsertTask_preservesAllFieldsWhenInFlight() throws {
    // Given: An in-flight task with local values
    let taskId = UUID()
    let existingTask = makeTask(id: taskId, title: "Local Title")
    existingTask.taskDescription = "Local description"
    existingTask.status = .inProgress
    existingTask.markSynced()
    context.insert(existingTask)
    try context.save()

    conflictResolver.markTasksInFlight([taskId])

    // When: Upsert with different remote values
    let dto = makeTaskDTO(
      id: taskId,
      title: "Remote Title",
      description: "Remote description",
      status: "completed"
    )
    try handler.upsertTask(dto: dto, context: context)

    // Then: All local values should be preserved
    let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == taskId })
    let tasks = try context.fetch(descriptor)
    let task = tasks.first
    XCTAssertEqual(task?.title, "Local Title")
    XCTAssertEqual(task?.taskDescription, "Local description")
    XCTAssertEqual(task?.status, .inProgress)

    conflictResolver.clearTasksInFlight()
  }

  // MARK: - upsertTask: Pending Protection Tests

  func test_upsertTask_skipsPendingTask() throws {
    // Given: A task with pending local changes
    let taskId = UUID()
    let existingTask = makeTask(id: taskId, title: "Pending Local Edit")
    existingTask.markPending()
    context.insert(existingTask)
    try context.save()

    // When: Upsert with remote update while pending
    let dto = makeTaskDTO(id: taskId, title: "Remote Title")
    try handler.upsertTask(dto: dto, context: context)

    // Then: Local content should be preserved
    let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == taskId })
    let tasks = try context.fetch(descriptor)
    XCTAssertEqual(tasks.first?.title, "Pending Local Edit")
    // Note: TaskItem doesn't have hasRemoteChangeWhilePending like Note does
    // The pending state itself indicates local authority
    XCTAssertEqual(tasks.first?.syncState, .pending)
  }

  func test_upsertTask_skipsFailedTask() throws {
    // Given: A task with failed sync state
    let taskId = UUID()
    let existingTask = makeTask(id: taskId, title: "Failed Local Edit")
    existingTask.markFailed("Network error")
    context.insert(existingTask)
    try context.save()

    // When: Upsert with remote update while failed
    let dto = makeTaskDTO(id: taskId, title: "Remote Title")
    try handler.upsertTask(dto: dto, context: context)

    // Then: Local content should be preserved
    let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == taskId })
    let tasks = try context.fetch(descriptor)
    XCTAssertEqual(tasks.first?.title, "Failed Local Edit")
    XCTAssertEqual(tasks.first?.syncState, .failed)
  }

  // MARK: - upsertTask: Soft Delete Tests

  func test_upsertTask_handlesSoftDelete() throws {
    // Given: An existing task
    let taskId = UUID()
    let existingTask = makeTask(id: taskId, title: "Original Task")
    existingTask.markSynced()
    context.insert(existingTask)
    try context.save()

    // When: Upsert with deletedAt set
    let deletedAt = Date()
    let dto = makeTaskDTO(id: taskId, title: "Original Task", deletedAt: deletedAt)
    try handler.upsertTask(dto: dto, context: context)

    // Then: Task should be soft-deleted
    let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == taskId })
    let tasks = try context.fetch(descriptor)
    XCTAssertNotNil(tasks.first?.deletedAt)
    XCTAssertEqual(tasks.first?.syncState, .synced)
  }

  func test_upsertTask_resurrectsSoftDeletedTask() throws {
    // Given: A soft-deleted task
    let taskId = UUID()
    let existingTask = makeTask(id: taskId, title: "Deleted Task")
    existingTask.deletedAt = Date()
    existingTask.markSynced()
    context.insert(existingTask)
    try context.save()

    // When: Upsert with no deletedAt (resurrection)
    let dto = makeTaskDTO(id: taskId, title: "Resurrected Task")
    try handler.upsertTask(dto: dto, context: context)

    // Then: Task should be resurrected
    let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == taskId })
    let tasks = try context.fetch(descriptor)
    XCTAssertNil(tasks.first?.deletedAt)
    XCTAssertEqual(tasks.first?.title, "Resurrected Task")
  }

  // MARK: - In-Flight Tracking Tests

  func test_markTasksInFlight_and_clearTasksInFlight_cycle() {
    // Given: Some task IDs
    let taskId1 = UUID()
    let taskId2 = UUID()

    // Initially not in-flight
    XCTAssertFalse(conflictResolver.isTaskInFlight(taskId1))
    XCTAssertFalse(conflictResolver.isTaskInFlight(taskId2))

    // When: Mark as in-flight
    conflictResolver.markTasksInFlight([taskId1, taskId2])

    // Then: Should be in-flight
    XCTAssertTrue(conflictResolver.isTaskInFlight(taskId1))
    XCTAssertTrue(conflictResolver.isTaskInFlight(taskId2))

    // When: Clear in-flight
    conflictResolver.clearTasksInFlight()

    // Then: No longer in-flight
    XCTAssertFalse(conflictResolver.isTaskInFlight(taskId1))
    XCTAssertFalse(conflictResolver.isTaskInFlight(taskId2))
  }

  func test_isTaskInFlight_returnsCorrectValues() {
    let inFlightId = UUID()
    let notInFlightId = UUID()

    conflictResolver.markTasksInFlight([inFlightId])

    XCTAssertTrue(conflictResolver.isTaskInFlight(inFlightId))
    XCTAssertFalse(conflictResolver.isTaskInFlight(notInFlightId))

    conflictResolver.clearTasksInFlight()
  }

  func test_isLocalAuthoritative_respectsInFlightState() throws {
    // Given: A synced task
    let taskId = UUID()
    let task = makeTask(id: taskId, title: "Test")
    task.markSynced()
    context.insert(task)
    try context.save()

    // When: Not in-flight
    var isAuthoritative = conflictResolver.isLocalAuthoritative(
      task,
      inFlight: conflictResolver.isTaskInFlight(taskId)
    )

    // Then: Not local-authoritative
    XCTAssertFalse(isAuthoritative)

    // When: Marked in-flight
    conflictResolver.markTasksInFlight([taskId])
    isAuthoritative = conflictResolver.isLocalAuthoritative(
      task,
      inFlight: conflictResolver.isTaskInFlight(taskId)
    )

    // Then: Is local-authoritative
    XCTAssertTrue(isAuthoritative)

    conflictResolver.clearTasksInFlight()
  }

  func test_isLocalAuthoritative_respectsPendingState() throws {
    // Given: A pending task
    let taskId = UUID()
    let task = makeTask(id: taskId, title: "Pending Task")
    task.markPending()
    context.insert(task)
    try context.save()

    // When: Check local-authoritative (not in-flight)
    let isAuthoritative = conflictResolver.isLocalAuthoritative(
      task,
      inFlight: false
    )

    // Then: Is local-authoritative due to pending state
    XCTAssertTrue(isAuthoritative)
  }

  func test_isLocalAuthoritative_respectsFailedState() throws {
    // Given: A failed task
    let taskId = UUID()
    let task = makeTask(id: taskId, title: "Failed Task")
    task.markFailed("Error")
    context.insert(task)
    try context.save()

    // When: Check local-authoritative
    let isAuthoritative = conflictResolver.isLocalAuthoritative(
      task,
      inFlight: false
    )

    // Then: Is local-authoritative due to failed state
    XCTAssertTrue(isAuthoritative)
  }

  // MARK: - deleteLocalTask Tests

  func test_deleteLocalTask_deletesExistingTask() throws {
    // Given: An existing task
    let taskId = UUID()
    let existingTask = makeTask(id: taskId, title: "To be deleted")
    context.insert(existingTask)
    try context.save()

    // When: Delete the task
    let deleted = try handler.deleteLocalTask(id: taskId, context: context)

    // Then: Task should be deleted
    XCTAssertTrue(deleted)
    let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == taskId })
    let tasks = try context.fetch(descriptor)
    XCTAssertTrue(tasks.isEmpty)
  }

  func test_deleteLocalTask_returnsFalseForMissingTask() throws {
    // Given: A non-existent task ID
    let missingId = UUID()

    // When: Try to delete
    let deleted = try handler.deleteLocalTask(id: missingId, context: context)

    // Then: Should return false
    XCTAssertFalse(deleted)
  }

  // MARK: - TaskAssignee Upsert Tests

  func test_upsertTaskAssignee_insertsNewAssignee() throws {
    // Given: A new assignee DTO that doesn't exist locally
    let assigneeId = UUID()
    let taskId = UUID()
    let userId = UUID()
    let dto = makeTaskAssigneeDTO(id: assigneeId, taskId: taskId, userId: userId)

    // When: Upsert the assignee
    try handler.upsertTaskAssignee(dto: dto, context: context)

    // Then: Assignee should be inserted
    let descriptor = FetchDescriptor<TaskAssignee>(predicate: #Predicate { $0.id == assigneeId })
    let assignees = try context.fetch(descriptor)
    XCTAssertEqual(assignees.count, 1)
    XCTAssertEqual(assignees.first?.taskId, taskId)
    XCTAssertEqual(assignees.first?.userId, userId)
    XCTAssertEqual(assignees.first?.syncState, .synced)
  }

  func test_upsertTaskAssignee_setsAllFieldsFromDTO() throws {
    // Given: A DTO with all fields
    let assigneeId = UUID()
    let taskId = UUID()
    let userId = UUID()
    let assignedBy = UUID()
    let assignedAt = Date()
    let dto = makeTaskAssigneeDTO(
      id: assigneeId,
      taskId: taskId,
      userId: userId,
      assignedBy: assignedBy,
      assignedAt: assignedAt
    )

    // When: Upsert the assignee
    try handler.upsertTaskAssignee(dto: dto, context: context)

    // Then: All fields should be set
    let descriptor = FetchDescriptor<TaskAssignee>(predicate: #Predicate { $0.id == assigneeId })
    let assignees = try context.fetch(descriptor)
    let assignee = assignees.first
    XCTAssertEqual(assignee?.taskId, taskId)
    XCTAssertEqual(assignee?.userId, userId)
    XCTAssertEqual(assignee?.assignedBy, assignedBy)
    XCTAssertEqual(assignee?.assignedAt, assignedAt)
  }

  func test_upsertTaskAssignee_updatesExistingSyncedAssignee() throws {
    // Given: An existing synced assignee
    let assigneeId = UUID()
    let oldTaskId = UUID()
    let newTaskId = UUID()
    let userId = UUID()
    let existingAssignee = makeTaskAssignee(
      id: assigneeId,
      taskId: oldTaskId,
      userId: userId
    )
    existingAssignee.markSynced()
    context.insert(existingAssignee)
    try context.save()

    // When: Upsert with new taskId
    let dto = makeTaskAssigneeDTO(id: assigneeId, taskId: newTaskId, userId: userId)
    try handler.upsertTaskAssignee(dto: dto, context: context)

    // Then: Assignee should be updated
    let descriptor = FetchDescriptor<TaskAssignee>(predicate: #Predicate { $0.id == assigneeId })
    let assignees = try context.fetch(descriptor)
    XCTAssertEqual(assignees.first?.taskId, newTaskId)
    XCTAssertEqual(assignees.first?.syncState, .synced)
  }

  func test_upsertTaskAssignee_skipsInFlightAssignee() throws {
    // Given: An assignee that is currently being synced up (in-flight)
    let assigneeId = UUID()
    let taskId = UUID()
    let userId = UUID()
    let existingAssignee = makeTaskAssignee(
      id: assigneeId,
      taskId: taskId,
      userId: userId
    )
    existingAssignee.markSynced()
    context.insert(existingAssignee)
    try context.save()

    // Mark as in-flight
    conflictResolver.markTaskAssigneesInFlight([assigneeId])

    // When: Upsert with different values while in-flight
    let newTaskId = UUID()
    let dto = makeTaskAssigneeDTO(id: assigneeId, taskId: newTaskId, userId: userId)
    try handler.upsertTaskAssignee(dto: dto, context: context)

    // Then: Local values should be preserved
    let descriptor = FetchDescriptor<TaskAssignee>(predicate: #Predicate { $0.id == assigneeId })
    let assignees = try context.fetch(descriptor)
    XCTAssertEqual(assignees.first?.taskId, taskId) // Original taskId preserved

    // Cleanup
    conflictResolver.clearTaskAssigneesInFlight()
  }

  func test_upsertTaskAssignee_skipsPendingAssignee() throws {
    // Given: An assignee with pending local changes
    let assigneeId = UUID()
    let taskId = UUID()
    let userId = UUID()
    let existingAssignee = makeTaskAssignee(
      id: assigneeId,
      taskId: taskId,
      userId: userId
    )
    existingAssignee.markPending()
    context.insert(existingAssignee)
    try context.save()

    // When: Upsert with different values while pending
    let newTaskId = UUID()
    let dto = makeTaskAssigneeDTO(id: assigneeId, taskId: newTaskId, userId: userId)
    try handler.upsertTaskAssignee(dto: dto, context: context)

    // Then: Local values should be preserved
    let descriptor = FetchDescriptor<TaskAssignee>(predicate: #Predicate { $0.id == assigneeId })
    let assignees = try context.fetch(descriptor)
    XCTAssertEqual(assignees.first?.taskId, taskId)
    XCTAssertEqual(assignees.first?.syncState, .pending)
  }

  func test_upsertTaskAssignee_skipsFailedAssignee() throws {
    // Given: An assignee with failed sync state
    let assigneeId = UUID()
    let taskId = UUID()
    let userId = UUID()
    let existingAssignee = makeTaskAssignee(
      id: assigneeId,
      taskId: taskId,
      userId: userId
    )
    existingAssignee.markFailed("Network error")
    context.insert(existingAssignee)
    try context.save()

    // When: Upsert with different values while failed
    let newTaskId = UUID()
    let dto = makeTaskAssigneeDTO(id: assigneeId, taskId: newTaskId, userId: userId)
    try handler.upsertTaskAssignee(dto: dto, context: context)

    // Then: Local values should be preserved
    let descriptor = FetchDescriptor<TaskAssignee>(predicate: #Predicate { $0.id == assigneeId })
    let assignees = try context.fetch(descriptor)
    XCTAssertEqual(assignees.first?.taskId, taskId)
    XCTAssertEqual(assignees.first?.syncState, .failed)
  }

  // MARK: - TaskAssignee In-Flight Tracking Tests

  func test_markTaskAssigneesInFlight_and_clearTaskAssigneesInFlight_cycle() {
    // Given: Some assignee IDs
    let assigneeId1 = UUID()
    let assigneeId2 = UUID()

    // Initially not in-flight
    XCTAssertFalse(conflictResolver.isTaskAssigneeInFlight(assigneeId1))
    XCTAssertFalse(conflictResolver.isTaskAssigneeInFlight(assigneeId2))

    // When: Mark as in-flight
    conflictResolver.markTaskAssigneesInFlight([assigneeId1, assigneeId2])

    // Then: Should be in-flight
    XCTAssertTrue(conflictResolver.isTaskAssigneeInFlight(assigneeId1))
    XCTAssertTrue(conflictResolver.isTaskAssigneeInFlight(assigneeId2))

    // When: Clear in-flight
    conflictResolver.clearTaskAssigneesInFlight()

    // Then: No longer in-flight
    XCTAssertFalse(conflictResolver.isTaskAssigneeInFlight(assigneeId1))
    XCTAssertFalse(conflictResolver.isTaskAssigneeInFlight(assigneeId2))
  }

  func test_isTaskAssigneeInFlight_returnsCorrectValues() {
    let inFlightId = UUID()
    let notInFlightId = UUID()

    conflictResolver.markTaskAssigneesInFlight([inFlightId])

    XCTAssertTrue(conflictResolver.isTaskAssigneeInFlight(inFlightId))
    XCTAssertFalse(conflictResolver.isTaskAssigneeInFlight(notInFlightId))

    conflictResolver.clearTaskAssigneesInFlight()
  }

  // MARK: - Relationship Establishment Tests

  func test_upsertTask_callsListingRelationshipClosure() throws {
    // Given: A task DTO with listing ID and a relationship closure
    let taskId = UUID()
    let listingId = UUID()
    let dto = makeTaskDTO(id: taskId, title: "Task with Listing", listing: listingId)

    var closureCalled = false
    var capturedTask: TaskItem?
    var capturedListingId: UUID?

    let establishRelationship: (TaskItem, UUID?, ModelContext) throws -> Void = { task, lid, _ in
      closureCalled = true
      capturedTask = task
      capturedListingId = lid
    }

    // When: Upsert with the closure
    try handler.upsertTask(
      dto: dto,
      context: context,
      establishListingRelationship: establishRelationship
    )

    // Then: Closure should be called with correct values
    XCTAssertTrue(closureCalled)
    XCTAssertEqual(capturedTask?.id, taskId)
    XCTAssertEqual(capturedListingId, listingId)
  }

  func test_upsertTaskAssignee_callsTaskRelationshipClosure() throws {
    // Given: An assignee DTO and a relationship closure
    let assigneeId = UUID()
    let taskId = UUID()
    let userId = UUID()
    let dto = makeTaskAssigneeDTO(id: assigneeId, taskId: taskId, userId: userId)

    var closureCalled = false
    var capturedAssignee: TaskAssignee?
    var capturedTaskId: UUID?

    let establishRelationship: (TaskAssignee, UUID, ModelContext) throws -> Void = { assignee, tid, _ in
      closureCalled = true
      capturedAssignee = assignee
      capturedTaskId = tid
    }

    // When: Upsert with the closure
    try handler.upsertTaskAssignee(
      dto: dto,
      context: context,
      establishTaskRelationship: establishRelationship
    )

    // Then: Closure should be called with correct values
    XCTAssertTrue(closureCalled)
    XCTAssertEqual(capturedAssignee?.id, assigneeId)
    XCTAssertEqual(capturedTaskId, taskId)
  }

  // MARK: - Edge Case Tests

  func test_upsertTask_handlesNilDescription() throws {
    // Given: A DTO with nil description
    let taskId = UUID()
    let dto = makeTaskDTO(id: taskId, title: "No Description Task", description: nil)

    // When: Upsert the task
    try handler.upsertTask(dto: dto, context: context)

    // Then: Task should have empty description
    let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == taskId })
    let tasks = try context.fetch(descriptor)
    XCTAssertEqual(tasks.first?.taskDescription, "")
  }

  func test_upsertTask_handlesInvalidStatus() throws {
    // Given: A DTO with an invalid status (TaskDTO.toModel handles this)
    let taskId = UUID()
    let declaredBy = UUID()

    // Create DTO manually to test invalid status handling
    let dto = TaskDTO(
      id: taskId,
      title: "Invalid Status Task",
      description: nil,
      dueDate: nil,
      status: "invalid_status",
      declaredBy: declaredBy,
      listing: nil,
      createdVia: "dispatch",
      sourceSlackMessages: nil,
      audiences: nil,
      completedAt: nil,
      deletedAt: nil,
      createdAt: Date(),
      updatedAt: Date()
    )

    // When: Upsert the task
    try handler.upsertTask(dto: dto, context: context)

    // Then: Task should default to .open status
    let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == taskId })
    let tasks = try context.fetch(descriptor)
    XCTAssertEqual(tasks.first?.status, .open)
  }

  func test_upsertTask_handlesDuplicateIds() throws {
    // Given: Insert same task twice
    let taskId = UUID()
    let dto1 = makeTaskDTO(id: taskId, title: "First Insert")
    let dto2 = makeTaskDTO(id: taskId, title: "Second Insert")

    // When: Upsert both
    try handler.upsertTask(dto: dto1, context: context)
    try handler.upsertTask(dto: dto2, context: context)

    // Then: Should have only one task with second title
    let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == taskId })
    let tasks = try context.fetch(descriptor)
    XCTAssertEqual(tasks.count, 1)
    XCTAssertEqual(tasks.first?.title, "Second Insert")
  }

  // MARK: Private

  // swiftlint:disable implicitly_unwrapped_optional
  private var container: ModelContainer!
  private var context: ModelContext!
  private var handler: TaskSyncHandler!
  private var conflictResolver: ConflictResolver!

  // swiftlint:enable implicitly_unwrapped_optional

  // MARK: - Test Helpers

  private func makeTask(
    id: UUID = UUID(),
    title: String = "Test Task",
    taskDescription: String = "",
    dueDate: Date? = nil,
    status: TaskStatus = .open,
    declaredBy: UUID = UUID(),
    listingId: UUID? = nil
  ) -> TaskItem {
    TaskItem(
      id: id,
      title: title,
      taskDescription: taskDescription,
      dueDate: dueDate,
      status: status,
      declaredBy: declaredBy,
      listingId: listingId
    )
  }

  private func makeTaskDTO(
    id: UUID = UUID(),
    title: String = "Test Task",
    description: String? = nil,
    dueDate: Date? = nil,
    status: String = "open",
    declaredBy: UUID = UUID(),
    listing: UUID? = nil,
    completedAt: Date? = nil,
    deletedAt: Date? = nil
  ) -> TaskDTO {
    TaskDTO(
      id: id,
      title: title,
      description: description,
      dueDate: dueDate,
      status: status,
      declaredBy: declaredBy,
      listing: listing,
      createdVia: "dispatch",
      sourceSlackMessages: nil,
      audiences: nil,
      completedAt: completedAt,
      deletedAt: deletedAt,
      createdAt: Date(),
      updatedAt: Date()
    )
  }

  private func makeTaskAssignee(
    id: UUID = UUID(),
    taskId: UUID = UUID(),
    userId: UUID = UUID(),
    assignedBy: UUID = UUID(),
    assignedAt: Date = Date()
  ) -> TaskAssignee {
    TaskAssignee(
      id: id,
      taskId: taskId,
      userId: userId,
      assignedBy: assignedBy,
      assignedAt: assignedAt
    )
  }

  private func makeTaskAssigneeDTO(
    id: UUID = UUID(),
    taskId: UUID = UUID(),
    userId: UUID = UUID(),
    assignedBy: UUID = UUID(),
    assignedAt: Date = Date()
  ) -> TaskAssigneeDTO {
    TaskAssigneeDTO(
      id: id,
      taskId: taskId,
      userId: userId,
      assignedBy: assignedBy,
      assignedAt: assignedAt,
      createdAt: Date(),
      updatedAt: Date()
    )
  }
}
