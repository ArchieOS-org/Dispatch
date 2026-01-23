//
//  SendableConformanceTests.swift
//  DispatchTests
//
//  Swift 6 regression tests to verify all sync DTOs maintain Sendable conformance.
//  These tests fail to compile if Sendable is removed from any DTO.
//

// swiftlint:disable implicit_return

import Foundation
import Testing
@testable import DispatchApp

// MARK: - SendableConformanceTests

/// Compile-time verification that all sync DTOs conform to Sendable.
/// If Sendable is removed from any DTO, these tests will fail to compile.
struct SendableConformanceTests {

  // MARK: Internal

  // MARK: - Individual DTO Tests

  @Test("TaskDTO conforms to Sendable")
  func testTaskDTOSendable() {
    let dto = TaskDTO(
      id: UUID(),
      title: "Test Task",
      description: "Test description",
      dueDate: Date(),
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

    // This line fails to compile if TaskDTO does not conform to Sendable
    verifySendable(dto)

    // Alternative verification: assign to any Sendable
    let sendable: any Sendable = dto
    _ = sendable
  }

  @Test("ActivityDTO conforms to Sendable")
  func testActivityDTOSendable() {
    let dto = ActivityDTO(
      id: UUID(),
      title: "Test Activity",
      description: "Test description",
      dueDate: Date(),
      status: "open",
      declaredBy: UUID(),
      listing: nil,
      createdVia: "dispatch",
      sourceSlackMessages: nil,
      audiences: nil,
      durationMinutes: 60,
      completedAt: nil,
      deletedAt: nil,
      createdAt: Date(),
      updatedAt: Date()
    )

    verifySendable(dto)

    let sendable: any Sendable = dto
    _ = sendable
  }

  @Test("ListingDTO conforms to Sendable")
  func testListingDTOSendable() {
    let dto = ListingDTO(
      id: UUID(),
      address: "123 Test St",
      city: "Toronto",
      province: "ON",
      postalCode: "M5H 2N2",
      country: "Canada",
      price: 750_000.00,
      mlsNumber: "C1234567",
      realDirt: nil,
      listingType: "sale",
      listingTypeId: nil,
      status: "active",
      stage: "pending",
      ownedBy: UUID(),
      propertyId: nil,
      createdVia: "dispatch",
      sourceSlackMessages: nil,
      activatedAt: nil,
      pendingAt: nil,
      closedAt: nil,
      deletedAt: nil,
      dueDate: nil,
      createdAt: Date(),
      updatedAt: Date()
    )

    verifySendable(dto)

    let sendable: any Sendable = dto
    _ = sendable
  }

  @Test("UserDTO conforms to Sendable")
  func testUserDTOSendable() {
    let dto = UserDTO(
      id: UUID(),
      name: "Test User",
      email: "test@example.com",
      avatarPath: nil,
      avatarHash: nil,
      userType: "admin",
      createdAt: Date(),
      updatedAt: Date()
    )

    verifySendable(dto)

    let sendable: any Sendable = dto
    _ = sendable
  }

  @Test("NoteDTO conforms to Sendable")
  func testNoteDTOSendable() {
    let dto = NoteDTO(
      id: UUID(),
      content: "Test note content",
      createdBy: UUID(),
      parentType: "task",
      parentId: UUID(),
      editedAt: nil,
      editedBy: nil,
      createdAt: Date(),
      updatedAt: nil,
      deletedAt: nil,
      deletedBy: nil
    )

    verifySendable(dto)

    let sendable: any Sendable = dto
    _ = sendable
  }

  // MARK: - Comprehensive Test

  @Test("All sync DTOs conform to Sendable")
  func testAllSyncDTOsSendable() {
    // Create instances of all sync DTOs
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

    let listingDTO = ListingDTO(
      id: UUID(),
      address: "Address",
      city: nil,
      province: nil,
      postalCode: nil,
      country: nil,
      price: nil,
      mlsNumber: nil,
      realDirt: nil,
      listingType: "sale",
      listingTypeId: nil,
      status: "draft",
      stage: nil,
      ownedBy: UUID(),
      propertyId: nil,
      createdVia: "dispatch",
      sourceSlackMessages: nil,
      activatedAt: nil,
      pendingAt: nil,
      closedAt: nil,
      deletedAt: nil,
      dueDate: nil,
      createdAt: Date(),
      updatedAt: Date()
    )

    let userDTO = UserDTO(
      id: UUID(),
      name: "User",
      email: "user@example.com",
      avatarPath: nil,
      avatarHash: nil,
      userType: "realtor",
      createdAt: Date(),
      updatedAt: Date()
    )

    let noteDTO = NoteDTO(
      id: UUID(),
      content: "Note",
      createdBy: UUID(),
      parentType: "task",
      parentId: UUID(),
      editedAt: nil,
      editedBy: nil,
      createdAt: Date(),
      updatedAt: nil,
      deletedAt: nil,
      deletedBy: nil
    )

    // All of these must compile - if any DTO loses Sendable, this test fails to compile
    verifySendable(taskDTO)
    verifySendable(activityDTO)
    verifySendable(listingDTO)
    verifySendable(userDTO)
    verifySendable(noteDTO)
  }

  // MARK: - Async Context Tests

  @Test("DTOs can be passed across actor boundaries")
  @MainActor
  func testDTOsCanCrossActorBoundary() async {
    let taskDTO = TaskDTO(
      id: UUID(),
      title: "Async Test Task",
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

    // Simulate the pattern from ChannelLifecycleManager:
    // Task { @MainActor in ... handleDTO(...) }
    // This verifies DTOs can be captured in @MainActor Task closures
    let result = await Task { @MainActor in
      // This simulates the delegate callback pattern
      return taskDTO.title
    }.value

    #expect(result == "Async Test Task")
  }

  @Test("DTOs maintain data integrity across Task boundaries")
  @MainActor
  func testDTODataIntegrityAcrossTaskBoundaries() async {
    let originalId = UUID()
    let originalTitle = "Original Title"

    let dto = TaskDTO(
      id: originalId,
      title: originalTitle,
      description: "Description",
      dueDate: Date(),
      status: "in_progress",
      declaredBy: UUID(),
      listing: nil,
      createdVia: "slack",
      sourceSlackMessages: ["msg1", "msg2"],
      audiences: ["admin"],
      completedAt: nil,
      deletedAt: nil,
      createdAt: Date(),
      updatedAt: Date()
    )

    // Pass DTO through Task boundary (simulates realtime handler pattern)
    let (capturedId, capturedTitle) = await Task { @MainActor in
      return (dto.id, dto.title)
    }.value

    #expect(capturedId == originalId)
    #expect(capturedTitle == originalTitle)
  }

  // MARK: Private

  // MARK: - Helper Function

  /// Generic function that requires Sendable conformance.
  /// Passing a non-Sendable type to this function causes a compile error.
  private func verifySendable(_: some Sendable) {
    // Intentionally empty - compile-time verification only
  }

}
