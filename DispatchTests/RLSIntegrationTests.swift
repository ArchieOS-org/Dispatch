//
//  RLSIntegrationTests.swift
//  DispatchTests
//
//  Row-Level Security (RLS) regression tests for Supabase policies.
//  Tests verify that RLS policies correctly scope data access to authorized users.
//
//  NOTE: These tests require a live Supabase instance with test users configured.
//  They are disabled by default - enable with DISPATCH_RLS_TESTS=1 environment variable.
//
//  Test User Setup:
//  Configure test credentials via environment variables:
//  - TEST_USER1_EMAIL / TEST_USER1_PASSWORD
//  - TEST_USER2_EMAIL / TEST_USER2_PASSWORD
//
//  The tests use service role to set up data, then authenticate as users to verify RLS.
//  Tests skip gracefully if credentials are not configured.
//

// swiftlint:disable force_unwrapping
// swiftlint:disable function_body_length

import Foundation
import Supabase
import Testing
@testable import DispatchApp

// MARK: - RLSTestConfig

/// Configuration for RLS integration tests
private enum RLSTestConfig {
  /// Deterministic UUIDs for test data (pattern: 00000000-0000-0000-XXXX-YYYYYYYYYYYY)
  /// XXXX = entity type, YYYYYYYYYYYY = sequential index
  enum TestUUIDs {
    // Listings (type = 0001)
    static let listingA = UUID(uuidString: "00000000-0000-0000-0001-000000000001")!
    static let listingB = UUID(uuidString: "00000000-0000-0000-0001-000000000002")!

    // Notes (type = 0005)
    static let noteOnListingA = UUID(uuidString: "00000000-0000-0000-0005-000000000001")!
    static let noteOnListingB = UUID(uuidString: "00000000-0000-0000-0005-000000000002")!
    static let deletedNote = UUID(uuidString: "00000000-0000-0000-0005-000000000003")!

    // Listing Types (type = 0006)
    static let listingTypeA = UUID(uuidString: "00000000-0000-0000-0006-000000000001")!
    static let listingTypeB = UUID(uuidString: "00000000-0000-0000-0006-000000000002")!

    // Properties (type = 0007)
    static let propertyA = UUID(uuidString: "00000000-0000-0000-0007-000000000001")!
    static let propertyB = UUID(uuidString: "00000000-0000-0000-0007-000000000002")!

    // Tasks (type = 0002)
    static let taskA = UUID(uuidString: "00000000-0000-0000-0002-000000000001")!
    static let taskB = UUID(uuidString: "00000000-0000-0000-0002-000000000002")!

    /// Task Assignees (type = 0008)
    static let taskAssigneeA = UUID(uuidString: "00000000-0000-0000-0008-000000000001")!
  }

  /// Test data prefix for cleanup
  static let testDataPrefix = "RLS_TEST_"

  /// Test user A credentials (from environment variables)
  static var userAEmail: String? {
    ProcessInfo.processInfo.environment["TEST_USER1_EMAIL"]
  }

  static var userAPassword: String? {
    ProcessInfo.processInfo.environment["TEST_USER1_PASSWORD"]
  }

  /// Test user B credentials (from environment variables)
  static var userBEmail: String? {
    ProcessInfo.processInfo.environment["TEST_USER2_EMAIL"]
  }

  static var userBPassword: String? {
    ProcessInfo.processInfo.environment["TEST_USER2_PASSWORD"]
  }

  /// Check if all required credentials are configured
  static var credentialsConfigured: Bool {
    userAEmail != nil && userAPassword != nil &&
      userBEmail != nil && userBPassword != nil
  }

}

/// Check if RLS tests are enabled via environment variable and credentials are configured
private var rlsTestsEnabled: Bool {
  ProcessInfo.processInfo.environment["DISPATCH_RLS_TESTS"] == "1" &&
    RLSTestConfig.credentialsConfigured
}

// MARK: - RLSTestError

/// Errors specific to RLS test setup
private enum RLSTestError: Error, LocalizedError {
  case credentialsNotConfigured(String)

  var errorDescription: String? {
    switch self {
    case .credentialsNotConfigured(let envVars):
      "Test credentials not configured. Set environment variables: \(envVars)"
    }
  }
}

// MARK: - RLSTestClient

/// Helper to create authenticated Supabase clients for RLS testing
@MainActor
final class RLSTestClient {

  // MARK: Internal

  /// Get the shared service-role client (bypasses RLS)
  static var serviceClient: SupabaseClient {
    supabase
  }

