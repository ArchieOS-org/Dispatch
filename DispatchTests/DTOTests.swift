//
//  DTOTests.swift
//  DispatchTests
//
//  Tests for Data Transfer Objects used in Supabase sync
//  Tests: TaskDTO, ListingDTO, UserDTO, NoteDTO, SubtaskDTO
//  Created by Test Generation on 2025-12-08.
//  Updated to match current codebase APIs.
//

// swiftlint:disable force_unwrapping

import Foundation
import Testing
@testable import DispatchApp

// MARK: - TaskDTOTests

struct TaskDTOTests {

  @Test("TaskDTO decodes from JSON correctly")
  func testDecodeFromJSON() throws {
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
    let dto = try decoder.decode(TaskDTO.self, from: json)

    #expect(dto.title == "Test Task")
    #expect(dto.description == "Test description")
    #expect(dto.status == "open")
    #expect(dto.createdVia == "dispatch")
    #expect(dto.listing == nil)
  }

  @Test("TaskDTO converts to TaskItem model correctly")
  func testToModel() {
    let id = UUID()
    let declaredBy = UUID()
    let dto = TaskDTO(
      id: id,
      title: "Test Task",
      description: "Description",
      dueDate: Date(),
      status: "in_progress",
      declaredBy: declaredBy,
      listing: nil,
      createdVia: "slack",
      sourceSlackMessages: ["message1", "message2"],
      audiences: nil,
      completedAt: nil,
      deletedAt: nil,
      createdAt: Date(),
      updatedAt: Date()
    )

    let model = dto.toModel()

    #expect(model.id == id)
    #expect(model.title == "Test Task")
    #expect(model.taskDescription == "Description")
    #expect(model.status == TaskStatus.inProgress)
    #expect(model.declaredBy == declaredBy)
    #expect(model.createdVia == CreationSource.slack)
    #expect(model.sourceSlackMessages?.count == 2)
  }

