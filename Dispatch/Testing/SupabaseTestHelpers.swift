//
//  SupabaseTestHelpers.swift
//  Dispatch
//
//  Created for Phase 1.3: Testing Infrastructure
//  Direct Supabase queries for verification and debugging
//

import Foundation
import Supabase

/// Counts of entities in Supabase (used to avoid large_tuple)
struct EntityCounts {
    let tasks: Int
    let activities: Int
    let listings: Int
    let users: Int
}

/// Helper methods for directly querying Supabase during testing
/// Used to verify sync operations independent of SwiftData state
@MainActor
enum SupabaseTestHelpers {

    // MARK: - Fetch Methods

    /// Fetch all tasks from Supabase
    /// - Returns: Array of TaskDTOs or empty array on error
    static func fetchAllTasks() async -> [TaskDTO] {
        do {
            let dtos: [TaskDTO] = try await supabase
                .from("tasks")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            return dtos
        } catch {
            print("[SupabaseTestHelpers] Failed to fetch tasks: \(error)")
            return []
        }
    }

    /// Fetch all activities from Supabase
    /// - Returns: Array of ActivityDTOs or empty array on error
    static func fetchAllActivities() async -> [ActivityDTO] {
        do {
            let dtos: [ActivityDTO] = try await supabase
                .from("activities")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            return dtos
        } catch {
            print("[SupabaseTestHelpers] Failed to fetch activities: \(error)")
            return []
        }
    }

    /// Fetch all listings from Supabase
    /// - Returns: Array of ListingDTOs or empty array on error
    static func fetchAllListings() async -> [ListingDTO] {
        do {
            let dtos: [ListingDTO] = try await supabase
                .from("listings")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            return dtos
        } catch {
            print("[SupabaseTestHelpers] Failed to fetch listings: \(error)")
            return []
        }
    }

    /// Fetch all users from Supabase
    /// - Returns: Array of UserDTOs or empty array on error
    static func fetchAllUsers() async -> [UserDTO] {
        do {
            let dtos: [UserDTO] = try await supabase
                .from("users")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            return dtos
        } catch {
            print("[SupabaseTestHelpers] Failed to fetch users: \(error)")
            return []
        }
    }

    // MARK: - Fetch by ID

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
            print("[SupabaseTestHelpers] Failed to fetch task \(id): \(error)")
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
            print("[SupabaseTestHelpers] Failed to fetch activity \(id): \(error)")
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
            print("[SupabaseTestHelpers] Failed to fetch listing \(id): \(error)")
            return nil
        }
    }

    // MARK: - Count Methods

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

    // MARK: - Delete Methods (for cleanup)

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
            print("[SupabaseTestHelpers] Failed to delete task \(id): \(error)")
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
            print("[SupabaseTestHelpers] Failed to delete activity \(id): \(error)")
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
            print("[SupabaseTestHelpers] Failed to delete listing \(id): \(error)")
            return false
        }
    }

    /// Delete all test data (entities with deterministic UUIDs)
    /// Use with caution - only for test cleanup
    static func deleteAllTestData() async {
        // Delete in reverse FK order: activities/tasks → listings → users
        // Test UUIDs follow pattern: 00000000-0000-0000-{type}-{index}

        print("[SupabaseTestHelpers] Cleaning up test data...")

        // Delete tasks (type = 0002)
        do {
            try await supabase
                .from("tasks")
                .delete()
                .like("id", pattern: "00000000-0000-0000-0002-%")
                .execute()
            print("[SupabaseTestHelpers] Deleted test tasks")
        } catch {
            print("[SupabaseTestHelpers] Failed to delete test tasks: \(error)")
        }

        // Delete activities (type = 0003)
        do {
            try await supabase
                .from("activities")
                .delete()
                .like("id", pattern: "00000000-0000-0000-0003-%")
                .execute()
            print("[SupabaseTestHelpers] Deleted test activities")
        } catch {
            print("[SupabaseTestHelpers] Failed to delete test activities: \(error)")
        }

        // Delete listings (type = 0004)
        do {
            try await supabase
                .from("listings")
                .delete()
                .like("id", pattern: "00000000-0000-0000-0004-%")
                .execute()
            print("[SupabaseTestHelpers] Deleted test listings")
        } catch {
            print("[SupabaseTestHelpers] Failed to delete test listings: \(error)")
        }

        // Note: Not deleting users as they may be needed for RLS
        print("[SupabaseTestHelpers] Test data cleanup complete (users preserved)")
    }

    // MARK: - Verification Methods

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
}
