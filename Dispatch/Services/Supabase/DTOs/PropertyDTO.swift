//
//  PropertyDTO.swift
//  Dispatch
//
//  Data transfer object for Property entity
//

import Foundation

struct PropertyDTO: Codable, Sendable {
    let id: UUID
    let address: String
    let unit: String?
    let city: String?
    let province: String?
    let postalCode: String?
    let country: String?
    let propertyType: String
    let ownedBy: UUID
    let createdVia: String
    let deletedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, address, unit, city, province, country
        case postalCode = "postal_code"
        case propertyType = "property_type"
        case ownedBy = "owned_by"
        case createdVia = "created_via"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func toModel() -> Property {
        // PropertyType with fallback
        let resolvedPropertyType: PropertyType
        if let pt = PropertyType(rawValue: propertyType) {
            resolvedPropertyType = pt
        } else {
            debugLog.log("⚠️ Invalid propertyType '\(propertyType)' for Property \(id), defaulting to .residential", category: .sync)
            resolvedPropertyType = .residential
        }

        // CreationSource with fallback
        let resolvedCreatedVia: CreationSource
        if let c = CreationSource(rawValue: createdVia) {
            resolvedCreatedVia = c
        } else {
            debugLog.log("⚠️ Invalid createdVia '\(createdVia)' for Property \(id), defaulting to .dispatch", category: .sync)
            resolvedCreatedVia = .dispatch
        }

        return Property(
            id: id,
            address: address,
            unit: unit,
            city: city ?? "",
            province: province ?? "",
            postalCode: postalCode ?? "",
            country: country ?? "Canada",
            propertyType: resolvedPropertyType,
            ownedBy: ownedBy,
            createdVia: resolvedCreatedVia,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - From Model Extension
extension PropertyDTO {
    /// Initialize from SwiftData model for syncUp operations
    init(from model: Property) {
        self.id = model.id
        self.address = model.address
        self.unit = model.unit
        self.city = model.city.isEmpty ? nil : model.city
        self.province = model.province.isEmpty ? nil : model.province
        self.postalCode = model.postalCode.isEmpty ? nil : model.postalCode
        self.country = model.country.isEmpty ? nil : model.country
        self.propertyType = model.propertyType.rawValue
        self.ownedBy = model.ownedBy
        self.createdVia = model.createdVia.rawValue
        self.deletedAt = model.deletedAt
        self.createdAt = model.createdAt
        self.updatedAt = model.updatedAt
    }
}