  @Test("TaskDTO handles nil description")
  func testNilDescription() {
    let dto = TaskDTO(
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

    let model = dto.toModel()
    #expect(model.taskDescription.isEmpty)
  }

  @Test("TaskDTO handles invalid status gracefully")
  func testInvalidStatus() {
    let dto = TaskDTO(
      id: UUID(),
      title: "Task",
      description: nil,
      dueDate: nil,
      status: "invalid_status",
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

    let model = dto.toModel()
    #expect(model.status == .open) // Falls back to default
  }
}

// MARK: - UserDTOTests

struct UserDTOTests {

  @Test("UserDTO decodes from JSON correctly")
  func testDecodeFromJSON() throws {
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

    #expect(dto.name == "John Doe")
    #expect(dto.email == "john@example.com")
    #expect(dto.userType == "admin")
  }

  @Test("UserDTO converts to User model correctly")
  func testToModel() {
    let id = UUID()
    let dto = UserDTO(
      id: id,
      name: "Jane Smith",
      email: "jane@example.com",
      avatarPath: nil,
      avatarHash: nil,
      userType: "marketing",
      createdAt: Date(),
      updatedAt: Date()
    )

    let model = dto.toModel()

    #expect(model.id == id)
    #expect(model.name == "Jane Smith")
    #expect(model.email == "jane@example.com")
    #expect(model.userType == UserType.marketing)
  }
}

// MARK: - ListingDTOTests

struct ListingDTOTests {

  @Test("ListingDTO decodes from JSON correctly")
  func testDecodeFromJSON() throws {
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
          "stage": null,
          "owned_by": "550e8400-e29b-41d4-a716-446655440001",
          "property_id": null,
          "created_via": "realtor_app",
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

    #expect(dto.address == "123 Main St")
    #expect(dto.city == "Toronto")
    #expect(dto.province == "ON")
    #expect(dto.listingType == "sale")
    #expect(dto.status == "active")
  }

  @Test("ListingDTO converts to Listing model correctly")
  func testToModel() {
    let id = UUID()
    let ownedBy = UUID()
    let dto = ListingDTO(
      id: id,
      address: "456 Oak Ave",
      city: "Vancouver",
      province: "BC",
      postalCode: "V6B 1A1",
      country: "Canada",
      price: 1200000.00,
      mlsNumber: "V9876543",
      listingType: "lease",
      listingTypeId: nil,
      status: "active",
      stage: nil,
      ownedBy: ownedBy,
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

    let model = dto.toModel()

    #expect(model.id == id)
    #expect(model.address == "456 Oak Ave")
    #expect(model.city == "Vancouver")
    #expect(model.listingType == ListingType.lease)
    #expect(model.status == ListingStatus.active)
    #expect(model.ownedBy == ownedBy)
  }
}

// MARK: - NoteDTOTests

struct NoteDTOTests {

  @Test("NoteDTO decodes from JSON correctly")
  func testDecodeFromJSON() throws {
    let json = """
      {
          "id": "550e8400-e29b-41d4-a716-446655440000",
          "content": "This is a test note",
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

    #expect(dto.content == "This is a test note")
    #expect(dto.parentType == "task")
    #expect(dto.editedAt == nil)
    #expect(dto.editedBy == nil)
  }

  @Test("NoteDTO converts to Note model correctly")
  func testToModel() {
    let id = UUID()
    let createdBy = UUID()
    let parentId = UUID()
    let dto = NoteDTO(
      id: id,
      content: "Important note",
      createdBy: createdBy,
      parentType: "activity",
      parentId: parentId,
      editedAt: nil,
      editedBy: nil,
      createdAt: Date(),
      updatedAt: nil,
      deletedAt: nil,
      deletedBy: nil
    )

    let model = dto.toModel()

    #expect(model.id == id)
    #expect(model.content == "Important note")
    #expect(model.createdBy == createdBy)
    #expect(model.parentType == ParentType.activity)
    #expect(model.parentId == parentId)
  }
}

// MARK: - SubtaskDTOTests

struct SubtaskDTOTests {

  @Test("SubtaskDTO decodes from JSON correctly")
  func testDecodeFromJSON() throws {
    let json = """
      {
          "id": "550e8400-e29b-41d4-a716-446655440000",
          "title": "Review documents",
          "completed": false,
          "parent_type": "task",
          "parent_id": "550e8400-e29b-41d4-a716-446655440001",
          "created_at": "2025-01-01T00:00:00Z"
      }
      """.data(using: .utf8)!

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let dto = try decoder.decode(SubtaskDTO.self, from: json)

    #expect(dto.title == "Review documents")
    #expect(dto.completed == false)
    #expect(dto.parentType == "task")
  }

  @Test("SubtaskDTO converts to Subtask model correctly")
  func testToModel() {
    let id = UUID()
    let parentId = UUID()
    let dto = SubtaskDTO(
      id: id,
      title: "Complete checklist",
      completed: true,
      parentType: "activity",
      parentId: parentId,
      createdAt: Date()
    )

    let model = dto.toModel()

    #expect(model.id == id)
    #expect(model.title == "Complete checklist")
    #expect(model.completed == true)
    #expect(model.parentType == .activity)
    #expect(model.parentId == parentId)
  }
}

// MARK: - AudienceNormalizationTests

/// Tests for audience mutual exclusivity enforcement (DIS-75)
struct AudienceNormalizationTests {

  // MARK: - normalizeAudiences() Tests

  @Test("normalizeAudiences returns admin when both audiences present")
  func testNormalizeBothAudiences() {
    let result = normalizeAudiences(["admin", "marketing"])
    #expect(result == ["admin"])
  }

  @Test("normalizeAudiences preserves single admin audience")
  func testNormalizeSingleAdmin() {
    let result = normalizeAudiences(["admin"])
    #expect(result == ["admin"])
  }

  @Test("normalizeAudiences preserves single marketing audience")
  func testNormalizeSingleMarketing() {
    let result = normalizeAudiences(["marketing"])
    #expect(result == ["marketing"])
  }

  @Test("normalizeAudiences defaults to admin for nil input")
  func testNormalizeNil() {
    let result = normalizeAudiences(nil)
    #expect(result == ["admin"])
  }

  @Test("normalizeAudiences defaults to admin for empty array")
  func testNormalizeEmpty() {
    let result = normalizeAudiences([])
    #expect(result == ["admin"])
  }

  @Test("normalizeAudiences defaults to admin for unknown values")
  func testNormalizeUnknown() {
    let result = normalizeAudiences(["unknown", "garbage"])
    #expect(result == ["admin"])
  }

  @Test("normalizeAudiences prefers admin over marketing when both present with extras")
  func testNormalizeWithExtras() {
    let result = normalizeAudiences(["marketing", "admin", "extra"])
    #expect(result == ["admin"])
  }

  // MARK: - normalizeTemplateAudiences() Tests

  @Test("normalizeTemplateAudiences preserves empty array")
  func testTemplateNormalizeEmpty() {
    let result = normalizeTemplateAudiences([])
    #expect(result == [])
  }

  @Test("normalizeTemplateAudiences normalizes multiple to admin")
  func testTemplateNormalizeBoth() {
    let result = normalizeTemplateAudiences(["admin", "marketing"])
    #expect(result == ["admin"])
  }

  @Test("normalizeTemplateAudiences preserves single admin")
  func testTemplateNormalizeSingleAdmin() {
    let result = normalizeTemplateAudiences(["admin"])
    #expect(result == ["admin"])
  }

  @Test("normalizeTemplateAudiences preserves single marketing")
  func testTemplateNormalizeSingleMarketing() {
    let result = normalizeTemplateAudiences(["marketing"])
    #expect(result == ["marketing"])
  }

  @Test("normalizeTemplateAudiences defaults unknown to admin")
  func testTemplateNormalizeUnknown() {
    let result = normalizeTemplateAudiences(["unknown"])
    #expect(result == ["admin"])
  }

  // MARK: - TaskDTO Audience Normalization Integration

  @Test("TaskDTO.toModel normalizes multiple audiences to admin")
  func testTaskDTONormalizesAudiences() {
    let dto = TaskDTO(
      id: UUID(),
      title: "Test",
      description: nil,
      dueDate: nil,
      status: "open",
      declaredBy: UUID(),
      listing: nil,
      createdVia: "dispatch",
      sourceSlackMessages: nil,
      audiences: ["admin", "marketing"],
      completedAt: nil,
      deletedAt: nil,
      createdAt: Date(),
      updatedAt: Date()
    )

    let model = dto.toModel()
    #expect(model.audiencesRaw == ["admin"])
  }

  @Test("TaskDTO.toModel defaults nil audiences to admin")
  func testTaskDTODefaultsNilAudiences() {
    let dto = TaskDTO(
      id: UUID(),
      title: "Test",
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

    let model = dto.toModel()
    #expect(model.audiencesRaw == ["admin"])
  }

  // MARK: - ActivityDTO Audience Normalization Integration

  @Test("ActivityDTO.toModel normalizes multiple audiences to admin")
  func testActivityDTONormalizesAudiences() {
    let dto = ActivityDTO(
      id: UUID(),
      title: "Test",
      description: nil,
      dueDate: nil,
      status: "open",
      declaredBy: UUID(),
      listing: nil,
      createdVia: "dispatch",
      sourceSlackMessages: nil,
      audiences: ["admin", "marketing"],
      durationMinutes: nil,
      completedAt: nil,
      deletedAt: nil,
      createdAt: Date(),
      updatedAt: Date()
    )

    let model = dto.toModel()
    #expect(model.audiencesRaw == ["admin"])
  }

  @Test("ActivityDTO.toModel preserves single marketing audience")
  func testActivityDTOPreservesMarketing() {
    let dto = ActivityDTO(
      id: UUID(),
      title: "Test",
      description: nil,
      dueDate: nil,
      status: "open",
      declaredBy: UUID(),
      listing: nil,
      createdVia: "dispatch",
      sourceSlackMessages: nil,
      audiences: ["marketing"],
      durationMinutes: nil,
      completedAt: nil,
      deletedAt: nil,
      createdAt: Date(),
      updatedAt: Date()
    )

    let model = dto.toModel()
    #expect(model.audiencesRaw == ["marketing"])
  }
}
