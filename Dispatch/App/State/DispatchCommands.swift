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

  var dispatch: (AppCommand) -> Void

  var body: some Commands {
    CommandGroup(after: .newItem) {
      Button("New Item") {
        dispatch(.newItem)
      }
      .keyboardShortcut("n", modifiers: .command)

      Button("Search") {
        dispatch(.openSearch())
      }
      .keyboardShortcut("f", modifiers: .command)

      Divider()

      Button("My Tasks") {
        dispatch(.filterMine)
      }
      .keyboardShortcut("1", modifiers: .command)

      Button("Others' Tasks") {
        dispatch(.filterOthers)
      }
      .keyboardShortcut("2", modifiers: .command)

      Button("Unclaimed") {
        dispatch(.filterUnclaimed)
      }
      .keyboardShortcut("3", modifiers: .command)
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
  }
}
