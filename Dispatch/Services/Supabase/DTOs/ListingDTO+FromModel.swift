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
        self.id = model.id
        self.address = model.address
        self.city = model.city.isEmpty ? nil : model.city
        self.province = model.province.isEmpty ? nil : model.province
        self.postalCode = model.postalCode.isEmpty ? nil : model.postalCode
        self.country = model.country.isEmpty ? nil : model.country
        // Convert Decimal to Double for Supabase
        self.price = model.price.map { NSDecimalNumber(decimal: $0).doubleValue }
        self.mlsNumber = model.mlsNumber
        self.listingType = model.listingType.rawValue
        self.status = model.status.rawValue
        self.ownedBy = model.ownedBy
        self.assignedStaff = model.assignedStaff
        self.createdVia = model.createdVia.rawValue
        self.sourceSlackMessages = model.sourceSlackMessages
        self.activatedAt = model.activatedAt
        self.pendingAt = model.pendingAt
        self.closedAt = model.closedAt
        self.deletedAt = model.deletedAt
        self.createdAt = model.createdAt
        self.updatedAt = model.updatedAt
    }
}
