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
    // MARK: - Nested Action Model

    /// Represents a single action in an overflow menu.
    struct Action: Identifiable {
        let id: String
        let title: String
        let icon: String
        let role: ButtonRole?
        let action: () -> Void

        /// Initializer for non-destructive actions
        init(id: String, title: String, icon: String, action: @escaping () -> Void) {
            self.id = id
            self.title = title
            self.icon = icon
            self.role = nil
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
    }

    // MARK: - Properties

    let actions: [Action]
    var icon: String = "ellipsis"
    var iconColor: Color = DS.Colors.accent
    var accessibilityLabelText: String = "More actions"

    /// Optional view filter for displaying ring indicator
    var viewFilter: ViewFilter?

    /// Optional callback for long-press gesture to cycle view filter
    var onLongPress: (() -> Void)?

    /// Optional callback for direct filter selection from menu
    var onFilterSelect: ((ViewFilter) -> Void)?

    // MARK: - Private State

    @State private var showingActions = false

    // MARK: - Private Properties

    /// Icon color based on current view filter (overrides iconColor when filter is active)
    private var effectiveIconColor: Color {
        guard let filter = viewFilter else { return iconColor }
        switch filter {
        case .all:
            return iconColor // Default color in All mode
        case .admin:
            return DS.Colors.RoleColors.admin
        case .marketing:
            return DS.Colors.RoleColors.marketing
        }
    }

    // MARK: - Body

    var body: some View {
        // Long press has priority - if it completes, tap won't fire
        menuLabel
            .contentShape(Rectangle())
            .highPriorityGesture(
                LongPressGesture(minimumDuration: DS.Spacing.longPressDuration)
                    .onEnded { _ in
                        if let onLongPress = onLongPress {
                            HapticFeedback.light()
                            onLongPress()
                        }
                    }
            )
            .onTapGesture {
                showingActions = true
            }
        .confirmationDialog("Actions", isPresented: $showingActions, titleVisibility: .hidden) {
                // Filter selection options (when viewFilter is provided)
                if let currentFilter = viewFilter, let selectFilter = onFilterSelect {
                    Section {
                        ForEach(ViewFilter.allCases, id: \.self) { filter in
                            Button {
                                selectFilter(filter)
                            } label: {
                                HStack {
                                    Text(filter.label)
                                    if filter == currentFilter {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }

                // Standard actions
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

    /// Menu label with filter-aware color
    private var menuLabel: some View {
        Image(systemName: icon)
            .font(.system(size: 20))
            .foregroundColor(effectiveIconColor)
            .frame(
                width: CGFloat(DS.Spacing.minTouchTarget),
                height: CGFloat(DS.Spacing.minTouchTarget)
            )
            .contentShape(Rectangle())
    }
}

// MARK: - Previews

#Preview("Overflow Menu - Standard") {
    VStack(spacing: DS.Spacing.xl) {
        HStack {
            Text("Listing Title")
                .font(DS.Typography.headline)
            Spacer()
            OverflowMenu(actions: [
                OverflowMenu.Action(id: "edit", title: "Edit", icon: DS.Icons.Action.edit) {
                    print("Edit tapped")
                },
                OverflowMenu.Action(id: "share", title: "Share", icon: DS.Icons.Action.share) {
                    print("Share tapped")
                },
                OverflowMenu.Action(id: "delete", title: "Delete", icon: DS.Icons.Action.delete, role: .destructive) {
                    print("Delete tapped")
                }
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
            OverflowMenu.Action(id: "delete", title: "Delete", icon: DS.Icons.Action.delete, role: .destructive) {
                print("Delete tapped")
            }
        ])
    }
    .padding()
}

#Preview("Overflow Menu - With View Filter") {
    VStack(spacing: DS.Spacing.xl) {
        HStack {
            Text("All View (no ring)")
            Spacer()
            OverflowMenu(
                actions: [
                    OverflowMenu.Action(id: "edit", title: "Edit", icon: DS.Icons.Action.edit) {}
                ],
                viewFilter: .all,
                onLongPress: { print("Long press - cycling to Admin") }
            )
        }
        .padding()
        .background(DS.Colors.Background.card)
        .cornerRadius(DS.Spacing.radiusCard)

        HStack {
            Text("Admin View (blue ring)")
            Spacer()
            OverflowMenu(
                actions: [
                    OverflowMenu.Action(id: "edit", title: "Edit", icon: DS.Icons.Action.edit) {}
                ],
                viewFilter: .admin,
                onLongPress: { print("Long press - cycling to Marketing") }
            )
        }
        .padding()
        .background(DS.Colors.Background.card)
        .cornerRadius(DS.Spacing.radiusCard)

        HStack {
            Text("Marketing View (green ring)")
            Spacer()
            OverflowMenu(
                actions: [
                    OverflowMenu.Action(id: "edit", title: "Edit", icon: DS.Icons.Action.edit) {}
                ],
                viewFilter: .marketing,
                onLongPress: { print("Long press - cycling to All") }
            )
        }
        .padding()
        .background(DS.Colors.Background.card)
        .cornerRadius(DS.Spacing.radiusCard)
    }
    .padding()
}