  /// Get an authenticated client for test user A
  /// - Throws: If credentials are not configured or authentication fails
  static func clientAsUserA() async throws -> (client: SupabaseClient, userId: UUID) {
    guard
      let email = RLSTestConfig.userAEmail,
      let password = RLSTestConfig.userAPassword
    else {
      throw RLSTestError.credentialsNotConfigured("TEST_USER1_EMAIL/TEST_USER1_PASSWORD")
    }
    return try await authenticatedClient(email: email, password: password)
  }

  /// Get an authenticated client for test user B
  /// - Throws: If credentials are not configured or authentication fails
  static func clientAsUserB() async throws -> (client: SupabaseClient, userId: UUID) {
    guard
      let email = RLSTestConfig.userBEmail,
      let password = RLSTestConfig.userBPassword
    else {
      throw RLSTestError.credentialsNotConfigured("TEST_USER2_EMAIL/TEST_USER2_PASSWORD")
    }
    return try await authenticatedClient(email: email, password: password)
  }

  /// Clean up test data using deterministic UUIDs
  static func cleanupTestData() async throws {
    // Delete in reverse FK order
    // Notes
    try? await supabase
      .from("notes")
      .delete()
      .like("id", pattern: "00000000-0000-0000-0005-%")
      .execute()

    // Task assignees
    try? await supabase
      .from("task_assignees")
      .delete()
      .like("id", pattern: "00000000-0000-0000-0008-%")
      .execute()

    // Tasks
    try? await supabase
      .from("tasks")
      .delete()
      .like("id", pattern: "00000000-0000-0000-0002-%")
      .execute()

    // Listings
    try? await supabase
      .from("listings")
      .delete()
      .like("id", pattern: "00000000-0000-0000-0001-%")
      .execute()

    // Listing types
    try? await supabase
      .from("listing_types")
      .delete()
      .like("id", pattern: "00000000-0000-0000-0006-%")
      .execute()

    // Properties
    try? await supabase
      .from("properties")
      .delete()
      .like("id", pattern: "00000000-0000-0000-0007-%")
      .execute()
  }

  // MARK: Private

  private static var cachedClients: [String: (SupabaseClient, UUID)] = [:]

  private static func authenticatedClient(
    email: String,
    password: String
  ) async throws -> (client: SupabaseClient, userId: UUID) {
    // Check cache first
    if let cached = cachedClients[email] {
      return cached
    }

    // Create a new client with same config
    let client = SupabaseClient(
      supabaseURL: URL(string: Secrets.supabaseURL)!,
      supabaseKey: Secrets.supabaseAnonKey
    )

    // Sign in
    let session = try await client.auth.signIn(email: email, password: password)
    let result = (client, session.user.id)

    // Cache for reuse
    cachedClients[email] = result

    return result
  }
}

// MARK: - NotesRLSTests

/// Tests for notes table RLS policies
/// Notes inherit access from their parent entity (listing, task, or activity)
struct NotesRLSTests {

  @Test("User can read notes on listings they own", .enabled(if: rlsTestsEnabled))
  func testCanReadOwnListingNotes() async throws {
    // Setup: Create listing owned by User A, then create note on that listing
    let (clientA, userIdA) = try await RLSTestClient.clientAsUserA()

    // Create listing via service client (to bypass RLS on insert)
    let listingId = RLSTestConfig.TestUUIDs.listingA
    try await RLSTestClient.serviceClient
      .from("listings")
      .upsert([
        "id": listingId.uuidString,
        "address": "RLS_TEST_123 Test St",
        "listing_type": "sale",
        "status": "active",
        "owned_by": userIdA.uuidString,
        "created_via": "dispatch"
      ])
      .execute()

    // Create note on that listing via service client
    let noteId = RLSTestConfig.TestUUIDs.noteOnListingA
    try await RLSTestClient.serviceClient
      .from("notes")
      .upsert([
        "id": noteId.uuidString,
        "content": "RLS_TEST_Note for User A's listing",
        "created_by": userIdA.uuidString,
        "parent_type": "listing",
        "parent_id": listingId.uuidString
      ])
      .execute()

    // Action: Query notes as User A
    let notes: [NoteDTO] = try await clientA
      .from("notes")
      .select()
      .eq("id", value: noteId.uuidString)
      .execute()
      .value

    // Assert: User A should see their note
    #expect(notes.count == 1, "User A should be able to read notes on their own listing")
    #expect(notes.first?.id == noteId, "Note ID should match")
  }

