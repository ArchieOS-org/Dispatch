//
//  QuickEntryState.swift
//  Dispatch
//
//  Global state for quick entry sheet presentation
//

import Combine
import SwiftUI

/// Observable state for the quick entry sheet.
/// Manages presentation and default entry type for the FAB action.
@MainActor
final class QuickEntryState: ObservableObject {
    /// Whether the quick entry sheet is presented
    @Published var isPresenting: Bool = false

    /// The default item type to show when the sheet opens
    var defaultItemType: QuickEntryItemType = .task
}
