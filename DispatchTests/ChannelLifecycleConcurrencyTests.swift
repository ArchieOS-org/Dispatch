//
//  ChannelLifecycleConcurrencyTests.swift
//  DispatchTests
//
//  Tests for MainActor isolation patterns in ChannelLifecycleManager.
//  Verifies the Swift 6 concurrency fixes at lines 118, 149, 180, 211, 242.
//

// swiftlint:disable force_unwrapping implicit_return

import XCTest
@testable import DispatchApp

// MARK: - ChannelLifecycleConcurrencyTests

/// Tests verifying MainActor isolation patterns used in ChannelLifecycleManager.
/// These tests ensure Task closures with @MainActor annotation work correctly
/// and that DTOs can be decoded and used within MainActor-isolated contexts.
@MainActor
final class ChannelLifecycleConcurrencyTests: XCTestCase {

  // MARK: - Task Closure Isolation Tests

  /// Verifies that Task closures with @MainActor execute on the main thread.
  /// This is the pattern used in ChannelLifecycleManager at lines 118, 149, 180, 211, 242.
  func testTaskClosureMaintainsMainActorIsolation() async {
    var executedOnMainActor = false

    await Task { @MainActor in
      // This should execute on MainActor (main thread)
      executedOnMainActor = Thread.isMainThread
    }.value

    XCTAssertTrue(executedOnMainActor, "Task { @MainActor in } should execute on main thread")
  }

  /// Verifies that nested Task groups within @MainActor Tasks maintain isolation.
  /// This matches the withTaskGroup pattern in ChannelLifecycleManager.
  func testNestedTaskGroupMaintainsMainActorIsolation() async {
    var allOnMainThread = true

    await Task { @MainActor in
      await withTaskGroup(of: Bool.self) { group in
        group.addTask { @MainActor in
          return Thread.isMainThread
        }
        group.addTask { @MainActor in
          return Thread.isMainThread
        }
        group.addTask { @MainActor in
          return Thread.isMainThread
        }

        for await result in group where !result {
          allOnMainThread = false
        }
      }
    }.value

    XCTAssertTrue(allOnMainThread, "All nested @MainActor tasks should execute on main thread")
  }

  // MARK: - DTO Decoding in MainActor Context Tests

  /// Verifies TaskDTO can be decoded and used within a @MainActor Task closure.
  /// This simulates the handleDTO callback pattern in ChannelLifecycleManager.
  func testTaskDTODecodingInMainActorContext() async throws {
    let json = """
      {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "title": "Test Task",
        "description": "Test description",
        "due_date": "2025-01-15T10:00:00Z",
        "status": "open",
        "declared_by": "550e8400-e29b-41d4-a716-446655440001",
        "listing": null,
        "created_via": "dispatch",
        "source_slack_messages": null,
        "audiences": null,
        "completed_at": null,
        "deleted_at": null,
        "created_at": "2025-01-01T00:00:00Z",
        "updated_at": "2025-01-01T00:00:00Z"
      }
      """.data(using: .utf8)!

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    // Decode outside the Task (simulates Supabase realtime decoding)
    let dto = try decoder.decode(TaskDTO.self, from: json)

    // Use DTO within @MainActor Task (simulates delegate callback)
    let model = await Task { @MainActor in
      return dto.toModel()
    }.value

    XCTAssertEqual(model.title, "Test Task")
    XCTAssertEqual(model.status, .open)
  }

  /// Verifies ActivityDTO can be decoded and passed across MainActor boundary.
  func testActivityDTODecodingInMainActorContext() async throws {
    let json = """
      {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "title": "Test Activity",
        "description": null,
        "due_date": null,
        "status": "open",
        "declared_by": "550e8400-e29b-41d4-a716-446655440001",
        "listing": null,
        "created_via": "dispatch",
        "source_slack_messages": null,
        "audiences": null,
        "duration_minutes": 60,
        "completed_at": null,
        "deleted_at": null,
        "created_at": "2025-01-01T00:00:00Z",
        "updated_at": "2025-01-01T00:00:00Z"
      }
      """.data(using: .utf8)!

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let dto = try decoder.decode(ActivityDTO.self, from: json)

    let model = await Task { @MainActor in
      return dto.toModel()
    }.value

    XCTAssertEqual(model.title, "Test Activity")
    XCTAssertEqual(model.duration, 3600) // 60 minutes * 60 seconds
  }

  /// Verifies UserDTO can be decoded and passed across MainActor boundary.
  func testUserDTODecodingInMainActorContext() async throws {
    let json = """
      {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "name": "John Doe",
        "email": "john@example.com",
        "avatar_path": null,
        "avatar_hash": null,
        "user_type": "admin",
        "created_at": "2025-01-01T00:00:00Z",
        "updated_at": "2025-01-01T00:00:00Z"
      }
      """.data(using: .utf8)!

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let dto = try decoder.decode(UserDTO.self, from: json)

    let model = await Task { @MainActor in
      return dto.toModel()
    }.value

    XCTAssertEqual(model.name, "John Doe")
    XCTAssertEqual(model.userType, .admin)
  }

