//
//  ListingSyncHandler.swift
//  Dispatch
//
//  Handles all Listing and ListingTypeDefinition sync operations.
//  Extracted from EntitySyncHandler for maintainability.
//

import Foundation
import Supabase
import SwiftData

// MARK: - ListingSyncHandler

/// Handles Listing and ListingTypeDefinition entity sync operations.
@MainActor
final class ListingSyncHandler: EntitySyncHandlerProtocol {

  // MARK: Lifecycle

  init(dependencies: SyncHandlerDependencies) {
    self.dependencies = dependencies
  }

  // MARK: Internal

  // MARK: - UserDefaults Keys

  static let lastSyncListingTypesKey = "dispatch.lastSyncListingTypes"

  let dependencies: SyncHandlerDependencies

  // MARK: - SyncDown Listings

  func syncDown(context: ModelContext, since: String) async throws {
    try await syncDownListings(context: context, since: since, establishOwnerRelationship: nil)
  }

  func syncDownListings(
    context: ModelContext,
    since: String,
    establishOwnerRelationship: ((Listing, UUID, ModelContext) throws -> Void)?
  ) async throws {
    debugLog.log("syncDownListings() - querying Supabase...", category: .sync)
    let dtos: [ListingDTO] = try await supabase
      .from("listings")
      .select()
      .gt("updated_at", value: since)
      .execute()
      .value

    debugLog.logSyncOperation(operation: "FETCH", table: "listings", count: dtos.count)

    for (index, dto) in dtos.enumerated() {
      debugLog.log("  Upserting listing \(index + 1)/\(dtos.count): \(dto.id) - \(dto.address)", category: .sync)
      try upsertListing(dto: dto, context: context, establishOwnerRelationship: establishOwnerRelationship)
    }
  }

  // MARK: - SyncUp Listings

  func syncUp(context: ModelContext) async throws {
    let descriptor = FetchDescriptor<Listing>()
    let allListings = try context.fetch(descriptor)
    debugLog.log("syncUpListings() - fetched \(allListings.count) total listings from SwiftData", category: .sync)

    let pendingListings = allListings.filter { $0.syncState == .pending || $0.syncState == .failed }
    debugLog.logSyncOperation(
      operation: "PENDING",
      table: "listings",
      count: pendingListings.count,
      details: "of \(allListings.count) total"
    )

    guard !pendingListings.isEmpty else {
      debugLog.log("  No pending listings to sync", category: .sync)
      return
    }

    // Mark as in-flight before upsert to prevent realtime echo from overwriting local state
    dependencies.conflictResolver.markListingsInFlight(Set(pendingListings.map { $0.id }))
    defer { dependencies.conflictResolver.clearListingsInFlight() } // Always clear, even on error

    // Try batch first for efficiency
    do {
      let dtos = pendingListings.map { ListingDTO(from: $0) }
      debugLog.log("  Batch upserting \(dtos.count) listings to Supabase...", category: .sync)
      try await supabase
        .from("listings")
        .upsert(dtos)
        .execute()
      debugLog.log("  Batch upsert successful", category: .sync)

      for listing in pendingListings {
        listing.markSynced()
      }
      debugLog.log("  Marked \(pendingListings.count) listings as synced", category: .sync)
    } catch {
      // Batch failed - try individual items to isolate failures
      debugLog.log("Batch listing sync failed, trying individually: \(error.localizedDescription)", category: .error)

      for listing in pendingListings {
        do {
          let dto = ListingDTO(from: listing)
          try await supabase
            .from("listings")
            .upsert([dto])
            .execute()
          listing.markSynced()
          debugLog.log("  Listing \(listing.id) synced individually", category: .sync)
        } catch {
          let message = dependencies.userFacingMessage(for: error)
          listing.markFailed(message)
          debugLog.error("  Listing \(listing.id) sync failed: \(message)")
        }
      }
    }
  }

  // MARK: - Upsert Listing

