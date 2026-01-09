//
//  ListingDTO.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

struct ListingDTO: Codable, Sendable {
  enum CodingKeys: String, CodingKey {
    case id
    case address
    case city
    case province
    case country
    case price
    case status
    case stage
    case postalCode = "postal_code"
    case mlsNumber = "mls_number"
    case listingType = "listing_type"
    case ownedBy = "owned_by"
    case propertyId = "property_id"
    case createdVia = "created_via"
    case sourceSlackMessages = "source_slack_messages"
    case activatedAt = "activated_at"
    case pendingAt = "pending_at"
    case closedAt = "closed_at"
    case deletedAt = "deleted_at"
    case dueDate = "due_date"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }

  let id: UUID
  let address: String
  let city: String?
  let province: String?
  let postalCode: String?
  let country: String?
  let price: Double?
  let mlsNumber: String?
  let listingType: String
  let status: String
  let stage: String?
  let ownedBy: UUID
  let propertyId: UUID?
  let createdVia: String
  let sourceSlackMessages: [String]?
  let activatedAt: Date?
  let pendingAt: Date?
  let closedAt: Date?
  let deletedAt: Date?
  let dueDate: Date?
  let createdAt: Date
  let updatedAt: Date

  func toModel() -> Listing {
    let resolvedListingType: ListingType
    if let lt = ListingType(rawValue: listingType) {
      resolvedListingType = lt
    } else {
      #if DEBUG
      let listingTypeMessage = "⚠️ Invalid listingType '\(listingType)' for Listing \(id), defaulting to .sale"
      Task { @MainActor in
        debugLog.log(listingTypeMessage, category: .sync)
      }
      #endif
      resolvedListingType = .sale
    }

    let resolvedStatus: ListingStatus
    if let s = ListingStatus(rawValue: status) {
      resolvedStatus = s
    } else {
      #if DEBUG
      let statusMessage = "⚠️ Invalid status '\(status)' for Listing \(id), defaulting to .draft"
      Task { @MainActor in
        debugLog.log(statusMessage, category: .sync)
      }
      #endif
      resolvedStatus = .draft
    }

    let resolvedCreatedVia: CreationSource
    if let c = CreationSource(rawValue: createdVia) {
      resolvedCreatedVia = c
    } else {
      #if DEBUG
      let createdViaMessage = "⚠️ Invalid createdVia '\(createdVia)' for Listing \(id), defaulting to .dispatch"
      Task { @MainActor in
        debugLog.log(createdViaMessage, category: .sync)
      }
      #endif
      resolvedCreatedVia = .dispatch
    }

    // Stage with fallback (nullable for backward compat during rollout)
    let resolvedStage: ListingStage
    if let stageValue = stage, let s = ListingStage(rawValue: stageValue) {
      resolvedStage = s
    } else {
      if let stageValue = stage {
        #if DEBUG
        let stageMessage = "⚠️ Invalid stage '\(stageValue)' for Listing \(id), defaulting to .pending"
        Task { @MainActor in
          debugLog.log(stageMessage, category: .sync)
        }
        #endif
      }
      resolvedStage = .pending
    }

    let listing = Listing(
      id: id,
      address: address,
      city: city ?? "",
      province: province ?? "",
      postalCode: postalCode ?? "",
      country: country ?? "Canada",
      price: price.map { Decimal($0) },
      mlsNumber: mlsNumber,
      listingType: resolvedListingType,
      status: resolvedStatus,
      stage: resolvedStage,
      ownedBy: ownedBy,
      createdVia: resolvedCreatedVia,
      sourceSlackMessages: sourceSlackMessages,
      dueDate: dueDate,
      createdAt: createdAt,
      updatedAt: updatedAt
    )

    // Set propertyId (relationship reconciled later in sync)
    listing.propertyId = propertyId

    return listing
  }
}