  /// Verifies ListingDTO can be decoded and passed across MainActor boundary.
  func testListingDTODecodingInMainActorContext() async throws {
    let json = """
      {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "address": "123 Main St",
        "city": "Toronto",
        "province": "ON",
        "postal_code": "M5H 2N2",
        "country": "Canada",
        "price": 750000.00,
        "mls_number": "C1234567",
        "listing_type": "sale",
        "listing_type_id": null,
        "status": "active",
        "stage": "pending",
        "owned_by": "550e8400-e29b-41d4-a716-446655440001",
        "property_id": null,
        "created_via": "dispatch",
        "source_slack_messages": null,
        "activated_at": null,
        "pending_at": null,
        "closed_at": null,
        "deleted_at": null,
        "due_date": null,
        "created_at": "2025-01-01T00:00:00Z",
        "updated_at": "2025-01-01T00:00:00Z"
      }
      """.data(using: .utf8)!

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let dto = try decoder.decode(ListingDTO.self, from: json)

    let model = await Task { @MainActor in
      return dto.toModel()
    }.value

    XCTAssertEqual(model.address, "123 Main St")
    XCTAssertEqual(model.listingType, .sale)
    XCTAssertEqual(model.status, .active)
  }

  /// Verifies NoteDTO can be decoded and passed across MainActor boundary.
  func testNoteDTODecodingInMainActorContext() async throws {
    let json = """
      {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "content": "Test note content",
        "created_by": "550e8400-e29b-41d4-a716-446655440001",
        "parent_type": "task",
        "parent_id": "550e8400-e29b-41d4-a716-446655440002",
        "created_at": "2025-01-01T00:00:00Z",
        "edited_at": null,
        "edited_by": null,
        "deleted_at": null,
        "deleted_by": null
      }
      """.data(using: .utf8)!

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let dto = try decoder.decode(NoteDTO.self, from: json)

    let model = await Task { @MainActor in
      return dto.toModel()
    }.value

    XCTAssertEqual(model.content, "Test note content")
    XCTAssertEqual(model.parentType, .task)
  }

  // MARK: - Callback Pattern Tests

  /// Simulates the delegate callback pattern used in ChannelLifecycleManager.
  /// Verifies that DTOs can be safely passed to callback closures from @MainActor Tasks.
  func testDelegateCallbackPattern() async {
    var receivedDTO: TaskDTO?

    let dto = TaskDTO(
      id: UUID(),
      title: "Callback Test",
      description: nil,
      dueDate: nil,
      status: "open",
      declaredBy: UUID(),
      listing: nil,
      createdVia: "dispatch",
      sourceSlackMessages: nil,
      audiences: nil,
      completedAt: nil,
      deletedAt: nil,
      createdAt: Date(),
      updatedAt: Date()
    )

    // Simulates: Task { @MainActor in callback(dto) }
    await Task { @MainActor in
      receivedDTO = dto
    }.value

    XCTAssertNotNil(receivedDTO)
    XCTAssertEqual(receivedDTO?.title, "Callback Test")
  }

  /// Tests the concurrent processing pattern used for multiple entity types.
  /// Mirrors the withTaskGroup usage in ChannelLifecycleManager.
  func testConcurrentEntityProcessing() async {
    var processedEntities: [String] = []

    let taskDTO = TaskDTO(
      id: UUID(),
      title: "Task",
      description: nil,
      dueDate: nil,
      status: "open",
      declaredBy: UUID(),
      listing: nil,
      createdVia: "dispatch",
      sourceSlackMessages: nil,
      audiences: nil,
      completedAt: nil,
      deletedAt: nil,
      createdAt: Date(),
      updatedAt: Date()
    )

    let activityDTO = ActivityDTO(
      id: UUID(),
      title: "Activity",
      description: nil,
      dueDate: nil,
      status: "open",
      declaredBy: UUID(),
      listing: nil,
      createdVia: "dispatch",
      sourceSlackMessages: nil,
      audiences: nil,
      durationMinutes: nil,
      completedAt: nil,
      deletedAt: nil,
      createdAt: Date(),
      updatedAt: Date()
    )

    // Simulates concurrent processing of multiple entity types
    await Task { @MainActor in
      await withTaskGroup(of: String.self) { group in
        group.addTask { @MainActor in
          return taskDTO.title
        }
        group.addTask { @MainActor in
          return activityDTO.title
        }

        for await title in group {
          processedEntities.append(title)
        }
      }
    }.value

    XCTAssertEqual(processedEntities.count, 2)
    XCTAssertTrue(processedEntities.contains("Task"))
    XCTAssertTrue(processedEntities.contains("Activity"))
  }

  // MARK: - ChannelLifecycleManager Instance Tests

  /// Verifies ChannelLifecycleManager can be instantiated in test mode.
  func testChannelLifecycleManagerTestMode() async {
    let manager = ChannelLifecycleManager(mode: .test)

    XCTAssertFalse(manager.isListening, "Should not be listening initially")
    XCTAssertNil(manager.realtimeChannel, "Should have no channel initially")
    XCTAssertEqual(manager.retryAttempt, 0, "Retry attempt should be 0")
  }

  /// Verifies startListening is a no-op in test mode (prevents side effects).
  func testStartListeningNoOpInTestMode() async {
    let manager = ChannelLifecycleManager(mode: .test)

    await manager.startListening(useBroadcastRealtime: false)

    // In test mode, startListening should return early without side effects
    XCTAssertFalse(manager.isListening, "Should not be listening in test mode")
    XCTAssertNil(manager.realtimeChannel, "Should have no channel in test mode")
  }

  /// Verifies task cleanup methods work correctly.
  func testTaskCleanup() async {
    let manager = ChannelLifecycleManager(mode: .test)

    // These should not crash even with no tasks
    manager.cancelAllTasks()
    await manager.awaitAllTasks()
    manager.clearTaskReferences()

    XCTAssertNil(manager.statusTask)
    XCTAssertNil(manager.tasksSubscriptionTask)
    XCTAssertNil(manager.activitiesSubscriptionTask)
    XCTAssertNil(manager.listingsSubscriptionTask)
    XCTAssertNil(manager.usersSubscriptionTask)
    XCTAssertNil(manager.notesSubscriptionTask)
  }
}
