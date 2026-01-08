//
//  OverflowMenu.swift
//  Dispatch
//
//  Shared Component - Reusable overflow menu with configurable actions
//

import SwiftUI

/// A reusable overflow menu button displaying an ellipsis icon.
/// Tapping reveals a menu of actions. Supports normal and destructive actions.
///
/// Usage:
/// ```swift
/// OverflowMenu(actions: [
///     OverflowMenu.Action(id: "edit", title: "Edit", icon: "pencil") { editItem() },
///     OverflowMenu.Action(id: "delete", title: "Delete", icon: "trash", role: .destructive) { deleteItem() }
/// ])
/// ```
struct OverflowMenu: View {

  // MARK: Internal

  /// Represents a single action in an overflow menu.
  struct Action: Identifiable {

    // MARK: Lifecycle

    /// Initializer for non-destructive actions
    init(id: String, title: String, icon: String, action: @escaping () -> Void) {
      self.id = id
      self.title = title
      self.icon = icon
      role = nil
      self.action = action
    }

    /// Initializer with explicit role (for destructive actions)
    init(id: String, title: String, icon: String, role: ButtonRole?, action: @escaping () -> Void) {
      self.id = id
      self.title = title
      self.icon = icon
      self.role = role
      self.action = action
    }

    // MARK: Internal

    let id: String
    let title: String
    let icon: String
    let role: ButtonRole?
    let action: () -> Void

  }

  let actions: [Action]
  var icon = "ellipsis"
  var iconColor = Color.primary
  var accessibilityLabelText = "More actions"

  var body: some View {
    menuLabel
      .contentShape(Rectangle())
      .onTapGesture {
        showingActions = true
      }
      .confirmationDialog("Actions", isPresented: $showingActions, titleVisibility: .hidden) {
        ForEach(actions) { item in
          Button(role: item.role) {
            item.action()
          } label: {
            Label(item.title, systemImage: item.icon)
          }
        }
      }
      .accessibilityLabel(accessibilityLabelText)
  }

  // MARK: Private

  @State private var showingActions = false

  /// Menu label
  private var menuLabel: some View {
    Image(systemName: icon)
      .font(.system(size: 20))
      .foregroundColor(iconColor)
      .frame(
        width: CGFloat(DS.Spacing.minTouchTarget),
        height: CGFloat(DS.Spacing.minTouchTarget),
      )
      .contentShape(Rectangle())
  }
}

// MARK: - Previews

#Preview("Overflow Menu - Standard") {
  VStack(spacing: DS.Spacing.xl) {
    HStack {
      Text("Item Title")
        .font(DS.Typography.headline)
      Spacer()
      OverflowMenu(actions: [
        OverflowMenu.Action(id: "edit", title: "Edit", icon: DS.Icons.Action.edit) { },
        OverflowMenu.Action(id: "share", title: "Share", icon: DS.Icons.Action.share) { },
        OverflowMenu.Action(id: "delete", title: "Delete", icon: DS.Icons.Action.delete, role: .destructive) { }
      ])
    }
    .padding()
    .background(DS.Colors.Background.card)
    .cornerRadius(DS.Spacing.radiusCard)
  }
  .padding()
}

#Preview("Overflow Menu - Single Action") {
  HStack {
    Text("Simple Case")
    Spacer()
    OverflowMenu(actions: [
      OverflowMenu.Action(id: "delete", title: "Delete", icon: DS.Icons.Action.delete, role: .destructive) { }
    ])
  }
  .padding()
}
