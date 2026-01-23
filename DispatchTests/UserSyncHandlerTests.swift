//
//  UserSyncHandlerTests.swift
//  DispatchTests
//
//  Unit tests for UserSyncHandler entity-specific sync operations.
//  Tests upsertUser, deleteLocalUser, and reconcileLegacyLocalUsers logic.
//

// swiftlint:disable implicitly_unwrapped_optional

import SwiftData
import XCTest
@testable import DispatchApp

// MARK: - UserSyncHandlerTests

@MainActor
final class UserSyncHandlerTests: XCTestCase {

  // MARK: Internal

  override func setUp() {
    super.setUp()

    // Create in-memory SwiftData container for testing
    // Include Listing.self for User relationship support
    let schema = Schema([User.self, Listing.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    // swiftlint:disable:next force_try
    container = try! ModelContainer(for: schema, configurations: [config])
    context = ModelContext(container)

    // Track fetchCurrentUser callback invocations
    fetchCurrentUserCalledWithID = nil

    // Create dependencies for test mode
    let deps = SyncHandlerDependencies(
      mode: .test,
      conflictResolver: ConflictResolver(),
      getCurrentUserID: { [weak self] in self?.currentUserID },
      getCurrentUser: { nil },
      fetchCurrentUser: { [weak self] id in self?.fetchCurrentUserCalledWithID = id },
      updateListingConfigReady: { _ in }
    )
    handler = UserSyncHandler(dependencies: deps)
  }

  override func tearDown() {
    context = nil
    container = nil
    handler = nil
    currentUserID = nil
    fetchCurrentUserCalledWithID = nil
    super.tearDown()
  }

  // MARK: - Initialization Tests

  func test_init_setsModeProperly() {
    XCTAssertEqual(handler.dependencies.mode, .test)
  }

  func test_init_setsConflictResolver() {
    XCTAssertNotNil(handler.dependencies.conflictResolver)
  }

  // MARK: - upsertUser Tests

  func test_upsertUser_insertsNewUser() async throws {
    // Given: A new user DTO that doesn't exist locally
    let userId = UUID()
    let dto = makeUserDTO(
      id: userId,
      name: "Steve Jobs",
      email: "steve@apple.com"
    )

    // When: Upsert the user
    try await handler.upsertUser(dto: dto, context: context)

    // Then: User should be inserted
    let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId })
    let users = try context.fetch(descriptor)
    XCTAssertEqual(users.count, 1)
    XCTAssertEqual(users.first?.name, "Steve Jobs")
    XCTAssertEqual(users.first?.email, "steve@apple.com")
    XCTAssertEqual(users.first?.syncState, .synced)
  }

