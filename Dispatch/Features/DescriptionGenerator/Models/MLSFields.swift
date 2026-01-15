//
//  MLSFields.swift
//  Dispatch
//
//  MLS fields model for copy-paste into MLS systems.
//  Groups all standard MLS fields that admins need to populate.
//

import Foundation

// MARK: - MLSFields

/// All MLS fields that need to be populated for a listing.
/// Each field can be copied individually or all at once.
struct MLSFields: Equatable {

  // MARK: - Property Details

  /// Property type (e.g., "Single Family", "Condo", "Townhouse")
  var propertyType: String = ""

  /// Year the property was built
  var yearBuilt: String = ""

  /// Total square footage
  var squareFootage: String = ""

  /// Lot size (e.g., "0.25 acres", "10,890 sq ft")
  var lotSize: String = ""

  /// Number of bedrooms
  var bedrooms: String = ""

  /// Number of bathrooms (e.g., "2.5")
  var bathrooms: String = ""

  /// Number of stories
  var stories: String = ""

  /// Number of parking spaces
  var parkingSpaces: String = ""

  /// Garage type (e.g., "Attached 2-Car", "Detached", "None")
  var garageType: String = ""

  // MARK: - Features

  /// Heating and cooling details
  var heatingCooling: String = ""

  /// Flooring types
  var flooring: String = ""

  /// Included appliances
  var appliances: String = ""

  /// Exterior features (e.g., "Deck", "Pool", "Fence")
  var exteriorFeatures: String = ""

  /// Interior features (e.g., "Fireplace", "High Ceilings")
  var interiorFeatures: String = ""

  /// Community features (e.g., "HOA", "Pool", "Tennis Courts")
  var communityFeatures: String = ""

  // MARK: - Descriptions (AI-generated)

  /// Main public listing description (250-500 words)
  var publicRemarks: String = ""

  /// Private remarks for agents only
  var privateRemarks: String = ""

  /// Driving directions to the property
  var directions: String = ""

  // MARK: - Marketing

  /// Short catchy headline for the listing
  var headline: String = ""

  /// One-liner marketing hook
  var tagline: String = ""

  // MARK: - Computed Properties

  /// Whether all required fields have content
  var isComplete: Bool {
    !propertyType.isEmpty &&
    !squareFootage.isEmpty &&
    !bedrooms.isEmpty &&
    !bathrooms.isEmpty &&
    !publicRemarks.isEmpty &&
    !headline.isEmpty
  }

  /// Format all fields for bulk copy
  func formattedForCopy() -> String {
    // PHASE 3: Implement proper MLS formatting based on target MLS system
    var lines: [String] = []

    // Property Details
    if !propertyType.isEmpty { lines.append("Property Type: \(propertyType)") }
    if !yearBuilt.isEmpty { lines.append("Year Built: \(yearBuilt)") }
    if !squareFootage.isEmpty { lines.append("Square Footage: \(squareFootage)") }
    if !lotSize.isEmpty { lines.append("Lot Size: \(lotSize)") }
    if !bedrooms.isEmpty { lines.append("Bedrooms: \(bedrooms)") }
    if !bathrooms.isEmpty { lines.append("Bathrooms: \(bathrooms)") }
    if !stories.isEmpty { lines.append("Stories: \(stories)") }
    if !parkingSpaces.isEmpty { lines.append("Parking Spaces: \(parkingSpaces)") }
    if !garageType.isEmpty { lines.append("Garage: \(garageType)") }

    // Features
    if !heatingCooling.isEmpty { lines.append("Heating/Cooling: \(heatingCooling)") }
    if !flooring.isEmpty { lines.append("Flooring: \(flooring)") }
    if !appliances.isEmpty { lines.append("Appliances: \(appliances)") }
    if !exteriorFeatures.isEmpty { lines.append("Exterior Features: \(exteriorFeatures)") }
    if !interiorFeatures.isEmpty { lines.append("Interior Features: \(interiorFeatures)") }
    if !communityFeatures.isEmpty { lines.append("Community Features: \(communityFeatures)") }

    // Descriptions
    if !headline.isEmpty { lines.append("\nHeadline: \(headline)") }
    if !tagline.isEmpty { lines.append("Tagline: \(tagline)") }
    if !publicRemarks.isEmpty { lines.append("\nPublic Remarks:\n\(publicRemarks)") }
    if !privateRemarks.isEmpty { lines.append("\nPrivate Remarks:\n\(privateRemarks)") }
    if !directions.isEmpty { lines.append("\nDirections:\n\(directions)") }

    return lines.joined(separator: "\n")
  }
}
