//
//  DispatchCommands.swift
//  Dispatch
//
//  Created for Dispatch Architecture Unification
//

import SwiftUI

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
        dispatch(.toggleSidebar)
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