  /// Upsert a listing from remote DTO. Relationship establishment delegated to coordinator.
  func upsertListing(
    dto: ListingDTO,
    context: ModelContext,
    establishOwnerRelationship: ((Listing, UUID, ModelContext) throws -> Void)? = nil
  ) throws {
    let targetId = dto.id
    let descriptor = FetchDescriptor<Listing>(
      predicate: #Predicate { $0.id == targetId }
    )

    if let existing = try context.fetch(descriptor).first {
      // Local-first: skip ALL updates if local-authoritative
      if
        dependencies.conflictResolver.isLocalAuthoritative(
          existing,
          inFlight: dependencies.conflictResolver.isListingInFlight(existing.id)
        )
      {
        debugLog.log(
          "[SyncDown] Skip update for listing \(dto.id) - local-authoritative (state=\(existing.syncState))",
          category: .sync
        )
        return
      }

      debugLog.log("    UPDATE existing listing: \(dto.id)", category: .sync)
      existing.address = dto.address
      existing.city = dto.city ?? ""
      existing.province = dto.province ?? ""
      existing.postalCode = dto.postalCode ?? ""
      existing.country = dto.country ?? "Canada"
      existing.price = dto.price.map { Decimal($0) }
      existing.mlsNumber = dto.mlsNumber
      existing.realDirt = dto.realDirt
      existing.listingType = ListingType(rawValue: dto.listingType) ?? .sale
      existing.status = ListingStatus(rawValue: dto.status) ?? .draft
      if let stageValue = dto.stage, let resolvedStage = ListingStage(rawValue: stageValue) {
        existing.stage = resolvedStage
      } else {
        existing.stage = .pending
      }
      existing.propertyId = dto.propertyId
      existing.typeDefinitionId = dto.listingTypeId
      existing.activatedAt = dto.activatedAt
      existing.pendingAt = dto.pendingAt
      existing.closedAt = dto.closedAt
      existing.deletedAt = dto.deletedAt
      existing.dueDate = dto.dueDate
      existing.updatedAt = dto.updatedAt

      // Link Owner Relationship (via coordinator callback)
      if let establishOwner = establishOwnerRelationship {
        try establishOwner(existing, dto.ownedBy, context)
      }

      existing.markSynced()
    } else {
      debugLog.log("    INSERT new listing: \(dto.id)", category: .sync)
      let newListing = dto.toModel()
      newListing.markSynced()
      context.insert(newListing)

      // Link Owner Relationship (via coordinator callback)
      if let establishOwner = establishOwnerRelationship {
        try establishOwner(newListing, dto.ownedBy, context)
      }
    }
  }

  // MARK: - Delete Listing

