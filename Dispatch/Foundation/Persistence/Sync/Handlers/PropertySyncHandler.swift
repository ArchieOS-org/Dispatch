//
//  PropertySyncHandler.swift
//  Dispatch
//
//  Handles all Property-specific sync operations: syncDown, syncUp, upsert.
//  Extracted from EntitySyncHandler for maintainability.
//

import Foundation
import Supabase
import SwiftData

// MARK: - PropertySyncHandler

/// Handles Property entity sync operations.
@MainActor
final class PropertySyncHandler: EntitySyncHandlerProtocol {

  // MARK: Lifecycle

  init(dependencies: SyncHandlerDependencies) {
    self.dependencies = dependencies
  }

  // MARK: Internal

  let dependencies: SyncHandlerDependencies

  // MARK: - SyncDown

  func syncDown(context: ModelContext, since: String) async throws {
    debugLog.log("syncDownProperties() - querying Supabase...", category: .sync)
    let dtos: [PropertyDTO] = try await supabase
      .from("properties")
      .select()
      .gt("updated_at", value: since)
      .execute()
      .value

    debugLog.logSyncOperation(operation: "FETCH", table: "properties", count: dtos.count)

    for (index, dto) in dtos.enumerated() {
      debugLog.log("  Upserting property \(index + 1)/\(dtos.count): \(dto.id) - \(dto.address)", category: .sync)
      try upsertProperty(dto: dto, context: context)
    }
  }

  // MARK: - SyncUp

  func syncUp(context: ModelContext) async throws {
    let descriptor = FetchDescriptor<Property>()
    let allProperties = try context.fetch(descriptor)
    debugLog.log("syncUpProperties() - fetched \(allProperties.count) total properties from SwiftData", category: .sync)

    let pendingProperties = allProperties.filter { $0.syncState == .pending || $0.syncState == .failed }
    debugLog.logSyncOperation(
      operation: "PENDING",
      table: "properties",
      count: pendingProperties.count,
      details: "of \(allProperties.count) total"
    )

    guard !pendingProperties.isEmpty else {
      debugLog.log("  No pending properties to sync", category: .sync)
      return
    }

    // Try batch first for efficiency
    do {
      let dtos = pendingProperties.map { PropertyDTO(from: $0) }
      debugLog.log("  Batch upserting \(dtos.count) properties to Supabase...", category: .sync)
      try await supabase
        .from("properties")
        .upsert(dtos)
        .execute()
      debugLog.log("  Batch upsert successful", category: .sync)

      for property in pendingProperties {
        property.markSynced()
      }
      debugLog.log("  Marked \(pendingProperties.count) properties as synced", category: .sync)
    } catch {
      // Batch failed - try individual items to isolate failures
      debugLog.log("Batch property sync failed, trying individually: \(error.localizedDescription)", category: .error)

      for property in pendingProperties {
        do {
          let dto = PropertyDTO(from: property)
          try await supabase
            .from("properties")
            .upsert([dto])
            .execute()
          property.markSynced()
          debugLog.log("  Property \(property.id) synced individually", category: .sync)
        } catch {
          let message = dependencies.userFacingMessage(for: error)
          property.markFailed(message)
          debugLog.error("  Property \(property.id) sync failed: \(message)")
        }
      }
    }
  }

  // MARK: - Upsert

  func upsertProperty(dto: PropertyDTO, context: ModelContext) throws {
    let targetId = dto.id
    let descriptor = FetchDescriptor<Property>(
      predicate: #Predicate { $0.id == targetId }
    )

    if let existing = try context.fetch(descriptor).first {
      // Local-first: skip ALL updates if local-authoritative
      if dependencies.conflictResolver.isLocalAuthoritative(existing, inFlight: false) {
        debugLog.log(
          "[SyncDown] Skip update for property \(dto.id) - local-authoritative (state=\(existing.syncState))",
          category: .sync
        )
        return
      }

      debugLog.log("    UPDATE existing property: \(dto.id)", category: .sync)
      existing.address = dto.address
      existing.unit = dto.unit
      existing.city = dto.city ?? ""
      existing.province = dto.province ?? ""
      existing.postalCode = dto.postalCode ?? ""
      existing.country = dto.country ?? "Canada"
      existing.propertyType = PropertyType(rawValue: dto.propertyType) ?? .residential
      existing.deletedAt = dto.deletedAt
      existing.updatedAt = dto.updatedAt

      existing.markSynced()
    } else {
      debugLog.log("    INSERT new property: \(dto.id)", category: .sync)
      let newProperty = dto.toModel()
      newProperty.markSynced()
      context.insert(newProperty)
    }
  }
}
