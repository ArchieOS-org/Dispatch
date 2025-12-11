//
//  Listing.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation
import SwiftData

@Model
final class Listing: NotableProtocol {
    @Attribute(.unique) var id: UUID
    var address: String
    var city: String
    var province: String
    var postalCode: String
    var country: String
    var price: Decimal?
    var mlsNumber: String?
    var listingType: ListingType
    var status: ListingStatus

    // Foreign keys
    var ownedBy: UUID

    // Metadata
    var createdVia: CreationSource
    var sourceSlackMessages: [String]?

    // Timestamps
    var activatedAt: Date?
    var pendingAt: Date?
    var closedAt: Date?
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var syncedAt: Date?

    // Relationships
    @Relationship(deleteRule: .cascade)
    var tasks: [TaskItem] = []

    @Relationship(deleteRule: .cascade)
    var activities: [Activity] = []

    @Relationship(deleteRule: .cascade)
    var notes: [Note] = []

    @Relationship(deleteRule: .cascade)
    var statusHistory: [StatusChange] = []

    // Inverse relationships
    var owner: User?

    init(
        id: UUID = UUID(),
        address: String,
        city: String = "",
        province: String = "",
        postalCode: String = "",
        country: String = "Canada",
        price: Decimal? = nil,
        mlsNumber: String? = nil,
        listingType: ListingType = .sale,
        status: ListingStatus = .draft,
        ownedBy: UUID,
        createdVia: CreationSource = .dispatch,
        sourceSlackMessages: [String]? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.address = address
        self.city = city
        self.province = province
        self.postalCode = postalCode
        self.country = country
        self.price = price
        self.mlsNumber = mlsNumber
        self.listingType = listingType
        self.status = status
        self.ownedBy = ownedBy
        self.createdVia = createdVia
        self.sourceSlackMessages = sourceSlackMessages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - RealtimeSyncable Conformance
extension Listing: RealtimeSyncable {
    var isDirty: Bool {
        guard let syncedAt = syncedAt else { return true }
        return updatedAt > syncedAt
    }
    // conflictResolution uses default from protocol extension (.lastWriteWins)
}
