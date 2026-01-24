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
      .gte("updated_at", value: since)
      .execute()
      .value

    debugLog.logSyncOperation(operation: "FETCH", table: "properties", count: dtos.count)

    for (index, dto) in dtos.enumerated() {
      debugLog.log("  Upserting property \(index + 1)/\(dtos.count): \(dto.id) - \(dto.address)", category: .sync)
      try upsertProperty(dto: dto, context: context)
    }
  }

  // MARK: - SyncUp

  /// Syncs properties using explicit DELETE + INSERT to ensure proper audit logging.
  ///
  /// The audit system only captures INSERT and DELETE events, not UPDATE events.
  /// Using UPSERT would trigger UPDATE when modifying a property, which wouldn't
  /// appear in the audit history. This method ensures:
  /// - Property creation generates an INSERT audit event
  /// - Property modification generates DELETE + INSERT audit events
  /// - Soft-deleted properties (deletedAt set) are synced but remain in database
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

    let pendingPropertyIds = pendingProperties.map { $0.id }

    // Fetch server-side properties to determine which ones already exist
    let serverProperties: [PropertyDTO] = try await supabase
      .from("properties")
      .select()
      .in("id", values: pendingPropertyIds.map { $0.uuidString })
      .execute()
      .value

    let serverPropertyIds = Set(serverProperties.map { $0.id })
    debugLog.log(
      "  Local pending: \(pendingProperties.count), Already on server: \(serverPropertyIds.count)",
      category: .sync
    )

    // Mark properties as in-flight to prevent realtime echo
    dependencies.conflictResolver.markPropertiesInFlight(Set(pendingPropertyIds))
    defer { dependencies.conflictResolver.clearPropertiesInFlight() }

    // Process each pending property with DELETE + INSERT
    for property in pendingProperties {
      let dto = PropertyDTO(from: property)

      do {
        // Delete if exists on server (to trigger DELETE audit event)
        if serverPropertyIds.contains(property.id) {
          try await supabase
            .from("properties")
            .delete()
            .eq("id", value: property.id.uuidString)
            .execute()
          debugLog.log("    Deleted existing property \(property.id) for re-insert", category: .sync)
        }

        // Insert the property (generates INSERT audit event)
        // Discard result to prevent type inference causing decode errors
        _ = try await supabase
          .from("properties")
          .insert(dto)
          .execute()
        property.markSynced()
        debugLog.log("    Inserted property \(property.id)", category: .sync)
      } catch {
        let message = dependencies.userFacingMessage(for: error)
        property.markFailed(message)
        debugLog.error("    Property \(property.id) sync failed: \(message)")
      }
    }

    debugLog.log("syncUpProperties() complete", category: .sync)
  }

  // MARK: - Upsert

  func upsertProperty(dto: PropertyDTO, context: ModelContext) throws {
    let targetId = dto.id
    let descriptor = FetchDescriptor<Property>(
      predicate: #Predicate { $0.id == targetId }
    )

    if let existing = try context.fetch(descriptor).first {
      // Local-first: skip updates if local-authoritative (timestamp-aware)
      if
        dependencies.conflictResolver.isLocalAuthoritative(
          existing,
          localUpdatedAt: existing.updatedAt,
          remoteUpdatedAt: dto.updatedAt,
          inFlight: dependencies.conflictResolver.isPropertyInFlight(existing.id)
        )
      {
        debugLog.log(
          "[SyncDown] Skip update for property \(dto.id) - local-authoritative (state=\(existing.syncState), local=\(existing.updatedAt), remote=\(dto.updatedAt))",
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
