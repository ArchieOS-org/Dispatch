//
//  DomainDesignBridge.swift
//  Dispatch
//
//  Bridge extensions mapping domain types to design system tokens.
//  Keeps Design layer pure while providing convenient mappings.
//

import SwiftUI

// MARK: - TaskStatus Colors & Icons

extension TaskStatus {
  var color: Color {
    switch self {
    case .open: DS.Colors.Status.open
    case .inProgress: DS.Colors.Status.inProgress
    case .completed: DS.Colors.Status.completed
    case .deleted: DS.Colors.Status.deleted
    }
  }

  var icon: String {
    switch self {
    case .open: DS.Icons.StatusIcons.open
    case .inProgress: DS.Icons.StatusIcons.inProgress
    case .completed: DS.Icons.StatusIcons.completed
    case .deleted: DS.Icons.StatusIcons.deleted
    }
  }
}

// MARK: - ActivityStatus Colors & Icons

extension ActivityStatus {
  var color: Color {
    switch self {
    case .open: DS.Colors.Status.open
    case .inProgress: DS.Colors.Status.inProgress
    case .completed: DS.Colors.Status.completed
    case .deleted: DS.Colors.Status.deleted
    }
  }

  var icon: String {
    switch self {
    case .open: DS.Icons.StatusIcons.open
    case .inProgress: DS.Icons.StatusIcons.inProgress
    case .completed: DS.Icons.StatusIcons.completed
    case .deleted: DS.Icons.StatusIcons.deleted
    }
  }
}

// MARK: - SyncStatus Colors & Icons

extension SyncStatus {
  var color: Color {
    switch self {
    case .idle: DS.Colors.Sync.idle
    case .syncing: DS.Colors.Sync.syncing
    case .ok: DS.Colors.Sync.ok
    case .error: DS.Colors.Sync.error
    }
  }

  var icon: String {
    switch self {
    case .idle: DS.Icons.Sync.idle
    case .syncing: DS.Icons.Sync.syncing
    case .ok: DS.Icons.Sync.ok
    case .error: DS.Icons.Sync.error
    }
  }
}

// MARK: - Role Colors

extension Role {
  var color: Color {
    switch self {
    case .admin: DS.Colors.RoleColors.admin
    case .marketing: DS.Colors.RoleColors.marketing
    }
  }
}

// MARK: - ListingStage Colors & Icons

extension ListingStage {
  var color: Color {
    switch self {
    case .pending: DS.Colors.Stage.pending
    case .workingOn: DS.Colors.Stage.workingOn
    case .live: DS.Colors.Stage.live
    case .sold: DS.Colors.Stage.sold
    case .reList: DS.Colors.Stage.reList
    case .done: DS.Colors.Stage.done
    }
  }

  var icon: String {
    switch self {
    case .pending: DS.Icons.Stage.pending
    case .workingOn: DS.Icons.Stage.workingOn
    case .live: DS.Icons.Stage.live
    case .sold: DS.Icons.Stage.sold
    case .reList: DS.Icons.Stage.reList
    case .done: DS.Icons.Stage.done
    }
  }

  var cardFillColor: Color {
    color.opacity(0.12)
  }
}
