//
//  FABContext.swift
//  Dispatch
//
//  Context-aware FAB behavior - defines what options the FAB presents
//

import SwiftUI

// MARK: - FABContext

/// Defines what options the FAB should present based on current screen context.
///
/// The FAB (Floating Action Button) adapts its available actions based on where
/// the user is in the app. This enum captures the semantic context of the current screen.
enum FABContext: Equatable {
  /// Workspace default - can create Listing, Task, or Activity
  case workspace

  /// Stage view or listing list - create Listing only
  case listingList

  /// Listing detail - create Task or Activity for specific listing
  case listingDetail(listingId: UUID)

  /// Realtor tab - create Property or Listing for realtor
  case realtor(realtorId: UUID)

  /// Properties screen - create Property only
  case properties
}

// MARK: - FABContextKey

private struct FABContextKey: EnvironmentKey {
  static let defaultValue: FABContext = .workspace
}

extension EnvironmentValues {
  var fabContext: FABContext {
    get { self[FABContextKey.self] }
    set { self[FABContextKey.self] = newValue }
  }
}

// MARK: - View Modifier

extension View {
  /// Sets the FAB context for this view and its descendants.
  ///
  /// Use this modifier on container views to inform the FAB what creation
  /// options are appropriate for the current screen.
  ///
  /// ```swift
  /// ListingDetailView(listing: listing)
  ///   .fabContext(.listingDetail(listingId: listing.id))
  /// ```
  func fabContext(_ context: FABContext) -> some View {
    environment(\.fabContext, context)
  }
}
