//
//  ActivitySyncHandlerTests.swift
//  DispatchTests
//
//  Unit tests for ActivitySyncHandler entity-specific sync operations.
//  Tests applyRemoteActivity, ActivityAssignee sync, ActivityTemplate sync,
//  in-flight protection, and error handling.
//

import SwiftData
import XCTest
@testable import DispatchApp

// MARK: - ActivitySyncHandlerTests

@MainActor
final class ActivitySyncHandlerTests: XCTestCase {

  // MARK: Internal

  override func setUp() {
    super.setUp()

    // Create in-memory SwiftData container for testing
    // Include models required by Activity relationships and ActivityTemplate
    let schema = Schema([
      Activity.self,
      ActivityAssignee.self,
      ActivityTemplate.self,
      ListingTypeDefinition.self,
      Listing.self,
      Property.self,
      User.self,
      TaskItem.self,
      TaskAssignee.self,
      Note.self,
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
    handler = ActivitySyncHandler(dependencies: deps)
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

  // MARK: - upsertActivity Tests

  func test_upsertActivity_insertsNewActivity() throws {
    // Given: A new activity DTO that doesn't exist locally
    let activityId = UUID()
    let dto = makeActivityDTO(id: activityId, title: "Test Activity")

    // When: Upsert the activity
    try handler.upsertActivity(dto: dto, context: context)

    // Then: Activity should be inserted
    let descriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.id == activityId })
    let activities = try context.fetch(descriptor)
    XCTAssertEqual(activities.count, 1)
    XCTAssertEqual(activities.first?.title, "Test Activity")
    XCTAssertEqual(activities.first?.syncState, .synced)
  }

  func test_upsertActivity_updatesExistingActivity() throws {
    // Given: An existing synced activity
    let activityId = UUID()
    let existingActivity = makeActivity(id: activityId, title: "Old Title")
    existingActivity.markSynced()
    context.insert(existingActivity)
    try context.save()

    // When: Upsert with updated title
    let dto = makeActivityDTO(id: activityId, title: "Updated Title")
    try handler.upsertActivity(dto: dto, context: context)

    // Then: Activity should be updated
    let descriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.id == activityId })
    let activities = try context.fetch(descriptor)
    XCTAssertEqual(activities.first?.title, "Updated Title")
    XCTAssertEqual(activities.first?.syncState, .synced)
  }

  func test_upsertActivity_skipsInFlightActivity() throws {
    // Given: An activity that is currently being synced up (in-flight)
    let activityId = UUID()
    let existingActivity = makeActivity(id: activityId, title: "Local Title")
    existingActivity.markSynced()
    context.insert(existingActivity)
    try context.save()

    // Mark as in-flight
    conflictResolver.markActivitiesInFlight([activityId])

    // When: Upsert remote update while in-flight
    let dto = makeActivityDTO(id: activityId, title: "Remote Title")
    try handler.upsertActivity(dto: dto, context: context)

    // Then: Local title should be preserved (in-flight protection)
    let descriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.id == activityId })
    let activities = try context.fetch(descriptor)
    XCTAssertEqual(activities.first?.title, "Local Title")

    // Cleanup
    conflictResolver.clearActivitiesInFlight()
  }

  func test_upsertActivity_skipsPendingActivity() throws {
    // Given: An activity with pending local changes
    let activityId = UUID()
    let existingActivity = makeActivity(id: activityId, title: "Pending Local Edit")
    existingActivity.markPending()
    context.insert(existingActivity)
    try context.save()

    // When: Upsert remote update while pending
    let dto = makeActivityDTO(id: activityId, title: "Remote Title")
    try handler.upsertActivity(dto: dto, context: context)

    // Then: Local title should be preserved
    let descriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.id == activityId })
    let activities = try context.fetch(descriptor)
    XCTAssertEqual(activities.first?.title, "Pending Local Edit")
    XCTAssertEqual(activities.first?.syncState, .pending)
  }

  func test_upsertActivity_skipsFailedActivity() throws {
    // Given: An activity with a failed sync state
    let activityId = UUID()
    let existingActivity = makeActivity(id: activityId, title: "Failed Local Edit")
    existingActivity.markFailed("Network error")
    context.insert(existingActivity)
    try context.save()

    // When: Upsert remote update while failed
    let dto = makeActivityDTO(id: activityId, title: "Remote Title")
    try handler.upsertActivity(dto: dto, context: context)

    // Then: Local title should be preserved
    let descriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.id == activityId })
    let activities = try context.fetch(descriptor)
    XCTAssertEqual(activities.first?.title, "Failed Local Edit")
    XCTAssertEqual(activities.first?.syncState, .failed)
  }

  func test_upsertActivity_handlesSoftDelete() throws {
    // Given: An existing activity
    let activityId = UUID()
    let existingActivity = makeActivity(id: activityId, title: "Original Activity")
    existingActivity.markSynced()
    context.insert(existingActivity)
    try context.save()

    // When: Upsert with deletedAt set (soft delete)
    let dto = makeActivityDTO(id: activityId, title: "Original Activity", deletedAt: Date())
    try handler.upsertActivity(dto: dto, context: context)

    // Then: Activity should be soft-deleted
    let descriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.id == activityId })
    let activities = try context.fetch(descriptor)
    XCTAssertNotNil(activities.first?.deletedAt)
    XCTAssertEqual(activities.first?.syncState, .synced)
  }

  func test_upsertActivity_updatesDescription() throws {
    // Given: An existing activity
    let activityId = UUID()
    let existingActivity = makeActivity(id: activityId, title: "Activity")
    existingActivity.activityDescription = "Old description"
    existingActivity.markSynced()
    context.insert(existingActivity)
    try context.save()

    // When: Upsert with new description
    let dto = makeActivityDTO(id: activityId, title: "Activity", description: "New description")
    try handler.upsertActivity(dto: dto, context: context)

    // Then: Description should be updated
    let descriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.id == activityId })
    let activities = try context.fetch(descriptor)
    XCTAssertEqual(activities.first?.activityDescription, "New description")
  }

  func test_upsertActivity_updatesDueDate() throws {
    // Given: An existing activity
    let activityId = UUID()
    let existingActivity = makeActivity(id: activityId, title: "Activity")
    existingActivity.markSynced()
    context.insert(existingActivity)
    try context.save()

    // When: Upsert with due date
    let dueDate = Date().addingTimeInterval(86400) // Tomorrow
    let dto = makeActivityDTO(id: activityId, title: "Activity", dueDate: dueDate)
    try handler.upsertActivity(dto: dto, context: context)

    // Then: Due date should be updated
    let descriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.id == activityId })
    let activities = try context.fetch(descriptor)
    XCTAssertNotNil(activities.first?.dueDate)
  }

  func test_upsertActivity_updatesStatus() throws {
    // Given: An existing open activity
    let activityId = UUID()
    let existingActivity = makeActivity(id: activityId, title: "Activity", status: .open)
    existingActivity.markSynced()
    context.insert(existingActivity)
    try context.save()

    // When: Upsert with completed status
    let dto = makeActivityDTO(id: activityId, title: "Activity", status: "completed")
    try handler.upsertActivity(dto: dto, context: context)

    // Then: Status should be updated
    let descriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.id == activityId })
    let activities = try context.fetch(descriptor)
    XCTAssertEqual(activities.first?.status, .completed)
  }

  func test_upsertActivity_updatesDuration() throws {
    // Given: An existing activity
    let activityId = UUID()
    let existingActivity = makeActivity(id: activityId, title: "Activity")
    existingActivity.markSynced()
    context.insert(existingActivity)
    try context.save()

    // When: Upsert with duration
    let dto = makeActivityDTO(id: activityId, title: "Activity", durationMinutes: 60)
    try handler.upsertActivity(dto: dto, context: context)

    // Then: Duration should be updated (60 minutes = 3600 seconds)
    let descriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.id == activityId })
    let activities = try context.fetch(descriptor)
    XCTAssertEqual(activities.first?.duration, 3600)
  }

  func test_upsertActivity_callsRelationshipEstablisher() throws {
    // Given: A new activity DTO with a listing ID
    let activityId = UUID()
    let listingId = UUID()
    let dto = makeActivityDTO(id: activityId, title: "Activity", listingId: listingId)

    var establisherCalled = false
    var receivedListingId: UUID?

    // When: Upsert with relationship establisher
    try handler.upsertActivity(dto: dto, context: context) { _, receivedId, _ in
      establisherCalled = true
      receivedListingId = receivedId
    }

    // Then: Relationship establisher should be called with correct listing ID
    XCTAssertTrue(establisherCalled)
    XCTAssertEqual(receivedListingId, listingId)
  }

  // MARK: - deleteLocalActivity Tests

  func test_deleteLocalActivity_deletesExistingActivity() throws {
    // Given: An existing activity
    let activityId = UUID()
    let existingActivity = makeActivity(id: activityId, title: "To be deleted")
    context.insert(existingActivity)
    try context.save()

    // When: Delete the activity
    let deleted = try handler.deleteLocalActivity(id: activityId, context: context)

    // Then: Activity should be deleted
    XCTAssertTrue(deleted)
    let descriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.id == activityId })
    let activities = try context.fetch(descriptor)
    XCTAssertTrue(activities.isEmpty)
  }

  func test_deleteLocalActivity_returnsFalseForMissingActivity() throws {
    // Given: A non-existent activity ID
    let missingId = UUID()

    // When: Try to delete
    let deleted = try handler.deleteLocalActivity(id: missingId, context: context)

    // Then: Should return false
    XCTAssertFalse(deleted)
  }

  // MARK: - upsertActivityAssignee Tests

  func test_upsertActivityAssignee_insertsNewAssignee() throws {
    // Given: A new activity assignee DTO
    let assigneeId = UUID()
    let activityId = UUID()
    let userId = UUID()
    let dto = makeActivityAssigneeDTO(id: assigneeId, activityId: activityId, userId: userId)

    // When: Upsert the assignee
    try handler.upsertActivityAssignee(dto: dto, context: context)

    // Then: Assignee should be inserted
    let descriptor = FetchDescriptor<ActivityAssignee>(predicate: #Predicate { $0.id == assigneeId })
    let assignees = try context.fetch(descriptor)
    XCTAssertEqual(assignees.count, 1)
    XCTAssertEqual(assignees.first?.activityId, activityId)
    XCTAssertEqual(assignees.first?.userId, userId)
    XCTAssertEqual(assignees.first?.syncState, .synced)
  }

  func test_upsertActivityAssignee_updatesExistingAssignee() throws {
    // Given: An existing synced assignee
    let assigneeId = UUID()
    let activityId = UUID()
    let originalUserId = UUID()
    let newUserId = UUID()
    let existingAssignee = makeActivityAssignee(id: assigneeId, activityId: activityId, userId: originalUserId)
    existingAssignee.markSynced()
    context.insert(existingAssignee)
    try context.save()

    // When: Upsert with new user ID
    let dto = makeActivityAssigneeDTO(id: assigneeId, activityId: activityId, userId: newUserId)
    try handler.upsertActivityAssignee(dto: dto, context: context)

    // Then: Assignee should be updated
    let descriptor = FetchDescriptor<ActivityAssignee>(predicate: #Predicate { $0.id == assigneeId })
    let assignees = try context.fetch(descriptor)
    XCTAssertEqual(assignees.first?.userId, newUserId)
    XCTAssertEqual(assignees.first?.syncState, .synced)
  }

  func test_upsertActivityAssignee_skipsInFlightAssignee() throws {
    // Given: An assignee that is currently being synced up (in-flight)
    let assigneeId = UUID()
    let activityId = UUID()
    let localUserId = UUID()
    let remoteUserId = UUID()
    let existingAssignee = makeActivityAssignee(id: assigneeId, activityId: activityId, userId: localUserId)
    existingAssignee.markSynced()
    context.insert(existingAssignee)
    try context.save()

    // Mark as in-flight
    conflictResolver.markActivityAssigneesInFlight([assigneeId])

    // When: Upsert remote update while in-flight
    let dto = makeActivityAssigneeDTO(id: assigneeId, activityId: activityId, userId: remoteUserId)
    try handler.upsertActivityAssignee(dto: dto, context: context)

    // Then: Local user ID should be preserved (in-flight protection)
    let descriptor = FetchDescriptor<ActivityAssignee>(predicate: #Predicate { $0.id == assigneeId })
    let assignees = try context.fetch(descriptor)
    XCTAssertEqual(assignees.first?.userId, localUserId)

    // Cleanup
    conflictResolver.clearActivityAssigneesInFlight()
  }

  func test_upsertActivityAssignee_skipsPendingAssignee() throws {
    // Given: An assignee with pending local changes
    let assigneeId = UUID()
    let activityId = UUID()
    let localUserId = UUID()
    let remoteUserId = UUID()
    let existingAssignee = makeActivityAssignee(id: assigneeId, activityId: activityId, userId: localUserId)
    existingAssignee.markPending()
    context.insert(existingAssignee)
    try context.save()

    // When: Upsert remote update while pending
    let dto = makeActivityAssigneeDTO(id: assigneeId, activityId: activityId, userId: remoteUserId)
    try handler.upsertActivityAssignee(dto: dto, context: context)

    // Then: Local user ID should be preserved
    let descriptor = FetchDescriptor<ActivityAssignee>(predicate: #Predicate { $0.id == assigneeId })
    let assignees = try context.fetch(descriptor)
    XCTAssertEqual(assignees.first?.userId, localUserId)
    XCTAssertEqual(assignees.first?.syncState, .pending)
  }

  func test_upsertActivityAssignee_skipsFailedAssignee() throws {
    // Given: An assignee with a failed sync state
    let assigneeId = UUID()
    let activityId = UUID()
    let localUserId = UUID()
    let remoteUserId = UUID()
    let existingAssignee = makeActivityAssignee(id: assigneeId, activityId: activityId, userId: localUserId)
    existingAssignee.markFailed("Network error")
    context.insert(existingAssignee)
    try context.save()

    // When: Upsert remote update while failed
    let dto = makeActivityAssigneeDTO(id: assigneeId, activityId: activityId, userId: remoteUserId)
    try handler.upsertActivityAssignee(dto: dto, context: context)

    // Then: Local user ID should be preserved
    let descriptor = FetchDescriptor<ActivityAssignee>(predicate: #Predicate { $0.id == assigneeId })
    let assignees = try context.fetch(descriptor)
    XCTAssertEqual(assignees.first?.userId, localUserId)
    XCTAssertEqual(assignees.first?.syncState, .failed)
  }

  func test_upsertActivityAssignee_callsRelationshipEstablisher() throws {
    // Given: A new assignee DTO
    let assigneeId = UUID()
    let activityId = UUID()
    let userId = UUID()
    let dto = makeActivityAssigneeDTO(id: assigneeId, activityId: activityId, userId: userId)

    var establisherCalled = false
    var receivedActivityId: UUID?

    // When: Upsert with relationship establisher
    try handler.upsertActivityAssignee(dto: dto, context: context) { _, receivedId, _ in
      establisherCalled = true
      receivedActivityId = receivedId
    }

    // Then: Relationship establisher should be called with correct activity ID
    XCTAssertTrue(establisherCalled)
    XCTAssertEqual(receivedActivityId, activityId)
  }

  // MARK: - upsertActivityTemplate Tests

  func test_upsertActivityTemplate_insertsNewTemplate() throws {
    // Given: A listing type and new template DTO
    let listingTypeId = UUID()
    let listingType = ListingTypeDefinition(id: listingTypeId, name: "Residential")
    context.insert(listingType)
    try context.save()

    let templateId = UUID()
    let dto = makeActivityTemplateDTO(id: templateId, title: "New Template", listingTypeId: listingTypeId)

    // When: Upsert the template
    try handler.upsertActivityTemplate(dto: dto, context: context, localTypes: [listingType])

    // Then: Template should be inserted
    let descriptor = FetchDescriptor<ActivityTemplate>(predicate: #Predicate { $0.id == templateId })
    let templates = try context.fetch(descriptor)
    XCTAssertEqual(templates.count, 1)
    XCTAssertEqual(templates.first?.title, "New Template")
    XCTAssertEqual(templates.first?.listingTypeId, listingTypeId)
    XCTAssertEqual(templates.first?.syncState, .synced)
  }

  func test_upsertActivityTemplate_updatesExistingTemplate() throws {
    // Given: An existing synced template
    let listingTypeId = UUID()
    let listingType = ListingTypeDefinition(id: listingTypeId, name: "Residential")
    context.insert(listingType)

    let templateId = UUID()
    let existingTemplate = ActivityTemplate(
      id: templateId,
      title: "Old Title",
      templateDescription: "Old description",
      position: 0,
      isArchived: false,
      audiencesRaw: [],
      listingTypeId: listingTypeId
    )
    existingTemplate.markSynced()
    context.insert(existingTemplate)
    try context.save()

    // When: Upsert with updated title
    let dto = makeActivityTemplateDTO(id: templateId, title: "Updated Title", listingTypeId: listingTypeId)
    try handler.upsertActivityTemplate(dto: dto, context: context, localTypes: [listingType])

    // Then: Template should be updated
    let descriptor = FetchDescriptor<ActivityTemplate>(predicate: #Predicate { $0.id == templateId })
    let templates = try context.fetch(descriptor)
    XCTAssertEqual(templates.first?.title, "Updated Title")
    XCTAssertEqual(templates.first?.syncState, .synced)
  }

  func test_upsertActivityTemplate_skipsPendingTemplate() throws {
    // Given: A template with pending local changes
    let listingTypeId = UUID()
    let listingType = ListingTypeDefinition(id: listingTypeId, name: "Residential")
    context.insert(listingType)

    let templateId = UUID()
    let existingTemplate = ActivityTemplate(
      id: templateId,
      title: "Pending Local Edit",
      templateDescription: "",
      position: 0,
      isArchived: false,
      audiencesRaw: [],
      listingTypeId: listingTypeId
    )
    existingTemplate.markPending()
    context.insert(existingTemplate)
    try context.save()

    // When: Upsert remote update while pending
    let dto = makeActivityTemplateDTO(id: templateId, title: "Remote Title", listingTypeId: listingTypeId)
    try handler.upsertActivityTemplate(dto: dto, context: context, localTypes: [listingType])

    // Then: Local title should be preserved
    let descriptor = FetchDescriptor<ActivityTemplate>(predicate: #Predicate { $0.id == templateId })
    let templates = try context.fetch(descriptor)
    XCTAssertEqual(templates.first?.title, "Pending Local Edit")
    XCTAssertEqual(templates.first?.syncState, .pending)
  }

  func test_upsertActivityTemplate_skipsFailedTemplate() throws {
    // Given: A template with a failed sync state
    let listingTypeId = UUID()
    let listingType = ListingTypeDefinition(id: listingTypeId, name: "Residential")
    context.insert(listingType)

    let templateId = UUID()
    let existingTemplate = ActivityTemplate(
      id: templateId,
      title: "Failed Local Edit",
      templateDescription: "",
      position: 0,
      isArchived: false,
      audiencesRaw: [],
      listingTypeId: listingTypeId
    )
    existingTemplate.markFailed("Network error")
    context.insert(existingTemplate)
    try context.save()

    // When: Upsert remote update while failed
    let dto = makeActivityTemplateDTO(id: templateId, title: "Remote Title", listingTypeId: listingTypeId)
    try handler.upsertActivityTemplate(dto: dto, context: context, localTypes: [listingType])

    // Then: Local title should be preserved
    let descriptor = FetchDescriptor<ActivityTemplate>(predicate: #Predicate { $0.id == templateId })
    let templates = try context.fetch(descriptor)
    XCTAssertEqual(templates.first?.title, "Failed Local Edit")
    XCTAssertEqual(templates.first?.syncState, .failed)
  }

  func test_upsertActivityTemplate_updatesPosition() throws {
    // Given: An existing template
    let listingTypeId = UUID()
    let listingType = ListingTypeDefinition(id: listingTypeId, name: "Residential")
    context.insert(listingType)

    let templateId = UUID()
    let existingTemplate = ActivityTemplate(
      id: templateId,
      title: "Template",
      templateDescription: "",
      position: 0,
      isArchived: false,
      audiencesRaw: [],
      listingTypeId: listingTypeId
    )
    existingTemplate.markSynced()
    context.insert(existingTemplate)
    try context.save()

    // When: Upsert with new position
    let dto = makeActivityTemplateDTO(id: templateId, title: "Template", listingTypeId: listingTypeId, position: 5)
    try handler.upsertActivityTemplate(dto: dto, context: context, localTypes: [listingType])

    // Then: Position should be updated
    let descriptor = FetchDescriptor<ActivityTemplate>(predicate: #Predicate { $0.id == templateId })
    let templates = try context.fetch(descriptor)
    XCTAssertEqual(templates.first?.position, 5)
  }

  func test_upsertActivityTemplate_updatesIsArchived() throws {
    // Given: An existing non-archived template
    let listingTypeId = UUID()
    let listingType = ListingTypeDefinition(id: listingTypeId, name: "Residential")
    context.insert(listingType)

    let templateId = UUID()
    let existingTemplate = ActivityTemplate(
      id: templateId,
      title: "Template",
      templateDescription: "",
      position: 0,
      isArchived: false,
      audiencesRaw: [],
      listingTypeId: listingTypeId
    )
    existingTemplate.markSynced()
    context.insert(existingTemplate)
    try context.save()

    // When: Upsert with archived = true
    let dto = makeActivityTemplateDTO(
      id: templateId,
      title: "Template",
      listingTypeId: listingTypeId,
      isArchived: true
    )
    try handler.upsertActivityTemplate(dto: dto, context: context, localTypes: [listingType])

    // Then: isArchived should be updated
    let descriptor = FetchDescriptor<ActivityTemplate>(predicate: #Predicate { $0.id == templateId })
    let templates = try context.fetch(descriptor)
    XCTAssertTrue(templates.first?.isArchived == true)
  }

  func test_upsertActivityTemplate_setsListingTypeRelationship() throws {
    // Given: A listing type
    let listingTypeId = UUID()
    let listingType = ListingTypeDefinition(id: listingTypeId, name: "Residential")
    context.insert(listingType)
    try context.save()

    let templateId = UUID()
    let dto = makeActivityTemplateDTO(id: templateId, title: "Template", listingTypeId: listingTypeId)

    // When: Upsert the template
    try handler.upsertActivityTemplate(dto: dto, context: context, localTypes: [listingType])

    // Then: Template should have listing type relationship
    let descriptor = FetchDescriptor<ActivityTemplate>(predicate: #Predicate { $0.id == templateId })
    let templates = try context.fetch(descriptor)
    XCTAssertEqual(templates.first?.listingType?.id, listingTypeId)
    XCTAssertEqual(templates.first?.listingType?.name, "Residential")
  }

  // MARK: - Edge Case Tests

  func test_upsertActivity_handlesInvalidStatusGracefully() throws {
    // Given: An activity DTO with invalid status (defaults to .open in toModel())
    let activityId = UUID()
    let dto = makeActivityDTO(id: activityId, title: "Activity", status: "invalid_status")

    // When: Upsert the activity
    try handler.upsertActivity(dto: dto, context: context)

    // Then: Activity should be inserted with default status
    let descriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.id == activityId })
    let activities = try context.fetch(descriptor)
    XCTAssertEqual(activities.first?.status, .open)
  }

  func test_upsertActivity_handlesNilDescription() throws {
    // Given: An activity DTO with nil description
    let activityId = UUID()
    let dto = makeActivityDTO(id: activityId, title: "Activity", description: nil)

    // When: Upsert the activity
    try handler.upsertActivity(dto: dto, context: context)

    // Then: Description should be empty string
    let descriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.id == activityId })
    let activities = try context.fetch(descriptor)
    XCTAssertEqual(activities.first?.activityDescription, "")
  }

  func test_upsertActivity_handlesNilDuration() throws {
    // Given: An activity DTO with nil duration
    let activityId = UUID()
    let dto = makeActivityDTO(id: activityId, title: "Activity", durationMinutes: nil)

    // When: Upsert the activity
    try handler.upsertActivity(dto: dto, context: context)

    // Then: Duration should be nil
    let descriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.id == activityId })
    let activities = try context.fetch(descriptor)
    XCTAssertNil(activities.first?.duration)
  }

  func test_upsertActivity_setsCompletedAt() throws {
    // Given: An existing activity
    let activityId = UUID()
    let existingActivity = makeActivity(id: activityId, title: "Activity")
    existingActivity.markSynced()
    context.insert(existingActivity)
    try context.save()

    // When: Upsert with completedAt
    let completedAt = Date()
    let dto = makeActivityDTO(id: activityId, title: "Activity", completedAt: completedAt)
    try handler.upsertActivity(dto: dto, context: context)

    // Then: completedAt should be set
    let descriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.id == activityId })
    let activities = try context.fetch(descriptor)
    XCTAssertNotNil(activities.first?.completedAt)
  }

  func test_conflictResolver_inFlightActivityCheck() {
    // Given: A conflict resolver
    let activityId1 = UUID()
    let activityId2 = UUID()

    // When: Mark one activity in-flight
    conflictResolver.markActivitiesInFlight([activityId1])

    // Then: Only that activity should be in-flight
    XCTAssertTrue(conflictResolver.isActivityInFlight(activityId1))
    XCTAssertFalse(conflictResolver.isActivityInFlight(activityId2))

    // When: Clear in-flight
    conflictResolver.clearActivitiesInFlight()

    // Then: No activities should be in-flight
    XCTAssertFalse(conflictResolver.isActivityInFlight(activityId1))
  }

  func test_conflictResolver_inFlightActivityAssigneeCheck() {
    // Given: A conflict resolver
    let assigneeId1 = UUID()
    let assigneeId2 = UUID()

    // When: Mark one assignee in-flight
    conflictResolver.markActivityAssigneesInFlight([assigneeId1])

    // Then: Only that assignee should be in-flight
    XCTAssertTrue(conflictResolver.isActivityAssigneeInFlight(assigneeId1))
    XCTAssertFalse(conflictResolver.isActivityAssigneeInFlight(assigneeId2))

    // When: Clear in-flight
    conflictResolver.clearActivityAssigneesInFlight()

    // Then: No assignees should be in-flight
    XCTAssertFalse(conflictResolver.isActivityAssigneeInFlight(assigneeId1))
  }

  func test_conflictResolver_isLocalAuthoritativeForPending() {
    // Given: A pending activity
    let activity = makeActivity(id: UUID(), title: "Pending")
    activity.markPending()

    // When/Then: Should be local-authoritative
    XCTAssertTrue(conflictResolver.isLocalAuthoritative(activity, inFlight: false))
  }

  func test_conflictResolver_isLocalAuthoritativeForFailed() {
    // Given: A failed activity
    let activity = makeActivity(id: UUID(), title: "Failed")
    activity.markFailed("Error")

    // When/Then: Should be local-authoritative
    XCTAssertTrue(conflictResolver.isLocalAuthoritative(activity, inFlight: false))
  }

  func test_conflictResolver_isLocalAuthoritativeForInFlight() {
    // Given: A synced activity that is in-flight
    let activity = makeActivity(id: UUID(), title: "In-flight")
    activity.markSynced()

    // When/Then: Should be local-authoritative when in-flight
    XCTAssertTrue(conflictResolver.isLocalAuthoritative(activity, inFlight: true))
    XCTAssertFalse(conflictResolver.isLocalAuthoritative(activity, inFlight: false))
  }

  // MARK: Private

  // swiftlint:disable implicitly_unwrapped_optional
  private var container: ModelContainer!
  private var context: ModelContext!
  private var handler: ActivitySyncHandler!
  private var conflictResolver: ConflictResolver!

  // swiftlint:enable implicitly_unwrapped_optional

  // MARK: - Test Helpers

  private func makeActivity(
    id: UUID = UUID(),
    title: String = "Test Activity",
    status: ActivityStatus = .open,
    declaredBy: UUID = UUID()
  ) -> Activity {
    Activity(
      id: id,
      title: title,
      activityDescription: "",
      dueDate: nil,
      status: status,
      declaredBy: declaredBy,
      listingId: nil,
      createdVia: .dispatch,
      sourceSlackMessages: nil,
      duration: nil,
      audiencesRaw: ["admin", "marketing"],
      createdAt: Date(),
      updatedAt: Date()
    )
  }

  private func makeActivityDTO(
    id: UUID = UUID(),
    title: String = "Test Activity",
    description: String? = "",
    dueDate: Date? = nil,
    status: String = "open",
    listingId: UUID? = nil,
    durationMinutes: Int? = nil,
    completedAt: Date? = nil,
    deletedAt: Date? = nil
  ) -> ActivityDTO {
    ActivityDTO(
      id: id,
      title: title,
      description: description,
      dueDate: dueDate,
      status: status,
      declaredBy: UUID(),
      listing: listingId,
      createdVia: "dispatch",
      sourceSlackMessages: nil,
      audiences: ["admin", "marketing"],
      durationMinutes: durationMinutes,
      completedAt: completedAt,
      deletedAt: deletedAt,
      createdAt: Date(),
      updatedAt: Date()
    )
  }

  private func makeActivityAssignee(
    id: UUID = UUID(),
    activityId: UUID = UUID(),
    userId: UUID = UUID(),
    assignedBy: UUID = UUID()
  ) -> ActivityAssignee {
    ActivityAssignee(
      id: id,
      activityId: activityId,
      userId: userId,
      assignedBy: assignedBy,
      assignedAt: Date(),
      createdAt: Date(),
      updatedAt: Date()
    )
  }

  private func makeActivityAssigneeDTO(
    id: UUID = UUID(),
    activityId: UUID = UUID(),
    userId: UUID = UUID(),
    assignedBy: UUID = UUID()
  ) -> ActivityAssigneeDTO {
    ActivityAssigneeDTO(
      id: id,
      activityId: activityId,
      userId: userId,
      assignedBy: assignedBy,
      assignedAt: Date(),
      createdAt: Date(),
      updatedAt: Date()
    )
  }

  private func makeActivityTemplateDTO(
    id: UUID = UUID(),
    title: String = "Test Template",
    listingTypeId: UUID,
    position: Int = 0,
    isArchived: Bool = false
  ) -> ActivityTemplateDTO {
    // Create a model first, then use the DTO initializer
    let template = ActivityTemplate(
      id: id,
      title: title,
      templateDescription: "",
      position: position,
      isArchived: isArchived,
      audiencesRaw: [],
      listingTypeId: listingTypeId,
      defaultAssigneeId: nil,
      createdAt: Date(),
      updatedAt: Date()
    )
    return ActivityTemplateDTO(from: template)
  }
}
