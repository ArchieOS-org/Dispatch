//
//  DTOTests.swift
//  DispatchTests
//
//  Tests for Data Transfer Objects used in Supabase sync
//  Tests: TaskDTO, ActivityDTO, ListingDTO, UserDTO, NoteDTO, SubtaskDTO, ClaimEventDTO
//  Created by Test Generation on 2025-12-08.
//

// swiftlint:disable force_unwrapping

import Testing
import Foundation
@testable import DispatchApp

struct TaskDTOTests {
    
    @Test("TaskDTO decodes from JSON correctly")
    func testDecodeFromJSON() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "title": "Test Task",
            "description": "Test description",
            "due_date": "2025-01-15T10:00:00Z",
            "priority": "high",
            "status": "open",
            "declared_by": "550e8400-e29b-41d4-a716-446655440001",
            "claimed_by": null,
            "listing": null,
            "created_via": "dispatch",
            "source_slack_messages": null,
            "claimed_at": null,
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
        #expect(dto.priority == "high")
        #expect(dto.status == "open")
        #expect(dto.createdVia == "dispatch")
        #expect(dto.claimedBy == nil)
        #expect(dto.listing == nil)
    }
    
    @Test("TaskDTO encodes to JSON correctly")
    func testEncodeToJSON() throws {
        let id = UUID()
        let declaredBy = UUID()
        let dto = TaskDTO(
            id: id,
            title: "Test Task",
            description: "Test description",
            dueDate: nil,
            priority: "medium",
            status: "open",
            declaredBy: declaredBy,
            claimedBy: nil,
            listing: nil,
            createdVia: "dispatch",
            sourceSlackMessages: nil,
            audiences: nil,
            claimedAt: nil,
            completedAt: nil,
            deletedAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(dto)
        
        // Verify it can be decoded back
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TaskDTO.self, from: data)
        
        #expect(decoded.id == id)
        #expect(decoded.title == "Test Task")
        #expect(decoded.priority == "medium")
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
            priority: "urgent",
            status: "in_progress",
            declaredBy: declaredBy,
            claimedBy: nil,
            listing: nil,
            createdVia: "slack",
            sourceSlackMessages: ["message1", "message2"],
            audiences: nil,
            claimedAt: nil,
            completedAt: nil,
            deletedAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let model = dto.toModel()
        
        #expect(model.id == id)
        #expect(model.title == "Test Task")
        #expect(model.taskDescription == "Description")
        #expect(model.priority == Priority.urgent)
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
            priority: "low",
            status: "open",
            declaredBy: UUID(),
            claimedBy: nil,
            listing: nil,
            createdVia: "dispatch",
            sourceSlackMessages: nil,
            audiences: nil,
            claimedAt: nil,
            completedAt: nil,
            deletedAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let model = dto.toModel()
        #expect(model.taskDescription.isEmpty)
    }
    
    @Test("TaskDTO handles invalid priority gracefully")
    func testInvalidPriority() {
        let dto = TaskDTO(
            id: UUID(),
            title: "Task",
            description: nil,
            dueDate: nil,
            priority: "invalid_priority",
            status: "open",
            declaredBy: UUID(),
            claimedBy: nil,
            listing: nil,
            createdVia: "dispatch",
            sourceSlackMessages: nil,
            audiences: nil,
            claimedAt: nil,
            completedAt: nil,
            deletedAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let model = dto.toModel()
        #expect(model.priority == .medium) // Falls back to default
    }
    
    @Test("TaskDTO handles invalid status gracefully")
    func testInvalidStatus() {
        let dto = TaskDTO(
            id: UUID(),
            title: "Task",
            description: nil,
            dueDate: nil,
            priority: "low",
            status: "invalid_status",
            declaredBy: UUID(),
            claimedBy: nil,
            listing: nil,
            createdVia: "dispatch",
            sourceSlackMessages: nil,
            audiences: nil,
            claimedAt: nil,
            completedAt: nil,
            deletedAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let model = dto.toModel()
        #expect(model.status == .open) // Falls back to default
    }
}

struct ActivityDTOTests {
    
    @Test("ActivityDTO decodes from JSON correctly")
    func testDecodeFromJSON() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "title": "Client Call",
            "description": "Follow up call",
            "activity_type": "call",
            "due_date": "2025-01-15T14:00:00Z",
            "priority": "high",
            "status": "open",
            "declared_by": "550e8400-e29b-41d4-a716-446655440001",
            "claimed_by": null,
            "listing": null,
            "created_via": "dispatch",
            "source_slack_messages": null,
            "duration_minutes": 30,
            "claimed_at": null,
            "completed_at": null,
            "deleted_at": null,
            "created_at": "2025-01-01T00:00:00Z",
            "updated_at": "2025-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(ActivityDTO.self, from: json)
        
        #expect(dto.title == "Client Call")
        #expect(dto.activityType == "call")
        #expect(dto.durationMinutes == 30)
        #expect(dto.priority == "high")
    }
    
    @Test("ActivityDTO converts to Activity model correctly")
    func testToModel() {
        let id = UUID()
        let declaredBy = UUID()
        let dto = ActivityDTO(
            id: id,
            title: "Property Showing",
            description: "Show property to client",
            activityType: "show_property",
            dueDate: Date(),
            priority: "urgent",
            status: "in_progress",
            declaredBy: declaredBy,
            claimedBy: nil,
            listing: nil,
            createdVia: "realtor_app",
            sourceSlackMessages: nil,
            audiences: nil,
            durationMinutes: 60,
            claimedAt: nil,
            completedAt: nil,
            deletedAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let model = dto.toModel()
        
        #expect(model.id == id)
        #expect(model.title == "Property Showing")
        #expect(model.type == ActivityType.showProperty)
        #expect(model.duration == 3600.0) // 60 minutes in seconds
        #expect(model.status == ActivityStatus.inProgress)
    }
    
    @Test("ActivityDTO handles nil duration")
    func testNilDuration() {
        let dto = ActivityDTO(
            id: UUID(),
            title: "Email",
            description: nil,
            activityType: "email",
            dueDate: nil,
            priority: "low",
            status: "open",
            declaredBy: UUID(),
            claimedBy: nil,
            listing: nil,
            createdVia: "dispatch",
            sourceSlackMessages: nil,
            audiences: nil,
            durationMinutes: nil,
            claimedAt: nil,
            completedAt: nil,
            deletedAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let model = dto.toModel()
        #expect(model.duration == nil)
    }
}

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
            "country": "Canada",
            "price": 750000.00,
            "mls_number": "C1234567",
            "listing_type": "sale",
            "status": "active",
            "owned_by": "550e8400-e29b-41d4-a716-446655440001",
            "created_via": "realtor_app",
            "source_slack_messages": null,
            "activated_at": null,
            "pending_at": null,
            "closed_at": null,
            "deleted_at": null,
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
            status: "active",
            ownedBy: ownedBy,
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

    @Test("ListingDTO ignores unknown keys in JSON (e.g., deprecated assigned_staff)")
    func testIgnoresUnknownKeys() throws {
        // This JSON includes 'assigned_staff' which is no longer in the DTO schema
        // The decoder should ignore it without throwing
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "address": "789 Legacy Lane",
            "city": "Calgary",
            "province": "AB",
            "postal_code": "T2P 1A1",
            "country": "Canada",
            "country": "Canada",
            "price": 500000.00,
            "mls_number": "A7654321",
            "listing_type": "sale",
            "status": "active",
            "owned_by": "550e8400-e29b-41d4-a716-446655440001",
            "assigned_staff": "550e8400-e29b-41d4-a716-446655440002",
            "created_via": "dispatch",
            "source_slack_messages": null,
            "activated_at": null,
            "pending_at": null,
            "closed_at": null,
            "deleted_at": null,
            "created_at": "2025-01-01T00:00:00Z",
            "updated_at": "2025-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Should not throw even though assigned_staff is present
        let dto = try decoder.decode(ListingDTO.self, from: json)

        #expect(dto.address == "789 Legacy Lane")
        #expect(dto.city == "Calgary")
        #expect(dto.status == "active")
    }
}

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
            "edited_by": null
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
            createdAt: Date()
        )
        
        let model = dto.toModel()
        
        #expect(model.id == id)
        #expect(model.content == "Important note")
        #expect(model.createdBy == createdBy)
        #expect(model.parentType == ParentType.activity)
        #expect(model.parentId == parentId)
    }
}

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