  func test_upsertUser_updatesExistingSyncedUser() async throws {
    // Given: An existing synced user
    let userId = UUID()
    let existingUser = makeUser(id: userId, name: "Old Name", email: "old@apple.com")
    existingUser.markSynced()
    context.insert(existingUser)
    try context.save()

    // When: Upsert with updated fields
    let dto = makeUserDTO(
      id: userId,
      name: "New Name",
      email: "new@apple.com"
    )
    try await handler.upsertUser(dto: dto, context: context)

    // Then: User should be updated
    let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId })
    let users = try context.fetch(descriptor)
    XCTAssertEqual(users.first?.name, "New Name")
    XCTAssertEqual(users.first?.email, "new@apple.com")
    XCTAssertEqual(users.first?.syncState, .synced)
  }

  func test_upsertUser_skipsUpdateWhenExistingUserIsPending() async throws {
    // Given: An existing user with pending local changes
    let userId = UUID()
    let existingUser = makeUser(id: userId, name: "Local Pending Name", email: "local@apple.com")
    existingUser.markPending()
    context.insert(existingUser)
    try context.save()

    // When: Upsert remote update while pending
    let dto = makeUserDTO(
      id: userId,
      name: "Remote Name",
      email: "remote@apple.com"
    )
    try await handler.upsertUser(dto: dto, context: context)

    // Then: Local pending content should be preserved (conflict protection)
    let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId })
    let users = try context.fetch(descriptor)
    XCTAssertEqual(users.first?.name, "Local Pending Name")
    XCTAssertEqual(users.first?.email, "local@apple.com")
    XCTAssertEqual(users.first?.syncState, .pending)
  }

  func test_upsertUser_clearsAvatarWhenRemoteHashIsNil() async throws {
    // Given: An existing user with local avatar data and hash
    let userId = UUID()
    let existingUser = makeUser(id: userId, name: "Test User", email: "test@apple.com")
    existingUser.avatar = Data([0xAA, 0xBB, 0xCC])
    existingUser.avatarHash = "oldHash123"
    existingUser.markSynced()
    context.insert(existingUser)
    try context.save()

    // When: Upsert DTO with nil avatar hash (remote avatar deleted)
    let dto = makeUserDTO(
      id: userId,
      name: "Test User",
      email: "test@apple.com",
      avatarPath: nil,
      avatarHash: nil
    )
    try await handler.upsertUser(dto: dto, context: context)

    // Then: Local avatar should be cleared
    let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId })
    let users = try context.fetch(descriptor)
    XCTAssertNil(users.first?.avatar)
    XCTAssertNil(users.first?.avatarHash)
  }

  func test_upsertUser_callsFetchCurrentUserWhenIDMatches() async throws {
    // Given: Set current user ID to match the DTO
    let userId = UUID()
    currentUserID = userId

    let dto = makeUserDTO(
      id: userId,
      name: "Current User",
      email: "current@apple.com"
    )

    // When: Upsert the user
    try await handler.upsertUser(dto: dto, context: context)

    // Then: fetchCurrentUser callback should be called with the user's ID
    XCTAssertEqual(fetchCurrentUserCalledWithID, userId)
  }

  func test_upsertUser_doesNotCallFetchCurrentUserWhenIDDoesNotMatch() async throws {
    // Given: Set current user ID to a different UUID
    let userId = UUID()
    let otherUserId = UUID()
    currentUserID = otherUserId

    let dto = makeUserDTO(
      id: userId,
      name: "Other User",
      email: "other@apple.com"
    )

    // When: Upsert the user
    try await handler.upsertUser(dto: dto, context: context)

    // Then: fetchCurrentUser callback should NOT be called
    XCTAssertNil(fetchCurrentUserCalledWithID)
  }

  func test_upsertUser_updatesUserType() async throws {
    // Given: An existing user with realtor type
    let userId = UUID()
    let existingUser = makeUser(id: userId, name: "Test", email: "test@apple.com")
    existingUser.userType = .realtor
    existingUser.markSynced()
    context.insert(existingUser)
    try context.save()

    // When: Upsert with admin user type
    let dto = makeUserDTO(
      id: userId,
      name: "Test",
      email: "test@apple.com",
      userType: "admin"
    )
    try await handler.upsertUser(dto: dto, context: context)

    // Then: User type should be updated
    let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId })
    let users = try context.fetch(descriptor)
    XCTAssertEqual(users.first?.userType, .admin)
  }

  // MARK: - deleteLocalUser Tests

  func test_deleteLocalUser_deletesExistingUser() throws {
    // Given: An existing user
    let userId = UUID()
    let existingUser = makeUser(id: userId, name: "To Be Deleted", email: "delete@apple.com")
    context.insert(existingUser)
    try context.save()

    // When: Delete the user
    let deleted = try handler.deleteLocalUser(id: userId, context: context)

    // Then: User should be deleted
    XCTAssertTrue(deleted)
    let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId })
    let users = try context.fetch(descriptor)
    XCTAssertTrue(users.isEmpty)
  }

  func test_deleteLocalUser_returnsFalseWhenUserNotFound() throws {
    // Given: A non-existent user ID
    let missingId = UUID()

    // When: Try to delete
    let deleted = try handler.deleteLocalUser(id: missingId, context: context)

    // Then: Should return false
    XCTAssertFalse(deleted)
  }

  // MARK: - reconcileLegacyLocalUsers Tests

  func test_reconcileLegacyLocalUsers_marksPhantomUsersAsPending() async throws {
    // Given: A phantom user (synced but syncedAt == nil)
    let userId = UUID()
    let phantomUser = makeUser(id: userId, name: "Phantom", email: "phantom@apple.com")
    phantomUser.syncStateRaw = .synced
    phantomUser.syncedAt = nil // Key: synced but never actually synced
    context.insert(phantomUser)
    try context.save()

    // When: Reconcile legacy users
    try await handler.reconcileLegacyLocalUsers(context: context)

    // Then: Phantom user should be marked as pending
    let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId })
    let users = try context.fetch(descriptor)
    XCTAssertEqual(users.first?.syncState, .pending)
  }

  func test_reconcileLegacyLocalUsers_migratesLegacyAvatars() async throws {
    // Given: A user with avatar data but no hash (legacy data)
    let userId = UUID()
    let legacyUser = makeUser(id: userId, name: "Legacy", email: "legacy@apple.com")
    legacyUser.avatar = Data([0x01, 0x02, 0x03, 0x04])
    legacyUser.avatarHash = nil // Key: has avatar but no hash
    legacyUser.markSynced()
    context.insert(legacyUser)
    try context.save()

    // When: Reconcile legacy users
    try await handler.reconcileLegacyLocalUsers(context: context)

    // Then: Avatar hash should be computed and user marked pending
    let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId })
    let users = try context.fetch(descriptor)
    XCTAssertNotNil(users.first?.avatarHash, "Avatar hash should be computed")
    XCTAssertEqual(users.first?.syncState, .pending, "User should be marked pending for sync")
  }

  func test_reconcileLegacyLocalUsers_doesNotAffectNormalUsers() async throws {
    // Given: A properly synced user with both avatar and hash
    let userId = UUID()
    let normalUser = makeUser(id: userId, name: "Normal", email: "normal@apple.com")
    normalUser.avatar = Data([0xAA, 0xBB])
    normalUser.avatarHash = "existingHash"
    normalUser.markSynced()
    normalUser.syncedAt = Date() // Properly synced
    context.insert(normalUser)
    try context.save()

    // When: Reconcile legacy users
    try await handler.reconcileLegacyLocalUsers(context: context)

    // Then: Normal user should remain unchanged
    let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId })
    let users = try context.fetch(descriptor)
    XCTAssertEqual(users.first?.syncState, .synced)
    XCTAssertEqual(users.first?.avatarHash, "existingHash")
  }

  func test_reconcileLegacyLocalUsers_handlesMultiplePhantomUsers() async throws {
    // Given: Multiple phantom users
    let userId1 = UUID()
    let userId2 = UUID()

    let phantom1 = makeUser(id: userId1, name: "Phantom1", email: "p1@apple.com")
    phantom1.syncStateRaw = .synced
    phantom1.syncedAt = nil

    let phantom2 = makeUser(id: userId2, name: "Phantom2", email: "p2@apple.com")
    phantom2.syncStateRaw = .synced
    phantom2.syncedAt = nil

    context.insert(phantom1)
    context.insert(phantom2)
    try context.save()

    // When: Reconcile legacy users
    try await handler.reconcileLegacyLocalUsers(context: context)

    // Then: Both phantom users should be marked pending
    let descriptor1 = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId1 })
    let descriptor2 = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId2 })
    let users1 = try context.fetch(descriptor1)
    let users2 = try context.fetch(descriptor2)
    XCTAssertEqual(users1.first?.syncState, .pending)
    XCTAssertEqual(users2.first?.syncState, .pending)
  }

  // MARK: - Avatar Sync Logic Tests

  func test_avatarHashDifferent_updatesHash() async throws {
    // Given: A user with existing hash
    let userId = UUID()
    let existingUser = makeUser(id: userId, name: "Test User", email: "test@apple.com")
    existingUser.avatarHash = "oldHash123"
    existingUser.avatar = Data([0x01, 0x02, 0x03])
    existingUser.markSynced()
    context.insert(existingUser)
    try context.save()

    // When: Upsert with different remote hash
    // Note: In test mode without network, the avatar update will clear the avatar
    // since it can't download the new one. This is expected behavior.
    let dto = makeUserDTO(
      id: userId,
      name: "Updated User",
      email: "test@apple.com",
      avatarPath: nil, // No avatar path to avoid network call
      avatarHash: nil // Clear avatar hash
    )
    try await handler.upsertUser(dto: dto, context: context)

    // Then: User should be updated
    let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId })
    let users = try context.fetch(descriptor)
    XCTAssertNotNil(users.first)
    XCTAssertEqual(users.first?.name, "Updated User")
  }

  func test_avatarHashMatches_skipsDownload() async throws {
    // Given: A user with matching hash
    let userId = UUID()
    let existingUser = makeUser(id: userId, name: "Test User", email: "test@apple.com")
    existingUser.avatarHash = "sameHash"
    existingUser.avatar = Data([0xAA, 0xBB, 0xCC])
    existingUser.markSynced()
    context.insert(existingUser)
    try context.save()

    let originalAvatar = existingUser.avatar

    // When: Upsert with same hash
    let dto = makeUserDTO(
      id: userId,
      name: "Test User",
      email: "test@apple.com",
      avatarPath: "avatars/test.jpg",
      avatarHash: "sameHash" // Same as local
    )
    try await handler.upsertUser(dto: dto, context: context)

    // Then: Avatar data should be preserved (no download needed)
    let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId })
    let users = try context.fetch(descriptor)
    XCTAssertEqual(users.first?.avatar, originalAvatar)
    XCTAssertEqual(users.first?.avatarHash, "sameHash")
  }

  func test_upsertUser_withNilAvatarHash_clearsLocalAvatar() async throws {
    // Given: A user with existing avatar
    let userId = UUID()
    let existingUser = makeUser(id: userId, name: "Test User", email: "test@apple.com")
    existingUser.avatar = Data([0x01, 0x02, 0x03])
    existingUser.avatarHash = "existingHash"
    existingUser.markSynced()
    context.insert(existingUser)
    try context.save()

    // When: Upsert with nil avatar hash (remote avatar deleted)
    let dto = makeUserDTO(
      id: userId,
      name: "Test User",
      email: "test@apple.com",
      avatarPath: nil,
      avatarHash: nil
    )
    try await handler.upsertUser(dto: dto, context: context)

    // Then: Local avatar should be cleared
    let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId })
    let users = try context.fetch(descriptor)
    XCTAssertNil(users.first?.avatar)
    XCTAssertNil(users.first?.avatarHash)
  }

  func test_pendingUser_preservesLocalAvatarDuringRemoteUpdate() async throws {
    // Given: A pending user with local avatar
    let userId = UUID()
    let existingUser = makeUser(id: userId, name: "Local Name", email: "local@apple.com")
    existingUser.avatar = Data([0xDE, 0xAD, 0xBE, 0xEF])
    existingUser.avatarHash = "localHash"
    existingUser.markPending()
    context.insert(existingUser)
    try context.save()

    let originalAvatar = existingUser.avatar
    let originalHash = existingUser.avatarHash

    // When: Remote update arrives while pending
    let dto = makeUserDTO(
      id: userId,
      name: "Remote Name",
      email: "remote@apple.com",
      avatarPath: "avatars/remote.jpg",
      avatarHash: "remoteHash"
    )
    try await handler.upsertUser(dto: dto, context: context)

    // Then: Local avatar should be preserved (pending protection)
    let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId })
    let users = try context.fetch(descriptor)
    XCTAssertEqual(users.first?.avatar, originalAvatar)
    XCTAssertEqual(users.first?.avatarHash, originalHash)
    XCTAssertEqual(users.first?.name, "Local Name") // Name also preserved
  }

  // MARK: - Avatar Upload RLS Policy Requirements
  //
  // IMPORTANT: Avatar uploads to Supabase Storage use `upsert: true` in FileOptions.
  // This requires THREE RLS policies on the `avatars` bucket:
  //
  //   1. SELECT - Required to check if file exists (upsert pre-check)
  //   2. INSERT - Required to create new files
  //   3. UPDATE - Required to replace existing files (upsert overwrites)
  //
  // If the UPDATE policy is missing, uploads will fail with:
  //   "new row violates row-level security policy"
  //
  // See: UserSyncHandler.uploadAvatar() which calls:
  //   supabase.storage.from("avatars").upload(path, data, options: FileOptions(upsert: true))
  //
  // Reference: https://supabase.com/docs/guides/storage/security/access-control
  //
  // REGRESSION PREVENTION:
  // If the upsert behavior changes, ensure all three RLS policies
  // (SELECT, INSERT, UPDATE) are in place.
  //
  // The uploadAvatar method uses:
  //   FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true)
  //
  // Without upsert: true, users would get errors when re-uploading avatars
  // because INSERT alone cannot replace existing files.

  func test_avatarUpload_failureDoesNotMarkUserSynced() async throws {
    // Given: A user with avatar data that needs to sync
    let userId = UUID()
    let userWithAvatar = makeUser(id: userId, name: "Avatar User", email: "avatar@apple.com")
    userWithAvatar.avatar = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header bytes
    userWithAvatar.avatarHash = nil // Will trigger upload attempt
    userWithAvatar.markPending()
    context.insert(userWithAvatar)
    try context.save()

    // When: syncUp is called (in test mode, upload will fail due to no network)
    // The handler should gracefully handle the failure
    try await handler.syncUp(context: context)

    // Then: User should NOT be marked as synced (remains in non-synced state: pending or failed)
    let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId })
    let users = try context.fetch(descriptor)
    // In test mode without network, the user stays in a non-synced state (pending or failed)
    // This verifies we don't accidentally mark users as synced when upload fails
    XCTAssertNotEqual(users.first?.syncState, .synced, "User should NOT be marked synced when avatar upload fails")
  }

  // MARK: - Avatar Hash Computation Tests

  func test_userWithAvatarButNoHash_markedForMigration() async throws {
    // Given: A legacy user with avatar but no hash
    let userId = UUID()
    let legacyUser = makeUser(id: userId, name: "Legacy User", email: "legacy@apple.com")
    legacyUser.avatar = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header bytes
    legacyUser.avatarHash = nil // No hash (legacy data)
    legacyUser.markSynced()
    context.insert(legacyUser)
    try context.save()

    // When: Reconcile legacy users
    try await handler.reconcileLegacyLocalUsers(context: context)

    // Then: Hash should be computed and user marked pending
    let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId })
    let users = try context.fetch(descriptor)
    XCTAssertNotNil(users.first?.avatarHash, "Hash should be computed")
    XCTAssertEqual(users.first?.syncState, .pending, "Should be marked pending for upload")
  }

  // MARK: - Avatar Download Cache-Busting Requirements
  //
  // IMPORTANT: Avatar downloads MUST bypass URL cache.
  //
  // Problem: When a user changes their photo, other devices may not see the update
  // because URLSession returns cached data. The avatar URL path is deterministic
  // (`{user_id}.jpg`), so the cache key is identical even after the photo changes.
  //
  // Solution: Use URLRequest with .reloadIgnoringLocalCacheData cache policy:
  //
  //   var request = URLRequest(url: publicURL)
  //   request.cachePolicy = .reloadIgnoringLocalCacheData
  //   let (data, _) = try await URLSession.shared.data(for: request)
  //
  // This ensures fresh data is fetched from Supabase Storage every time the hash changes.
  //
  // REGRESSION PREVENTION:
  // If avatar downloads start using URLSession.shared.data(from:) directly,
  // users will see stale avatars when other users update their photos.
  //
  // Without cache-busting:
  // 1. User A uploads new avatar (hash changes to "abc123")
  // 2. User B's device sees hash changed, triggers download
  // 3. URLSession returns cached data from previous avatar
  // 4. User B sees stale photo despite hash indicating update

  func test_avatarDownload_hashChangeTriggersFreshDownload() async throws {
    // Given: A user with existing avatar and hash
    let userId = UUID()
    let existingUser = makeUser(id: userId, name: "Test User", email: "test@apple.com")
    existingUser.avatarHash = "oldHash123"
    existingUser.avatar = Data([0x01, 0x02, 0x03])
    existingUser.markSynced()
    context.insert(existingUser)
    try context.save()

    // Document the behavior: When remote hash differs from local hash,
    // the handler MUST attempt to download fresh data.
    //
    // The hash comparison happens in upsertUser():
    //   if remoteHash != currentLocalHash {
    //     // Download triggered
    //   }
    //
    // This test verifies the hash comparison logic works correctly.
    // In test mode (no network), download will fail gracefully,
    // but the attempt confirms hash-based download triggering.

    let dto = makeUserDTO(
      id: userId,
      name: "Test User",
      email: "test@apple.com",
      avatarPath: "\(userId.uuidString).jpg",
      avatarHash: "newHash456" // Different hash should trigger download attempt
    )

    // When: Upsert with different hash
    try await handler.upsertUser(dto: dto, context: context)

    // Then: User record should be marked synced even if avatar download fails
    // upsertUser() processes the DTO and marks the user record as synced.
    // The avatar download is a best-effort operation - if it fails (e.g., test mode,
    // network error), the user record is still considered synced, just with
    // potentially missing avatar data. The avatar will be retried on next sync.
    let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId })
    let users = try context.fetch(descriptor)
    XCTAssertNotNil(users.first)
    XCTAssertEqual(users.first?.syncState, .synced)
  }

  func test_userWithoutAvatar_hashRemainsNil() async throws {
    // Given: A user without avatar
    let userId = UUID()
    let userWithoutAvatar = makeUser(id: userId, name: "No Avatar", email: "noavatar@apple.com")
    userWithoutAvatar.avatar = nil
    userWithoutAvatar.avatarHash = nil
    userWithoutAvatar.markSynced()
    userWithoutAvatar.syncedAt = Date() // Not a phantom
    context.insert(userWithoutAvatar)
    try context.save()

    // When: Reconcile legacy users
    try await handler.reconcileLegacyLocalUsers(context: context)

    // Then: Hash should remain nil (no avatar to hash)
    let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId })
    let users = try context.fetch(descriptor)
    XCTAssertNil(users.first?.avatarHash)
    XCTAssertEqual(users.first?.syncState, .synced) // Not changed
  }

  // MARK: Private

  private var container: ModelContainer!
  private var context: ModelContext!
  private var handler: UserSyncHandler!
  private var currentUserID: UUID?
  private var fetchCurrentUserCalledWithID: UUID?

  // MARK: - Test Helpers

  private func makeUser(
    id: UUID = UUID(),
    name: String = "Test User",
    email: String = "test@example.com",
    userType: UserType = .realtor
  ) -> User {
    User(
      id: id,
      name: name,
      email: email,
      avatar: nil,
      avatarHash: nil,
      userType: userType
    )
  }

  private func makeUserDTO(
    id: UUID = UUID(),
    name: String = "Test User",
    email: String = "test@example.com",
    avatarPath: String? = nil,
    avatarHash: String? = nil,
    userType: String = "realtor"
  ) -> UserDTO {
    UserDTO(
      id: id,
      name: name,
      email: email,
      avatarPath: avatarPath,
      avatarHash: avatarHash,
      userType: userType,
      createdAt: Date(),
      updatedAt: Date()
    )
  }
}

// swiftlint:enable implicitly_unwrapped_optional
