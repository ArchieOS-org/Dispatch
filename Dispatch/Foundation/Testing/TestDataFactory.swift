//
//  TestDataFactory.swift
//  Dispatch
//
//  Created for Phase 1.3: Testing Infrastructure
//  Factory methods for creating test entities with deterministic data
//

// swiftlint:disable force_unwrapping

import Foundation
import SwiftData

/// Factory for creating test entities with realistic Canadian data
/// All entities are created with syncedAt = nil to ensure they're dirty for sync testing
@MainActor
enum TestDataFactory {

  // MARK: Internal

  /// Create a test user with realistic data
  /// - Parameters:
  ///   - context: The ModelContext to insert into
  ///   - index: Index for deterministic UUID generation (default: 1)
  ///   - isStaff: Whether user is staff (admin/marketing) or realtor (default: true)
  /// - Returns: The created User entity
  @discardableResult
  static func createTestUser(
    context: ModelContext,
    index: Int = 1,
    isStaff: Bool = true
  ) -> User {
    let names = ["Alice Johnson", "Bob Smith", "Carol Williams", "David Brown", "Emma Davis"]
    let name = names[(index - 1) % names.count]
    let emailPrefix = name.lowercased().replacingOccurrences(of: " ", with: ".")

    let user = User(
      id: deterministicUUID(type: "user", index: index),
      name: name,
      email: "\(emailPrefix)@dispatch-test.ca",
      avatar: nil,
      userType: isStaff ? .admin : .realtor,
      createdAt: Date(),
      updatedAt: Date()
    )
    user.syncedAt = nil // Ensure dirty for sync testing
    context.insert(user)
    return user
  }

  /// Create a test task with realistic data
  /// - Parameters:
  ///   - context: The ModelContext to insert into
  ///   - index: Index for deterministic UUID generation (default: 1)
  ///   - listingId: Optional listing ID to associate with
  /// - Returns: The created TaskItem entity
  @discardableResult
  static func createTestTask(
    context: ModelContext,
    index: Int = 1,
    listingId: UUID? = nil
  ) -> TaskItem {
    let titles = [
      "Order title search",
      "Schedule home inspection",
      "Prepare condition waiver",
      "Request mortgage approval letter",
      "Coordinate key exchange"
    ]
    let descriptions = [
      "Contact Stewart Title for property search",
      "Book with certified inspector - 3 hour window needed",
      "Draft waiver documents for buyer signature",
      "Follow up with TD Bank mortgage specialist",
      "Arrange handover at closing - confirm lockbox code"
    ]

    let titleIndex = (index - 1) % titles.count

    let task = TaskItem(
      id: deterministicUUID(type: "task", index: index),
      title: titles[titleIndex],
      taskDescription: descriptions[titleIndex],
      dueDate: Calendar.current.date(byAdding: .day, value: index, to: Date()),
      status: .open,
      declaredBy: deterministicUUID(type: "user", index: 1),
      listingId: listingId,
      createdVia: .dispatch,
      sourceSlackMessages: nil,
      createdAt: Date(),
      updatedAt: Date()
    )
    task.syncedAt = nil // Ensure dirty for sync testing
    context.insert(task)
    return task
  }

  /// Create a test activity with realistic data
  /// - Parameters:
  ///   - context: The ModelContext to insert into
  ///   - index: Index for deterministic UUID generation (default: 1)
  ///   - listingId: Optional listing ID to associate with
  /// - Returns: The created Activity entity
  @discardableResult
  static func createTestActivity(
    context: ModelContext,
    index: Int = 1,
    listingId: UUID? = nil
  ) -> Activity {
    let titles = [
      "Property showing at 123 Queen St W",
      "Open house preparation",
      "Client consultation call",
      "Offer presentation meeting",
      "Final walkthrough inspection"
    ]
    let descriptions = [
      "Show property to Smith family - interested in 2BR units",
      "Set up signage, prepare feature sheets, arrange refreshments",
      "Discuss pricing strategy and market conditions",
      "Present competing offers to seller",
      "Pre-closing inspection with buyers"
    ]
    let durations: [Int] = [60, 180, 30, 90, 45] // minutes

    let activityIndex = (index - 1) % titles.count

    let activity = Activity(
      id: deterministicUUID(type: "activity", index: index),
      title: titles[activityIndex],
      activityDescription: descriptions[activityIndex],
      dueDate: Calendar.current.date(byAdding: .day, value: index, to: Date()),
      status: .open,
      declaredBy: deterministicUUID(type: "user", index: 1),
      listingId: listingId,
      createdVia: .dispatch,
      sourceSlackMessages: nil,
      duration: TimeInterval(durations[activityIndex] * 60),
      createdAt: Date(),
      updatedAt: Date()
    )
    activity.syncedAt = nil // Ensure dirty for sync testing
    context.insert(activity)
    return activity
  }