struct ClaimEventDTOTests {

    @Test("ClaimEventDTO decodes from JSON correctly")
    func testDecodeFromJSON() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "parent_type": "task",
            "parent_id": "550e8400-e29b-41d4-a716-446655440001",
            "action": "claimed",
            "user_id": "550e8400-e29b-41d4-a716-446655440002",
            "performed_at": "2025-01-15T10:00:00Z",
            "reason": "Taking ownership",
            "created_at": "2025-01-01T00:00:00Z",
            "updated_at": "2025-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(ClaimEventDTO.self, from: json)

        #expect(dto.parentType == "task")
        #expect(dto.action == "claimed")
        #expect(dto.reason == "Taking ownership")
    }

    @Test("ClaimEventDTO encodes to JSON correctly")
    func testEncodeToJSON() throws {
        let id = UUID()
        let parentId = UUID()
        let userId = UUID()
        let now = Date()
        let dto = ClaimEventDTO(
            id: id,
            parentType: "activity",
            parentId: parentId,
            action: "released",
            userId: userId,
            performedAt: now,
            reason: "Reassigning",
            createdAt: now,
            updatedAt: now
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(dto)

        // Verify it can be decoded back
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ClaimEventDTO.self, from: data)

        #expect(decoded.id == id)
        #expect(decoded.parentType == "activity")
        #expect(decoded.action == "released")
        #expect(decoded.reason == "Reassigning")
    }

    @Test("ClaimEventDTO converts to ClaimEvent model correctly")
    func testToModel() {
        let id = UUID()
        let parentId = UUID()
        let userId = UUID()
        let performedAt = Date()
        let createdAt = Date().addingTimeInterval(-3600)
        let updatedAt = Date()
        let dto = ClaimEventDTO(
            id: id,
            parentType: "task",
            parentId: parentId,
            action: "claimed",
            userId: userId,
            performedAt: performedAt,
            reason: "I'll handle this",
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let model = dto.toModel()

        #expect(model.id == id)
        #expect(model.parentType == .task)
        #expect(model.parentId == parentId)
        #expect(model.action == .claimed)
        #expect(model.userId == userId)
        #expect(model.reason == "I'll handle this")
        #expect(model.createdAt == createdAt)
        #expect(model.updatedAt == updatedAt)
    }

    @Test("ClaimEventDTO handles nil reason")
    func testNilReason() {
        let dto = ClaimEventDTO(
            id: UUID(),
            parentType: "task",
            parentId: UUID(),
            action: "claimed",
            userId: UUID(),
            performedAt: Date(),
            reason: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        let model = dto.toModel()
        #expect(model.reason == nil)
    }

    @Test("ClaimEventDTO handles invalid action gracefully")
    func testInvalidAction() {
        let dto = ClaimEventDTO(
            id: UUID(),
            parentType: "task",
            parentId: UUID(),
            action: "invalid_action",
            userId: UUID(),
            performedAt: Date(),
            reason: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        let model = dto.toModel()
        #expect(model.action == .claimed) // Falls back to default
    }

    @Test("ClaimEventDTO handles invalid parentType gracefully")
    func testInvalidParentType() {
        let dto = ClaimEventDTO(
            id: UUID(),
            parentType: "invalid_type",
            parentId: UUID(),
            action: "claimed",
            userId: UUID(),
            performedAt: Date(),
            reason: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        let model = dto.toModel()
        #expect(model.parentType == .task) // Falls back to default
    }

    @Test("ClaimEventDTO init(from:) creates DTO from model correctly")
    func testInitFromModel() {
        let id = UUID()
        let parentId = UUID()
        let userId = UUID()
        let performedAt = Date()
        let createdAt = Date().addingTimeInterval(-3600)
        let updatedAt = Date()

        let model = ClaimEvent(
            id: id,
            parentType: .activity,
            parentId: parentId,
            action: .released,
            userId: userId,
            performedAt: performedAt,
            reason: "No longer available",
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let dto = ClaimEventDTO(from: model)

        #expect(dto.id == id)
        #expect(dto.parentType == "activity")
        #expect(dto.parentId == parentId)
        #expect(dto.action == "released")
        #expect(dto.userId == userId)
        #expect(dto.reason == "No longer available")
        #expect(dto.createdAt == createdAt)
        #expect(dto.updatedAt == updatedAt)
    }
}
