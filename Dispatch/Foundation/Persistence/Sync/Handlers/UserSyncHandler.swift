//
//  UserSyncHandler.swift
//  Dispatch
//
//  Handles all User-specific sync operations: syncDown, syncUp, upsert, delete.
//  Extracted from EntitySyncHandler for maintainability.
//

import CryptoKit
import Foundation
import Supabase
import SwiftData

// MARK: - UserSyncHandler

/// Handles User entity sync operations.
/// Includes avatar upload/download handling.
@MainActor
final class UserSyncHandler: EntitySyncHandlerProtocol {

  // MARK: Lifecycle

  init(dependencies: SyncHandlerDependencies) {
    self.dependencies = dependencies
  }

  // MARK: Internal

  let dependencies: SyncHandlerDependencies

  // MARK: - SyncDown

  func syncDown(context: ModelContext, since: String) async throws {
    debugLog.log("syncDownUsers() - querying Supabase...", category: .sync)
    var dtos: [UserDTO] = try await supabase
      .from("users")
      .select()
      .gte("updated_at", value: since)
      .execute()
      .value

    debugLog.logSyncOperation(operation: "FETCH", table: "users", count: dtos.count)

    // CRITICAL FIX: If we are authenticated but have no local currentUser,
    // we MUST fetch our own profile regardless of 'since' time.
    // This handles re-login scenarios where the user record is older than lastSyncTime.
    if dependencies.getCurrentUser() == nil, let currentID = dependencies.getCurrentUserID() {
      let isCurrentInBatch = dtos.contains { $0.id == currentID }
      if !isCurrentInBatch {
        debugLog.log("Warning: Current user profile missing from delta sync - force fetching...", category: .sync)
        do {
          let currentUserDTO: UserDTO = try await supabase
            .from("users")
            .select()
            .eq("id", value: currentID)
            .single()
            .execute()
            .value
          debugLog.log("  Force fetched current user profile: \(currentUserDTO.name)", category: .sync)
          dtos.append(currentUserDTO)
        } catch {
          debugLog.error("  Failed to force fetch current user profile", error: error)
        }
      }
    }

    for (index, dto) in dtos.enumerated() {
      debugLog.log("  Upserting user \(index + 1)/\(dtos.count): \(dto.id) - \(dto.name)", category: .sync)
      try await upsertUser(dto: dto, context: context)
    }
  }

  // MARK: - SyncUp

  func syncUp(context: ModelContext) async throws {
    let descriptor = FetchDescriptor<User>()
    let allUsers = try context.fetch(descriptor)
    debugLog.log("syncUpUsers() - fetched \(allUsers.count) total users from SwiftData", category: .sync)

    // Filter for pending or failed users
    let pendingUsers = allUsers.filter { $0.syncState == .pending || $0.syncState == .failed }
    debugLog.logSyncOperation(
      operation: "PENDING",
      table: "users",
      count: pendingUsers.count,
      details: "of \(allUsers.count) total"
    )

    guard !pendingUsers.isEmpty else {
      debugLog.log("  No pending users to sync", category: .sync)
      return
    }

    // Process individually to handle avatar uploads reliably
    for user in pendingUsers {
      do {
        try await uploadAvatarAndSyncUser(user: user, context: context)

      } catch {
        let message = dependencies.userFacingMessage(for: error)
        user.markFailed(message)
        debugLog.log("  Failed to sync user \(user.id): \(error.localizedDescription)", category: .error)
      }
    }
  }

  // MARK: - Upsert

  func upsertUser(dto: UserDTO, context: ModelContext) async throws {
    let targetId = dto.id
    let descriptor = FetchDescriptor<User>(
      predicate: #Predicate { $0.id == targetId }
    )

    // 1. Fetch Existing
    let existing = try context.fetch(descriptor).first

    // 2. Conflict Check (Jobs-standard)
    // If local user is .pending, DO NOT overwrite pending fields with remote data.
    // We only proceed if .synced or .failed
    let shouldApplyScalars = (existing == nil) || (existing?.syncState != .pending)

    // 3. Avatar Logic (Download)
    var newAvatarData: Data?
    var shouldUpdateAvatar = false

    // Determine current local hash
    let currentLocalHash = existing?.avatarHash

    // Check if remote differs
    if let remoteHash = dto.avatarHash {
      if remoteHash != currentLocalHash {
        // Different! Check if we have a path
        if let path = dto.avatarPath {
          debugLog.log("    Avatar hash changed (remote: \(remoteHash.prefix(6))...). Downloading...", category: .sync)
          do {
            // Use Public URL download to bypass strict RLS on `storage.objects`
            let publicURL = try supabase.storage
              .from("avatars")
              .getPublicURL(path: path)

            let (data, _) = try await URLSession.shared.data(from: publicURL)

            newAvatarData = data
            shouldUpdateAvatar = true

            debugLog.log("    Avatar downloaded via Public URL", category: .sync)
          } catch {
            debugLog.error("    Warning: Failed to download avatar", error: error)
            // On failure, keep local
          }
        } else {
          debugLog.log("    Remote hash exists but path is nil. Skipping avatar.", category: .sync)
        }
      }
    } else {
      // Remote hash is NIL.
      // If local is NOT nil, we must clear it (deletion propagated from server)
      if currentLocalHash != nil {
        shouldUpdateAvatar = true
        newAvatarData = nil // Clears it
        debugLog.log("    Remote avatar deleted. Clearing local.", category: .sync)
      }
    }

    if let user = existing {
      // UPDATE
      if shouldApplyScalars {
        debugLog.log("    UPDATE existing user: \(dto.id)", category: .sync)
        user.name = dto.name
        user.email = dto.email
        user.userType = UserType(rawValue: dto.userType) ?? .realtor
        user.updatedAt = dto.updatedAt

        // Only mark synced if we accept the server state
        user.markSynced()
      } else {
        debugLog.log("    SKIP scalar update for user \(dto.id) (Local state: \(user.syncState))", category: .sync)
      }

      // Apply Avatar Update (independent of scalar pending state? Usually yes, binary assets sync separately)
      // If pending, skip avatar overwrite.
      if shouldApplyScalars {
        if shouldUpdateAvatar {
          user.avatar = newAvatarData
          user.avatarHash = dto.avatarHash
        }
      }

    } else {
      // INSERT
      debugLog.log("    INSERT new user: \(dto.id)", category: .sync)
      let newUser = dto.toModel()

      // Apply downloaded avatar
      if shouldUpdateAvatar {
        newUser.avatar = newAvatarData
        newUser.avatarHash = dto.avatarHash // Sync hash too
      }

      newUser.markSynced()
      context.insert(newUser)
    }

    // Update currentUser if this is the one
    if dto.id == dependencies.getCurrentUserID() {
      dependencies.fetchCurrentUser(dto.id)
    }
  }

