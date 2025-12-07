//
//  ListingDTO.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

struct ListingDTO: Codable, Sendable {
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
    let ownedBy: UUID
    let assignedStaff: UUID?
    let createdVia: String
    let sourceSlackMessages: [String]?
    let activatedAt: Date?
    let pendingAt: Date?
    let closedAt: Date?
    let deletedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, address, city, province, country, price, status
        case postalCode = "postal_code"
        case mlsNumber = "mls_number"
        case listingType = "listing_type"
        case ownedBy = "owned_by"
        case assignedStaff = "assigned_staff"
        case createdVia = "created_via"
        case sourceSlackMessages = "source_slack_messages"
        case activatedAt = "activated_at"
        case pendingAt = "pending_at"
        case closedAt = "closed_at"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func toModel() -> Listing {
        Listing(
            id: id,
            address: address,
            city: city ?? "",
            province: province ?? "",
            postalCode: postalCode ?? "",
            country: country ?? "Canada",
            price: price.map { Decimal($0) },
            mlsNumber: mlsNumber,
            listingType: ListingType(rawValue: listingType) ?? .sale,
            status: ListingStatus(rawValue: status) ?? .draft,
            ownedBy: ownedBy,
            assignedStaff: assignedStaff,
            createdVia: CreationSource(rawValue: createdVia) ?? .dispatch,
            sourceSlackMessages: sourceSlackMessages,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