  /// Create a test listing with realistic Toronto/GTA data
  /// - Parameters:
  ///   - context: The ModelContext to insert into
  ///   - index: Index for deterministic UUID generation (default: 1)
  /// - Returns: The created Listing entity
  @discardableResult
  static func createTestListing(
    context: ModelContext,
    index: Int = 1
  ) -> Listing {
    let addresses = [
      ("123 Queen Street West", "Toronto", "M5H 2M9"),
      ("456 Bloor Street East", "Toronto", "M4W 1H1"),
      ("789 Yonge Street", "Toronto", "M4Y 1Z2"),
      ("321 King Street West", "Toronto", "M5V 1J5"),
      ("654 Bay Street", "Toronto", "M5G 2K4")
    ]
    let prices: [Decimal] = [899_000, 1_250_000, 675_000, 2_100_000, 549_000]
    let mlsNumbers = ["W1234567", "E2345678", "C3456789", "W4567890", "C5678901"]
    let types: [ListingType] = [.sale, .sale, .lease, .sale, .lease]

    let listingIndex = (index - 1) % addresses.count
    let (address, city, postalCode) = addresses[listingIndex]

    let listing = Listing(
      id: deterministicUUID(type: "listing", index: index),
      address: address,
      city: city,
      province: "Ontario",
      postalCode: postalCode,
      country: "Canada",
      price: prices[listingIndex],
      mlsNumber: mlsNumbers[listingIndex],
      listingType: types[listingIndex],
      status: .active,
      ownedBy: deterministicUUID(type: "user", index: 1),
      createdVia: .dispatch,
      sourceSlackMessages: nil,
      createdAt: Date(),
      updatedAt: Date()
    )
    listing.syncedAt = nil // Ensure dirty for sync testing
    context.insert(listing)
    return listing
  }

  /// Create a full test dataset with multiple entities
  /// - Parameters:
  ///   - context: The ModelContext to insert into
  ///   - userCount: Number of users to create (default: 3)
  ///   - listingCount: Number of listings to create (default: 3)
  ///   - tasksPerListing: Number of tasks per listing (default: 2)
  ///   - activitiesPerListing: Number of activities per listing (default: 2)
  static func createTestDataset(
    context: ModelContext,
    userCount: Int = 3,
    listingCount: Int = 3,
    tasksPerListing: Int = 2,
    activitiesPerListing: Int = 2
  ) {
    // Create users (first is realtor, rest are staff)
    for i in 1 ... userCount {
      createTestUser(context: context, index: i, isStaff: i > 1)
    }

    // Create listings with associated tasks and activities
    var taskIndex = 1
    var activityIndex = 1

    for i in 1 ... listingCount {
      let listing = createTestListing(context: context, index: i)

      for _ in 1 ... tasksPerListing {
        createTestTask(context: context, index: taskIndex, listingId: listing.id)
        taskIndex += 1
      }

      for _ in 1 ... activitiesPerListing {
        createTestActivity(context: context, index: activityIndex, listingId: listing.id)
        activityIndex += 1
      }
    }
  }

  // MARK: Private

  /// Generate deterministic UUID based on entity type and index
  /// Format: 00000000-0000-0000-{type}-{index as 12 hex digits}
  private static func deterministicUUID(type: String, index: Int) -> UUID {
    let typeHex =
      switch type {
      case "user": "0001"
      case "task": "0002"
      case "activity": "0003"
      case "listing": "0004"
      default: "0000"
      }
    // Mask to 48 bits (12 hex digits max = 0xFFFFFFFFFFFF)
    let maskedIndex = UInt64(clamping: index) & 0xFFFF_FFFF_FFFF
    let indexHex = String(format: "%012llx", maskedIndex)
    return UUID(uuidString: "00000000-0000-0000-\(typeHex)-\(indexHex)")!
  }

}