  func deleteLocalListing(id: UUID, context: ModelContext) throws -> Bool {
    let descriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == id })
    guard let listing = try context.fetch(descriptor).first else {
      debugLog.log("deleteLocalListing: Listing \(id) not found locally", category: .sync)
      return false
    }
    debugLog.log("deleteLocalListing: Deleting listing \(id) - \(listing.address)", category: .sync)
    context.delete(listing)
    return true
  }

  // MARK: - Reconcile Missing Listings

  /// Reconciles missing listings - finds listings on server that don't exist locally and fetches them.
  /// This is a failsafe to catch listings that were missed due to watermark issues or other sync gaps.
  /// Runs on every sync to ensure data consistency.
  func reconcileMissingListings(context: ModelContext) async throws -> Int {
    // 1. Fetch all listing IDs from server (lightweight query)
    let remoteDTOs: [IDOnlyDTO] = try await supabase
      .from("listings")
      .select("id")
      .execute()
      .value
    let remoteIds = Set(remoteDTOs.map { $0.id })
    debugLog.log("  Remote listings: \(remoteIds.count)", category: .sync)

    // 2. Get all local listing IDs
    let localDescriptor = FetchDescriptor<Listing>()
    let localListings = try context.fetch(localDescriptor)
    let localIds = Set(localListings.map { $0.id })
    debugLog.log("  Local listings: \(localIds.count)", category: .sync)

    // 3. Find IDs that exist on server but not locally
    let missingIds = remoteIds.subtracting(localIds)

    guard !missingIds.isEmpty else {
      debugLog.log("  No missing listings", category: .sync)
      return 0
    }

    debugLog.log("  Warning: Found \(missingIds.count) missing listings, fetching...", category: .sync)

    // 4. Fetch full listing data for missing IDs (batch query)
    let missingDTOs: [ListingDTO] = try await supabase
      .from("listings")
      .select()
      .in("id", values: Array(missingIds).map { $0.uuidString })
      .execute()
      .value

    // 5. Upsert missing listings
    for dto in missingDTOs {
      try upsertListing(dto: dto, context: context, establishOwnerRelationship: nil)
    }

    debugLog.log("  Reconciled \(missingDTOs.count) missing listings", category: .sync)
    return missingDTOs.count
  }

  // MARK: - SyncDown ListingTypes

  func syncDownListingTypes(context: ModelContext) async throws {
    // Per-table watermark with 2s overlap window
    let lastSync = (
      dependencies.mode == .live
        ? UserDefaults.standard.object(forKey: Self.lastSyncListingTypesKey) as? Date
        : nil
    ) ?? Date.distantPast
    let safeDate = lastSync.addingTimeInterval(-2) // Overlap window
    let safeISO = ISO8601DateFormatter().string(from: safeDate)
    debugLog.log("syncDownListingTypes() - fetching records updated since: \(safeISO)", category: .sync)

    let dtos: [ListingTypeDefinitionDTO] = try await supabase
      .from("listing_types")
      .select()
      .gte("updated_at", value: safeISO)
      .execute()
      .value
    debugLog.logSyncOperation(operation: "FETCH", table: "listing_types", count: dtos.count)

    for dto in dtos {
      let descriptor = FetchDescriptor<ListingTypeDefinition>(predicate: #Predicate { $0.id == dto.id })
      let existing = try context.fetch(descriptor).first

      // Pending/failed protection: don't overwrite local changes
      if let existing, existing.syncState == .pending || existing.syncState == .failed {
        debugLog.log("    SKIP (pending/failed): \(dto.id)", category: .sync)
        continue
      }

      if let existing {
        // UPDATE
        debugLog.log("    UPDATE: \(dto.id) - \(dto.name)", category: .sync)
        existing.name = dto.name
        existing.position = dto.position
        existing.isArchived = dto.isArchived
        existing.ownedBy = dto.ownedBy
        existing.updatedAt = dto.updatedAt
        existing.markSynced()
      } else {
        // INSERT
        debugLog.log("    INSERT: \(dto.id) - \(dto.name)", category: .sync)
        let newType = dto.toModel()
        newType.markSynced()
        context.insert(newType)
      }
    }

    // Update per-table watermark (only on success, only in live mode)
    if dependencies.mode == .live {
      UserDefaults.standard.set(Date(), forKey: Self.lastSyncListingTypesKey)
    }

    // Update isListingConfigReady flag
    let allTypesDescriptor = FetchDescriptor<ListingTypeDefinition>(predicate: #Predicate { !$0.isArchived })
    let typesCount = try context.fetch(allTypesDescriptor).count
    dependencies.updateListingConfigReady(typesCount > 0)
    debugLog.log("isListingConfigReady = \(typesCount > 0) (\(typesCount) active types)", category: .sync)
  }

  // MARK: - SyncUp ListingTypes

  func syncUpListingTypes(context: ModelContext) async throws {
    let descriptor = FetchDescriptor<ListingTypeDefinition>()
    let allTypes = try context.fetch(descriptor)
    debugLog.log("syncUpListingTypes() - fetched \(allTypes.count) total", category: .sync)

    let pendingTypes = allTypes.filter { $0.syncState == .pending || $0.syncState == .failed }
    debugLog.logSyncOperation(
      operation: "PENDING",
      table: "listing_types",
      count: pendingTypes.count,
      details: "of \(allTypes.count) total"
    )

    guard !pendingTypes.isEmpty else {
      debugLog.log("  No pending listing types to sync", category: .sync)
      return
    }

    // Batch upsert first
    do {
      let dtos = pendingTypes.map { ListingTypeDefinitionDTO(from: $0) }
      debugLog.log("  Batch upserting \(dtos.count) listing types...", category: .sync)
      try await supabase
        .from("listing_types")
        .upsert(dtos)
        .execute()
      debugLog.log("  Batch upsert successful", category: .sync)

      for type in pendingTypes {
        type.markSynced()
      }
    } catch {
      // Individual fallback
      debugLog.log("Batch listing type sync failed, trying individually: \(error.localizedDescription)", category: .error)

      for type in pendingTypes {
        do {
          let dto = ListingTypeDefinitionDTO(from: type)
          try await supabase
            .from("listing_types")
            .upsert([dto])
            .execute()
          type.markSynced()
          debugLog.log("  ListingType \(type.id) synced", category: .sync)
        } catch {
          let message = dependencies.userFacingMessage(for: error)
          type.markFailed(message)
          debugLog.error("  ListingType \(type.id) sync failed: \(message)")
        }
      }
    }
  }

  // MARK: Private

  /// Lightweight DTO for fetching only IDs from Supabase
  private struct IDOnlyDTO: Codable {
    let id: UUID
  }
}
