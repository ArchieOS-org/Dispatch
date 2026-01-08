//
//  PropertyDTO.swift
//  Dispatch
//
//  Data transfer object for Property entity
//

import Foundation

// MARK: - PropertyDTO

struct PropertyDTO: Codable, Sendable {
  enum CodingKeys: String, CodingKey {
    case id
    case address
    case unit
    case city
    case province
    case country
    case postalCode = "postal_code"
    case propertyType = "property_type"
    case ownedBy = "owned_by"
    case createdVia = "created_via"
    case deletedAt = "deleted_at"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }

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

  func toModel() -> Property {
    // PropertyType with fallback
    let resolvedPropertyType: PropertyType
    if let pt = PropertyType(rawValue: propertyType) {
      resolvedPropertyType = pt
    } else {
      #if DEBUG
      let propertyTypeMessage = "⚠️ Invalid propertyType '\(propertyType)' for Property \(id), defaulting to .residential"
      Task { @MainActor in
        debugLog.log(propertyTypeMessage, category: .sync)
      }
      #endif
      resolvedPropertyType = .residential
    }

    // CreationSource with fallback
    let resolvedCreatedVia: CreationSource
    if let c = CreationSource(rawValue: createdVia) {
      resolvedCreatedVia = c
    } else {
      #if DEBUG
      let createdViaMessage = "⚠️ Invalid createdVia '\(createdVia)' for Property \(id), defaulting to .dispatch"
      Task { @MainActor in
        debugLog.log(createdViaMessage, category: .sync)
      }
      #endif
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
      updatedAt: updatedAt,
    )
  }
}

// MARK: - From Model Extension
extension PropertyDTO {
  /// Initialize from SwiftData model for syncUp operations
  init(from model: Property) {
    id = model.id
    address = model.address
    unit = model.unit
    city = model.city.isEmpty ? nil : model.city
    province = model.province.isEmpty ? nil : model.province
    postalCode = model.postalCode.isEmpty ? nil : model.postalCode
    country = model.country.isEmpty ? nil : model.country
    propertyType = model.propertyType.rawValue
    ownedBy = model.ownedBy
    createdVia = model.createdVia.rawValue
    deletedAt = model.deletedAt
    createdAt = model.createdAt
    updatedAt = model.updatedAt
  }
}
