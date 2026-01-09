//
//  PreviewShell.swift
//  Dispatch
//
//  Canonical "One Boss" Shell for Previews.
//  Enforces strict dependency injection, network isolation, and stable initialization.
//

import Combine
import SwiftData
import SwiftUI

// MARK: - PreviewContext

/// Holds the lifecycle of all preview dependencies to ensure they are created exactly once
/// and persist across view identity changes (e.g. during live edits).
@MainActor
final class PreviewContext: ObservableObject {

  // MARK: Lifecycle

  init(
    setup: (ModelContext) -> Void,
    appState: AppState,
    syncManager: SyncManager,
    lensState: LensState,
    overlayState: AppOverlayState
  ) {
    self.appState = appState
    self.syncManager = syncManager
    self.lensState = lensState
    self.overlayState = overlayState

    // InMemory Container with Full Schema
    let schema = Schema([
      User.self,
      Listing.self,
      TaskItem.self,
      Activity.self,
      Note.self,
      ClaimEvent.self,
      ListingTypeDefinition.self,
      ActivityTemplate.self
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    do {
      container = try ModelContainer(for: schema, configurations: [config])
    } catch {
      fatalError("Failed to create Preview Container: \(error)")
    }

    // Seed Once. Assumes fresh in-memory container.
    setup(container.mainContext)
  }

  // MARK: Internal

  /// Satisfy ObservableObject requirement since we wrap other ObservableObjects manually
  let objectWillChange = Combine.ObservableObjectPublisher()

  let appState: AppState
  let syncManager: SyncManager
  let lensState: LensState
  let overlayState: AppOverlayState
  let container: ModelContainer

}

// MARK: - PreviewShell

/// A wrapper view that injects all required Environment Objects for Dispatch screens.
/// Guarantees:
/// 1. Stability: Dependencies are not recreated on redraw.
/// 2. Isolation: Network and Side Effects are disabled.
/// 3. Completeness: All Global Environment Objects are present.
struct PreviewShell<Content: View>: View {

  // MARK: Lifecycle

  @MainActor
  init(
    withNavigation: Bool = true,
    appState: AppState? = nil,
    syncManager: SyncManager? = nil,
    lensState: LensState? = nil,
    overlayState: AppOverlayState? = nil,
    setup: @escaping (ModelContext) -> Void = { _ in },
    @ViewBuilder content: @escaping (ModelContext) -> Content
  ) {
    self.withNavigation = withNavigation
    self.content = content

    // Initialize StateObject with wrappedValue to take ownership of passed dependencies
    // logic: Use passed instance OR create new Preview instance
    _context = StateObject(wrappedValue: PreviewContext(
      setup: setup,
      appState: appState ?? AppState(mode: .preview),
      syncManager: syncManager ?? SyncManager(mode: .preview),
      lensState: lensState ?? LensState(),
      overlayState: overlayState ?? AppOverlayState(mode: .preview)
    ))
  }

  // MARK: Internal

  let withNavigation: Bool

  var body: some View {
    Group {
      if withNavigation {
        NavigationStack {
          content(context.container.mainContext)
        }
      } else {
        content(context.container.mainContext)
      }
    }
    .modelContainer(context.container)
    .environmentObject(context.appState)
    .environmentObject(context.syncManager)
    .environmentObject(context.lensState)
    .environmentObject(context.overlayState)
  }

  // MARK: Private

  /// Stable Context Storage
  @StateObject private var context: PreviewContext

  private let content: (ModelContext) -> Content

}