  @Test("User cannot read notes on listings owned by others", .enabled(if: rlsTestsEnabled))
  func testCannotReadOthersListingNotes() async throws {
    // Setup: User A owns listing, User B tries to read notes
    let (_, userIdA) = try await RLSTestClient.clientAsUserA()
    let (clientB, _) = try await RLSTestClient.clientAsUserB()

    // Create listing owned by User A
    let listingId = RLSTestConfig.TestUUIDs.listingA
    try await RLSTestClient.serviceClient
      .from("listings")
      .upsert([
        "id": listingId.uuidString,
        "address": "RLS_TEST_456 Private Ave",
        "listing_type": "sale",
        "status": "active",
        "owned_by": userIdA.uuidString,
        "created_via": "dispatch"
      ])
      .execute()

    // Create note on User A's listing
    let noteId = RLSTestConfig.TestUUIDs.noteOnListingA
    try await RLSTestClient.serviceClient
      .from("notes")
      .upsert([
        "id": noteId.uuidString,
        "content": "RLS_TEST_Private note on User A's listing",
        "created_by": userIdA.uuidString,
        "parent_type": "listing",
        "parent_id": listingId.uuidString
      ])
      .execute()

    // Action: Query notes as User B
    let notes: [NoteDTO] = try await clientB
      .from("notes")
      .select()
      .eq("id", value: noteId.uuidString)
      .execute()
      .value

    // Assert: User B should NOT see notes on User A's listing
    #expect(notes.isEmpty, "User B should NOT be able to read notes on User A's listing")
  }

  @Test("Deleted notes are not visible to owner", .enabled(if: rlsTestsEnabled))
  func testDeletedNotesNotVisible() async throws {
    // Setup: Create listing and soft-deleted note
    let (clientA, userIdA) = try await RLSTestClient.clientAsUserA()

    let listingId = RLSTestConfig.TestUUIDs.listingA
    try await RLSTestClient.serviceClient
      .from("listings")
      .upsert([
        "id": listingId.uuidString,
        "address": "RLS_TEST_789 Deleted Lane",
        "listing_type": "sale",
        "status": "active",
        "owned_by": userIdA.uuidString,
        "created_via": "dispatch"
      ])
      .execute()

    // Create soft-deleted note (deleted more than 10 minutes ago)
    let noteId = RLSTestConfig.TestUUIDs.deletedNote
    let oldDeletedAt = Date().addingTimeInterval(-3600) // 1 hour ago
    try await RLSTestClient.serviceClient
      .from("notes")
      .upsert([
        "id": noteId.uuidString,
        "content": "RLS_TEST_This note was deleted",
        "created_by": userIdA.uuidString,
        "parent_type": "listing",
        "parent_id": listingId.uuidString,
        "deleted_at": ISO8601DateFormatter().string(from: oldDeletedAt),
        "deleted_by": userIdA.uuidString
      ])
      .execute()

    // Action: Query notes as User A
    let notes: [NoteDTO] = try await clientA
      .from("notes")
      .select()
      .eq("id", value: noteId.uuidString)
      .execute()
      .value

    // Assert: Deleted note should not be visible (RLS filters deleted_at)
    #expect(notes.isEmpty, "Soft-deleted notes should NOT be visible via RLS")
  }
}

// MARK: - ListingTypesRLSTests

/// Tests for listing_types table RLS policies
/// Users can only see listing types they own (or admins can see all)
struct ListingTypesRLSTests {

  @Test("User can read their own listing types", .enabled(if: rlsTestsEnabled))
  func testCanReadOwnListingTypes() async throws {
    let (clientA, userIdA) = try await RLSTestClient.clientAsUserA()

    // Create listing type owned by User A
    let listingTypeId = RLSTestConfig.TestUUIDs.listingTypeA
    try await RLSTestClient.serviceClient
      .from("listing_types")
      .upsert([
        "id": listingTypeId.uuidString,
        "name": "RLS_TEST_User A's Custom Type",
        "owned_by": userIdA.uuidString
      ])
      .execute()

    // Query as User A
    struct ListingTypeRow: Decodable {
      let id: UUID
      let name: String
    }
    let types: [ListingTypeRow] = try await clientA
      .from("listing_types")
      .select()
      .eq("id", value: listingTypeId.uuidString)
      .execute()
      .value

    #expect(types.count == 1, "User A should see their own listing type")
    #expect(types.first?.name == "RLS_TEST_User A's Custom Type")
  }