  // MARK: - Delete

  func deleteLocalUser(id: UUID, context: ModelContext) throws -> Bool {
    let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == id })
    guard let user = try context.fetch(descriptor).first else {
      debugLog.log("deleteLocalUser: User \(id) not found locally", category: .sync)
      return false
    }
    debugLog.log("deleteLocalUser: Deleting user \(id) - \(user.name)", category: .sync)
    context.delete(user)
    return true
  }

  // MARK: - Legacy Migration

  /// One-time local migration to catch "phantom" users that are marked .synced but were never uploaded (syncedAt == nil)
  /// OR users who have avatar data but no hash (legacy data).
  func reconcileLegacyLocalUsers(context: ModelContext) async throws {
    // Fetch ALL users and filter in memory to avoid SwiftData #Predicate enum issues
    let descriptor = FetchDescriptor<User>()
    let allUsers = try context.fetch(descriptor)

    // 1. Phantom Users (Synced but no syncedAt date -> Pending)
    let phantomUsers = allUsers.filter { user in
      user.syncStateRaw == .synced && user.syncedAt == nil
    }

    if !phantomUsers.isEmpty {
      debugLog.log("Found \(phantomUsers.count) phantom legacy users. Marking as pending for upload.", category: .sync)
      for user in phantomUsers {
        user.markPending()
      }
    }

    // 2. Avatar Migration (Avatar Data present but Hash missing)
    let legacyAvatarUsers = allUsers.filter { user in
      user.avatar != nil && user.avatarHash == nil
    }

    if !legacyAvatarUsers.isEmpty {
      debugLog.log("Found \(legacyAvatarUsers.count) users with legacy avatars (no hash). Migrating...", category: .sync)

      for user in legacyAvatarUsers {
        if let data = user.avatar {
          // Compute proper hash
          let (normalized, hash) = await normalizeAndHash(data: data)

          // Update model
          user.avatar = normalized
          user.avatarHash = hash

          // Mark pending to ensure we sync this up to server
          user.markPending()
        }
      }
      debugLog.log("Migrated \(legacyAvatarUsers.count) legacy avatars", category: .sync)
    }
  }

  // MARK: Private

  /// Extracted helper for clarity and isolation
  private func uploadAvatarAndSyncUser(user: User, context _: ModelContext) async throws {
    var avatarPath: String?
    var avatarHash: String?
    var uploadFailed = false

    if let avatarData = user.avatar {
      // Normalize & Hash (Off-Main)
      let (normalizedData, newHash) = await normalizeAndHash(data: avatarData)

      // If changed, Upload
      if newHash != user.avatarHash {
        debugLog.log("  Avatar hash changed. Uploading...", category: .sync)

        let path = "\(user.id.uuidString).jpg"

        do {
          try await uploadAvatar(path: path, data: normalizedData)

          // Success: Update local
          user.avatar = normalizedData
          user.avatarHash = newHash

          avatarPath = path
          avatarHash = newHash
          debugLog.log("  Avatar uploaded", category: .sync)
        } catch {
          debugLog.error("  Warning: Avatar upload failed", error: error)
          uploadFailed = true // Mark failure
        }
      } else {
        debugLog.log("  Avatar hash matches. Skipping upload.", category: .sync)
        // Deterministic path reconstruction
        avatarPath = "\(user.id.uuidString).jpg"
        avatarHash = user.avatarHash
      }
    } else {
      // Nil avatar means delete
      avatarPath = nil
      avatarHash = nil
    }

    // Critical Safety: If upload failed, we SKIP upsert to avoid wiping/staling server state.
    guard !uploadFailed else {
      debugLog.log("  Skipping User upsert due to avatar failure", category: .sync)
      return // User stays .pending
    }

    // Upsert
    let dto = UserDTO(from: user, avatarPath: avatarPath, avatarHash: avatarHash)
    try await supabase.from("users").upsert([dto]).execute()

    user.markSynced()
    debugLog.log("  User \(user.id) synced", category: .sync)
  }

  /// Helper: Normalizes image to JPEG and computes SHA256 (Off-Main Actor)
  nonisolated private func normalizeAndHash(data: Data) async -> (Data, String) {
    await Task.detached(priority: .userInitiated) {
      let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
      // Returning original data as "normalized" for now to avoid massive dependency add.
      // TODO: Add Image Resizing.
      return (data, hash)
    }.value
  }

  private func uploadAvatar(path: String, data: Data) async throws {
    let bucket = "avatars"
    _ = try await supabase.storage
      .from(bucket)
      .upload(
        path,
        data: data,
        options: FileOptions(
          cacheControl: "3600",
          contentType: "image/jpeg",
          upsert: true
        )
      )
  }
}
