//
//  SupabaseTestHelpers.swift
//  Dispatch
//
//  Created for Phase 1.3: Testing Infrastructure
//  Direct Supabase queries for verification and debugging
//

import Foundation
import OSLog
import Supabase

// MARK: - EntityCounts

/// Counts of entities in Supabase (used to avoid large_tuple)
struct EntityCounts {
  let tasks: Int
  let activities: Int
  let listings: Int
  let users: Int
}

// MARK: - SupabaseTestHelpers

/// Helper methods for directly querying Supabase during testing
/// Used to verify sync operations independent of SwiftData state
@MainActor
enum SupabaseTestHelpers {

  // MARK: Internal

  /// Fetch all tasks from Supabase
  /// - Returns: Array of TaskDTOs or empty array on error
  static func fetchAllTasks() async -> [TaskDTO] {
    do {
      return try await supabase
        .from("tasks")
        .select()
        .order("created_at", ascending: false)
        .execute()
        .value
    } catch {
      Self.logger.error("Failed to fetch tasks: \(String(describing: error))")
      return []
    }
  }

  /// Fetch all activities from Supabase
  /// - Returns: Array of ActivityDTOs or empty array on error
  static func fetchAllActivities() async -> [ActivityDTO] {
    do {
      return try await supabase
        .from("activities")
        .select()
        .order("created_at", ascending: false)
        .execute()
        .value
    } catch {
      Self.logger.error("Failed to fetch activities: \(String(describing: error))")
      return []
    }
  }

  /// Fetch all listings from Supabase
  /// - Returns: Array of ListingDTOs or empty array on error
  static func fetchAllListings() async -> [ListingDTO] {
    do {
      return try await supabase
        .from("listings")
        .select()
        .order("created_at", ascending: false)
        .execute()
        .value
    } catch {
      Self.logger.error("Failed to fetch listings: \(String(describing: error))")
      return []
    }
  }

  /// Fetch all users from Supabase
  /// - Returns: Array of UserDTOs or empty array on error
  static func fetchAllUsers() async -> [UserDTO] {
    do {
      return try await supabase
        .from("users")
        .select()
        .order("created_at", ascending: false)
        .execute()
        .value
    } catch {
      Self.logger.error("Failed to fetch users: \(String(describing: error))")
      return []
    }
  }

  /// Fetch a specific task by ID from Supabase
  /// - Parameter id: The task UUID
  /// - Returns: TaskDTO if found, nil otherwise
  static func fetchTask(id: UUID) async -> TaskDTO? {
    do {
      let dtos: [TaskDTO] = try await supabase
        .from("tasks")
        .select()
        .eq("id", value: id.uuidString)
        .execute()
        .value
      return dtos.first
    } catch {
      Self.logger.error("Failed to fetch task \(id): \(String(describing: error))")
      return nil
    }
  }

  /// Fetch a specific activity by ID from Supabase
  /// - Parameter id: The activity UUID
  /// - Returns: ActivityDTO if found, nil otherwise
  static func fetchActivity(id: UUID) async -> ActivityDTO? {
    do {
      let dtos: [ActivityDTO] = try await supabase
        .from("activities")
        .select()
        .eq("id", value: id.uuidString)
        .execute()
        .value
      return dtos.first
    } catch {
      Self.logger.error("Failed to fetch activity \(id): \(String(describing: error))")
      return nil
    }
  }

  /// Fetch a specific listing by ID from Supabase
  /// - Parameter id: The listing UUID
  /// - Returns: ListingDTO if found, nil otherwise
  static func fetchListing(id: UUID) async -> ListingDTO? {
    do {
      let dtos: [ListingDTO] = try await supabase
        .from("listings")
        .select()
        .eq("id", value: id.uuidString)
        .execute()
        .value
      return dtos.first
    } catch {
      Self.logger.error("Failed to fetch listing \(id): \(String(describing: error))")
      return nil
    }
  }

  /// Get count of all entities in Supabase
  /// - Returns: EntityCounts struct with counts for each entity type
  static func fetchCounts() async -> EntityCounts {
    async let tasks = fetchAllTasks()
    async let activities = fetchAllActivities()
    async let listings = fetchAllListings()
    async let users = fetchAllUsers()

    let (t, a, l, u) = await (tasks, activities, listings, users)
    return EntityCounts(tasks: t.count, activities: a.count, listings: l.count, users: u.count)
  }