  @Test("User cannot read other users' listing types", .enabled(if: rlsTestsEnabled))
  func testCannotReadOthersListingTypes() async throws {
    let (_, userIdA) = try await RLSTestClient.clientAsUserA()
    let (clientB, _) = try await RLSTestClient.clientAsUserB()

    // Create listing type owned by User A
    let listingTypeId = RLSTestConfig.TestUUIDs.listingTypeA
    try await RLSTestClient.serviceClient
      .from("listing_types")
      .upsert([
        "id": listingTypeId.uuidString,
        "name": "RLS_TEST_User A's Private Type",
        "owned_by": userIdA.uuidString
      ])
      .execute()

    // Query as User B
    struct ListingTypeRow: Decodable {
      let id: UUID
    }
    let types: [ListingTypeRow] = try await clientB
      .from("listing_types")
      .select()
      .eq("id", value: listingTypeId.uuidString)
      .execute()
      .value

    #expect(types.isEmpty, "User B should NOT see User A's listing types")
  }
}

// MARK: - PropertiesRLSTests

/// Tests for properties table RLS policies
/// Properties are owned by users and scoped accordingly
struct PropertiesRLSTests {

  @Test("User can read their own properties", .enabled(if: rlsTestsEnabled))
  func testCanReadOwnProperties() async throws {
    let (clientA, userIdA) = try await RLSTestClient.clientAsUserA()

    // Create property owned by User A
    let propertyId = RLSTestConfig.TestUUIDs.propertyA
    try await RLSTestClient.serviceClient
      .from("properties")
      .upsert([
        "id": propertyId.uuidString,
        "address": "RLS_TEST_100 Property Lane",
        "owned_by": userIdA.uuidString
      ])
      .execute()

    // Query as User A
    struct PropertyRow: Decodable {
      let id: UUID
      let address: String
    }
    let properties: [PropertyRow] = try await clientA
      .from("properties")
      .select()
      .eq("id", value: propertyId.uuidString)
      .execute()
      .value

    #expect(properties.count == 1, "User A should see their own property")
  }

  @Test("User cannot update other users' properties", .enabled(if: rlsTestsEnabled))
  func testCannotUpdateOthersProperties() async throws {
    let (_, userIdA) = try await RLSTestClient.clientAsUserA()
    let (clientB, _) = try await RLSTestClient.clientAsUserB()

    // Create property owned by User A
    let propertyId = RLSTestConfig.TestUUIDs.propertyA
    try await RLSTestClient.serviceClient
      .from("properties")
      .upsert([
        "id": propertyId.uuidString,
        "address": "RLS_TEST_200 Owned by A",
        "owned_by": userIdA.uuidString
      ])
      .execute()

    // Attempt to update as User B
    var updateFailed = false
    do {
      try await clientB
        .from("properties")
        .update(["address": "RLS_TEST_Hacked by B"])
        .eq("id", value: propertyId.uuidString)
        .execute()
    } catch {
      // Expected: RLS should block this update
      updateFailed = true
    }

    // Verify the address wasn't changed
    struct PropertyRow: Decodable {
      let address: String
    }
    let properties: [PropertyRow] = try await RLSTestClient.serviceClient
      .from("properties")
      .select()
      .eq("id", value: propertyId.uuidString)
      .execute()
      .value

    // RLS may silently filter (no rows updated) rather than throw an error
    let addressUnchanged = properties.first?.address == "RLS_TEST_200 Owned by A"
    #expect(
      updateFailed || addressUnchanged,
      "User B should NOT be able to update User A's property"
    )
  }
}

// MARK: - TaskAssigneesRLSTests

/// Tests for task_assignees table RLS policies
/// Users can see assignees if: they are the assignee, they declared the task, or they own the listing
struct TaskAssigneesRLSTests {

  @Test("User can see task assignees for tasks they declared", .enabled(if: rlsTestsEnabled))
  func testCanSeeAssigneesForOwnTasks() async throws {
    let (clientA, userIdA) = try await RLSTestClient.clientAsUserA()
    let (_, userIdB) = try await RLSTestClient.clientAsUserB()

    // Create task declared by User A
    let taskId = RLSTestConfig.TestUUIDs.taskA
    try await RLSTestClient.serviceClient
      .from("tasks")
      .upsert([
        "id": taskId.uuidString,
        "title": "RLS_TEST_Task by User A",
        "status": "open",
        "declared_by": userIdA.uuidString,
        "created_via": "dispatch"
      ])
      .execute()

    // Assign User B to the task (via service client)
    let assigneeId = RLSTestConfig.TestUUIDs.taskAssigneeA
    try await RLSTestClient.serviceClient
      .from("task_assignees")
      .upsert([
        "id": assigneeId.uuidString,
        "task_id": taskId.uuidString,
        "user_id": userIdB.uuidString
      ])
      .execute()

    // Query assignees as User A (task declarer)
    struct AssigneeRow: Decodable {
      let id: UUID
      // swiftlint:disable:next identifier_name
      let user_id: UUID
    }
    let assignees: [AssigneeRow] = try await clientA
      .from("task_assignees")
      .select()
      .eq("task_id", value: taskId.uuidString)
      .execute()
      .value

    #expect(assignees.count == 1, "Task declarer should see assignees on their task")
    #expect(assignees.first?.user_id == userIdB, "Assignee should be User B")
  }

