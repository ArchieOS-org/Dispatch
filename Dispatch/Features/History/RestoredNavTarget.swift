//
//  RestoredNavTarget.swift
//  Dispatch
//
//  Navigation target for navigating to a restored entity.
//  Uses struct instead of tuple to conform to Identifiable and Hashable.
//

import Foundation

// MARK: - RestoredNavTarget

struct RestoredNavTarget: Identifiable, Hashable {
  let type: AuditableEntity
  let entityId: UUID

  // MARK: Identifiable

  var id: UUID { entityId }
}
