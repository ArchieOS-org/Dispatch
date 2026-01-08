//
//  UITestSeeder.swift
//  Dispatch
//
//  Seeds deterministic data for UI tests.
//  Uses stable UUIDs to enable reliable UI element identification.
//

import Foundation
import SwiftData

/// Seeder for UI test data. Uses the same stable IDs as PreviewDataFactory.
@MainActor
enum UITestSeeder {
  /// Stable IDs for UI test verification
  static let testRealtorID = PreviewDataFactory.bobID
  static let testListingID = PreviewDataFactory.listingID
  static let testPropertyID = UUID(uuidString: "880e8400-e29b-41d4-a716-446655440003")!

  private static var hasSeeded = false

  /// Seeds the container with test data if not already seeded.
  static func seedIfNeeded(container: ModelContainer) {
    guard !hasSeeded else { return }
    hasSeeded = true

    let context = container.mainContext
    PreviewDataFactory.seed(context)

    // Add a Property for property navigation tests
    let property = Property(
      id: testPropertyID,
      address: "456 Test Property Lane",
      unit: nil,
      city: "Toronto",
      province: "ON",
      postalCode: "M5V 2T6",
      ownedBy: testRealtorID
    )
    property.syncState = .synced
    context.insert(property)

    try? context.save()
  }
}