  /// Delete a task from Supabase by ID
  /// - Parameter id: The task UUID to delete
  /// - Returns: True if successful
  static func deleteTask(id: UUID) async -> Bool {
    do {
      try await supabase
        .from("tasks")
        .delete()
        .eq("id", value: id.uuidString)
        .execute()
      return true
    } catch {
      Self.logger.error("Failed to delete task \(id): \(String(describing: error))")
      return false
    }
  }

  /// Delete an activity from Supabase by ID
  /// - Parameter id: The activity UUID to delete
  /// - Returns: True if successful
  static func deleteActivity(id: UUID) async -> Bool {
    do {
      try await supabase
        .from("activities")
        .delete()
        .eq("id", value: id.uuidString)
        .execute()
      return true
    } catch {
      Self.logger.error("Failed to delete activity \(id): \(String(describing: error))")
      return false
    }
  }

  /// Delete a listing from Supabase by ID
  /// - Parameter id: The listing UUID to delete
  /// - Returns: True if successful
  static func deleteListing(id: UUID) async -> Bool {
    do {
      try await supabase
        .from("listings")
        .delete()
        .eq("id", value: id.uuidString)
        .execute()
      return true
    } catch {
      Self.logger.error("Failed to delete listing \(id): \(String(describing: error))")
      return false
    }
  }

  /// Delete all test data (entities with deterministic UUIDs)
  /// Use with caution - only for test cleanup
  static func deleteAllTestData() async {
    // Delete in reverse FK order: activities/tasks → listings → users
    // Test UUIDs follow pattern: 00000000-0000-0000-{type}-{index}

    Self.logger.info("Cleaning up test data...")

    // Delete tasks (type = 0002)
    do {
      try await supabase
        .from("tasks")
        .delete()
        .like("id", pattern: "00000000-0000-0000-0002-%")
        .execute()
      Self.logger.info("Deleted test tasks")
    } catch {
      Self.logger.error("Failed to delete test tasks: \(String(describing: error))")
    }

    // Delete activities (type = 0003)
    do {
      try await supabase
        .from("activities")
        .delete()
        .like("id", pattern: "00000000-0000-0000-0003-%")
        .execute()
      Self.logger.info("Deleted test activities")
    } catch {
      Self.logger.error("Failed to delete test activities: \(String(describing: error))")
    }

    // Delete listings (type = 0004)
    do {
      try await supabase
        .from("listings")
        .delete()
        .like("id", pattern: "00000000-0000-0000-0004-%")
        .execute()
      Self.logger.info("Deleted test listings")
    } catch {
      Self.logger.error("Failed to delete test listings: \(String(describing: error))")
    }

    // Note: Not deleting users as they may be needed for RLS
    Self.logger.info("Test data cleanup complete (users preserved)")
  }

  /// Verify a task exists in Supabase with matching title
  /// - Parameters:
  ///   - id: The task UUID
  ///   - expectedTitle: The expected title
  /// - Returns: True if task exists with matching title
  static func verifyTask(id: UUID, expectedTitle: String) async -> Bool {
    guard let dto = await fetchTask(id: id) else { return false }
    return dto.title == expectedTitle
  }

  /// Verify an activity exists in Supabase with matching title
  /// - Parameters:
  ///   - id: The activity UUID
  ///   - expectedTitle: The expected title
  /// - Returns: True if activity exists with matching title
  static func verifyActivity(id: UUID, expectedTitle: String) async -> Bool {
    guard let dto = await fetchActivity(id: id) else { return false }
    return dto.title == expectedTitle
  }

  /// Verify a listing exists in Supabase with matching address
  /// - Parameters:
  ///   - id: The listing UUID
  ///   - expectedAddress: The expected address
  /// - Returns: True if listing exists with matching address
  static func verifyListing(id: UUID, expectedAddress: String) async -> Bool {
    guard let dto = await fetchListing(id: id) else { return false }
    return dto.address == expectedAddress
  }

  // MARK: Private

  private static let logger = Logger(subsystem: "Dispatch", category: "SupabaseTestHelpers")
}