  @Test("Assignee can see their own assignment", .enabled(if: rlsTestsEnabled))
  func testAssigneeCanSeeOwnAssignment() async throws {
    let (_, userIdA) = try await RLSTestClient.clientAsUserA()
    let (clientB, userIdB) = try await RLSTestClient.clientAsUserB()

    // Create task declared by User A
    let taskId = RLSTestConfig.TestUUIDs.taskA
    try await RLSTestClient.serviceClient
      .from("tasks")
      .upsert([
        "id": taskId.uuidString,
        "title": "RLS_TEST_Task with assignment",
        "status": "open",
        "declared_by": userIdA.uuidString,
        "created_via": "dispatch"
      ])
      .execute()

    // Assign User B
    let assigneeId = RLSTestConfig.TestUUIDs.taskAssigneeA
    try await RLSTestClient.serviceClient
      .from("task_assignees")
      .upsert([
        "id": assigneeId.uuidString,
        "task_id": taskId.uuidString,
        "user_id": userIdB.uuidString
      ])
      .execute()

    // Query as User B (the assignee)
    struct AssigneeRow: Decodable {
      let id: UUID
    }
    let assignees: [AssigneeRow] = try await clientB
      .from("task_assignees")
      .select()
      .eq("id", value: assigneeId.uuidString)
      .execute()
      .value

    #expect(assignees.count == 1, "Assignee should see their own assignment")
  }
}

// MARK: - UnauthenticatedAccessTests

/// Tests verifying that unauthenticated/anon access is properly restricted
struct UnauthenticatedAccessTests {

  @Test("Anon cannot insert into notes table", .enabled(if: rlsTestsEnabled))
  func testAnonCannotInsertNotes() async throws {
    // Create anon client (not signed in)
    let anonClient = SupabaseClient(
      supabaseURL: URL(string: Secrets.supabaseURL)!,
      supabaseKey: Secrets.supabaseAnonKey
    )

    // Attempt to insert a note as anon
    var insertFailed = false
    do {
      try await anonClient
        .from("notes")
        .insert([
          "id": UUID().uuidString,
          "content": "RLS_TEST_Anon trying to insert",
          "created_by": UUID().uuidString,
          "parent_type": "listing",
          "parent_id": UUID().uuidString
        ])
        .execute()
    } catch {
      // Expected: RLS should block anon inserts
      insertFailed = true
    }

    #expect(insertFailed, "Anon users should NOT be able to insert notes")
  }

  @Test("Anon cannot read listing_types", .enabled(if: rlsTestsEnabled))
  func testAnonCannotReadListingTypes() async throws {
    let anonClient = SupabaseClient(
      supabaseURL: URL(string: Secrets.supabaseURL)!,
      supabaseKey: Secrets.supabaseAnonKey
    )

    // Create a listing type via service client
    let (_, userIdA) = try await RLSTestClient.clientAsUserA()
    let listingTypeId = RLSTestConfig.TestUUIDs.listingTypeA
    try await RLSTestClient.serviceClient
      .from("listing_types")
      .upsert([
        "id": listingTypeId.uuidString,
        "name": "RLS_TEST_Should not be visible to anon",
        "owned_by": userIdA.uuidString
      ])
      .execute()

    // Query as anon
    struct ListingTypeRow: Decodable {
      let id: UUID
    }
    let types: [ListingTypeRow] = try await anonClient
      .from("listing_types")
      .select()
      .eq("id", value: listingTypeId.uuidString)
      .execute()
      .value

    #expect(types.isEmpty, "Anon users should NOT be able to read listing_types")
  }
}

// MARK: - RLSCleanupTests

/// Cleanup test to run after all RLS tests
struct RLSCleanupTests {

  @Test("Cleanup RLS test data", .enabled(if: rlsTestsEnabled))
  func testCleanupTestData() async throws {
    try await RLSTestClient.cleanupTestData()
    // No assertion needed - cleanup should succeed silently
  }
}

// swiftlint:enable force_unwrapping
// swiftlint:enable function_body_length
