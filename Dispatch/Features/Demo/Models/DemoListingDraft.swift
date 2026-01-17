//
//  DemoListingDraft.swift
//  Dispatch
//
//  Self-contained demo model for listing draft editing view.
//  For slide deck presentation - no real data connections.
//

import SwiftUI

// MARK: - DemoPhoto

struct DemoPhoto: Identifiable, Equatable {
  static var allPhotos: [DemoPhoto] {
    let labels = [
      "Exterior Front",
      "Exterior Angle",
      "Living Room",
      "Living Detail",
      "Kitchen Wide",
      "Kitchen Island",
      "Dining Area",
      "Primary Bedroom",
      "Primary Ensuite",
      "Second Bedroom",
      "Third Bedroom",
      "Second Bath",
      "Walk-in Closet",
      "Rooftop Terrace",
      "Terrace View",
      "Lake View 1",
      "Lake View 2",
      "Amenities",
      "Lobby",
      "Floor Plan"
    ]

    return labels.enumerated().map { index, label in
      DemoPhoto(
        id: UUID(),
        index: index + 1,
        imageName: "demo_photo_\(index + 1)",
        label: label
      )
    }
  }

  let id: UUID
  let index: Int
  let imageName: String
  let label: String

}

// MARK: - DemoListingType

enum DemoListingType: String, CaseIterable, Identifiable {
  case sale = "Sale"
  case rent = "Rent"
  case lease = "Lease"

  var id: String { rawValue }
}

// MARK: - DemoListingDraft

@Observable
final class DemoListingDraft {

  // MARK: - Snapshot (for dirty tracking)

  private struct Snapshot: Equatable {
    let address: String
    let unit: String
    let city: String
    let province: String
    let postalCode: String
    let price: Decimal
    let listingType: DemoListingType
    let bedrooms: Int
    let bathrooms: Int
    let squareFeet: Int
    let headline: String
    let description: String
    let features: [String]
    let photoIDs: [UUID]
    let stage: ListingStage
  }

  // MARK: - Property Details

  var address: String = "1847 Lakeshore Boulevard West"
  var unit: String = "PH 2501"
  var city: String = "Toronto"
  var province: String = "ON"
  var postalCode: String = "M6S 5A4"
  var country: String = "Canada"

  // MARK: - Listing Details

  var price: Decimal = 2_895_000
  var listingType: DemoListingType = .sale
  var mlsNumber: String = "C9456782"
  var bedrooms: Int = 3
  var bathrooms: Int = 2
  var squareFeet: Int = 2450
  var yearBuilt: Int = 2019

  // MARK: - Description

  var headline: String = "Stunning Waterfront Penthouse with Panoramic Views"

  // swiftlint:disable line_length
  var description: String = """
    Experience luxury living at its finest in this breathtaking penthouse suite overlooking Lake Ontario. Floor-to-ceiling windows frame unobstructed views of the Toronto skyline and waterfront, creating a truly spectacular living experience.

    The open-concept layout features engineered hardwood floors throughout, a gourmet kitchen with Miele appliances and quartz countertops, and a spacious primary suite with spa-like ensuite. The private rooftop terrace offers an additional 800 sq ft of outdoor living space, perfect for entertaining or enjoying sunset views over the lake.

    Building amenities include 24-hour concierge, fitness center, indoor pool, and direct access to the waterfront trail. Two underground parking spaces and a storage locker are included.
    """
  // swiftlint:enable line_length

  // MARK: - Features

  var features: [String] = [
    "Floor-to-ceiling windows with lake views",
    "Private 800 sq ft rooftop terrace",
    "Chef's kitchen with Miele appliances",
    "Primary suite with walk-in closet",
    "Spa-like ensuite with heated floors",
    "In-suite laundry",
    "Smart home technology throughout",
    "Two underground parking spaces",
    "Concierge service 24/7",
    "Steps to transit and waterfront trail"
  ]

  // MARK: - Photos

  var photos: [DemoPhoto] = DemoPhoto.allPhotos

  // MARK: - Stage

  var stage: ListingStage = .workingOn

  // MARK: - Edit State

  private var originalSnapshot: Snapshot?

  var isDirty: Bool {
    guard let original = originalSnapshot else { return false }
    return currentSnapshot != original
  }

  private var currentSnapshot: Snapshot {
    Snapshot(
      address: address,
      unit: unit,
      city: city,
      province: province,
      postalCode: postalCode,
      price: price,
      listingType: listingType,
      bedrooms: bedrooms,
      bathrooms: bathrooms,
      squareFeet: squareFeet,
      headline: headline,
      description: description,
      features: features,
      photoIDs: photos.map(\.id),
      stage: stage
    )
  }

  // MARK: - Factory

  static func sample() -> DemoListingDraft {
    let draft = DemoListingDraft()
    draft.originalSnapshot = draft.currentSnapshot
    return draft
  }

  func addFeature(_ feature: String) {
    features.append(feature)
  }

  func removeFeature(at index: Int) {
    guard features.indices.contains(index) else { return }
    features.remove(at: index)
  }

  func removePhoto(at index: Int) {
    guard photos.indices.contains(index) else { return }
    photos.remove(at: index)
  }

  func movePhotos(from source: IndexSet, to destination: Int) {
    photos.move(fromOffsets: source, toOffset: destination)
  }

}
