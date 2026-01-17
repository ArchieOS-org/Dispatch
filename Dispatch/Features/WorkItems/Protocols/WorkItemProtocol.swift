//
//  WorkItemProtocol.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

protocol WorkItemProtocol {
  var id: UUID { get }
  var title: String { get set }
  var dueDate: Date? { get set }
  var declaredBy: UUID { get }
  var assigneeUserIds: [UUID] { get }
  var listingId: UUID? { get set }
  var notes: [Note] { get }
  var subtasks: [Subtask] { get }
  var statusHistory: [StatusChange] { get }
  var createdVia: CreationSource { get }
  var createdAt: Date { get }
  var updatedAt: Date { get set }
  var syncedAt: Date? { get set }
}
