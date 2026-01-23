//
//  ListingDTO+FromModel.swift
//  Dispatch
//
//  Created for Phase 1.3: SyncManager Service
//

import Foundation

extension ListingDTO {
  /// Initialize from SwiftData model for syncUp operations
  init(from model: Listing) {
    id = model.id
    address = model.address
    city = model.city.isEmpty ? nil : model.city
    province = model.province.isEmpty ? nil : model.province
    postalCode = model.postalCode.isEmpty ? nil : model.postalCode
    country = model.country.isEmpty ? nil : model.country
    // Convert Decimal to Double for Supabase
    price = model.price.map { NSDecimalNumber(decimal: $0).doubleValue }
    mlsNumber = model.mlsNumber
    realDirt = model.realDirt
    listingType = model.listingType.rawValue
    listingTypeId = model.typeDefinitionId
    status = model.status.rawValue
    stage = model.stage.rawValue
    ownedBy = model.ownedBy
    propertyId = model.propertyId
    createdVia = model.createdVia.rawValue
    sourceSlackMessages = model.sourceSlackMessages
    activatedAt = model.activatedAt
    pendingAt = model.pendingAt
    closedAt = model.closedAt
    deletedAt = model.deletedAt
    dueDate = model.dueDate
    createdAt = model.createdAt
    updatedAt = model.updatedAt
  }
}
