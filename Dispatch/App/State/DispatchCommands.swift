//
//  DispatchCommands.swift
//  Dispatch
//
//  Created for Dispatch Architecture Unification
//

import SwiftUI

// MARK: - ColumnVisibilityKey

/// FocusedValueKey for NavigationSplitView column visibility binding.
/// Enables menu commands to toggle the sidebar of the focused window.
private struct ColumnVisibilityKey: FocusedValueKey {
  typealias Value = Binding<NavigationSplitViewVisibility>
}

// MARK: - FocusedValues

extension FocusedValues {
  /// Column visibility binding from the focused NavigationSplitView.
  /// Used by DispatchCommands to toggle sidebar via Cmd+/ shortcut.
  var columnVisibility: Binding<NavigationSplitViewVisibility>? {
    get { self[ColumnVisibilityKey.self] }
    set { self[ColumnVisibilityKey.self] = newValue }
  }
}

// MARK: - DispatchCommands

/// Native macOS Menu Bar Commands.
/// Bridges system menu actions to AppState commands.
struct DispatchCommands: Commands {
  // In SwiftUI Commands, EnvironmentObject usually works if the CommandGroup is
  // inside a WindowGroup or if the context is passed down.
  // However, top-level .commands modifier on Scene sometimes has trouble reading EnvironmentObject
  // from the App struct itself.
  // The robust pattern is to rely on the AppState passed/captured if possible,
  // or use a dedicated transparent plumbing if Environment fails at Scene level.
  //
  // "Jobs Standard": We try the clean way first.

  // NOTE: Swift 6 / SwiftUI has limitations injecting EnvObj into Commands builder.
  // A common workaround is "FocusBinding" or capturing a reference if the App holds it.
  // Since DispatchApp holds the StateObject, we can pass a closure or binding,
  // OR we can make this struct take the actions directly.

  @Environment(\.openWindow) private var openWindow

  /// Focused column visibility binding from the active NavigationSplitView window.
  /// Enables per-window sidebar toggle via Cmd+/ shortcut.
  @FocusedValue(\.columnVisibility) private var columnVisibility

  var dispatch: (AppCommand) -> Void

  var body: some Commands {
    // Replace the default .newItem group to take over Cmd+N from WindowGroup's "New Window"
    CommandGroup(replacing: .newItem) {
      // New Window: Cmd+Shift+N (was Cmd+N by default, causing conflict)
      Button("New Window") {
        openWindow(id: "main")
      }
      .keyboardShortcut("n", modifiers: [.command, .shift])

      // New Item: Cmd+N (our primary action for creating tasks)
      Button("New Item") {
        dispatch(.newItem)
      }
      .keyboardShortcut("n", modifiers: .command)

      Divider()

      Button("Search") {
        // Post notification for per-window handling (WindowUIState)
        NotificationCenter.default.post(name: .openSearch, object: nil)
      }
      .keyboardShortcut("f", modifiers: .command)

      Divider()

      Button("My Workspace") {
        dispatch(.userSelectedDestination(.tab(.workspace)))
      }
      .keyboardShortcut("1", modifiers: .command)
    }

    CommandGroup(after: .toolbar) {
      Button("Sync Now") {
        dispatch(.syncNow)
      }
      .keyboardShortcut("r", modifiers: .command)
    }

    CommandGroup(after: .sidebar) {
      Button("Toggle Sidebar") {
        // Use FocusedValue for per-window sidebar toggle
        // Falls back to AppState dispatch if no focused window
        if let visibility = columnVisibility {
          withAnimation {
            visibility.wrappedValue = visibility.wrappedValue == .all ? .detailOnly : .all
          }
        } else {
          dispatch(.toggleSidebar)
        }
      }
      .keyboardShortcut("/", modifiers: .command)
    }

    // Navigation menu - keyboard shortcuts for macOS navigation
    CommandMenu("Navigate") {
      Button("Back") {
        dispatch(.popNavigation)
      }
      .keyboardShortcut(.escape, modifiers: [])
    }
  }
}
