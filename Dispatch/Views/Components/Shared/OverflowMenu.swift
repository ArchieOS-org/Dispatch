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

    /// Optional audience lens for displaying ring indicator
    var audienceLens: AudienceLens?

    /// Optional callback for long-press gesture to cycle audience lens
    var onLongPress: (() -> Void)?

    /// Optional callback for direct lens selection from menu
    var onLensSelect: ((AudienceLens) -> Void)?

    // MARK: - Private State

    @State private var showingActions = false

    // MARK: - Private Properties

    /// Icon color based on current audience lens (overrides iconColor when filter is active)
    private var effectiveIconColor: Color {
        guard let lens = audienceLens else { return iconColor }
        switch lens {
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
                // Lens selection options (when audienceLens is provided)
                if let currentLens = audienceLens, let selectLens = onLensSelect {
                    Section {
                        ForEach(AudienceLens.allCases, id: \.self) { lens in
                            Button {
                                selectLens(lens)
                            } label: {
                                HStack {
                                    Text(lens.label)
                                    if lens == currentLens {
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

#Preview("Overflow Menu - With Audience Lens") {
    VStack(spacing: DS.Spacing.xl) {
        HStack {
            Text("All View (no ring)")
            Spacer()
            OverflowMenu(
                actions: [
                    OverflowMenu.Action(id: "edit", title: "Edit", icon: DS.Icons.Action.edit) {}
                ],
                audienceLens: .all,
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
                audienceLens: .admin,
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
                audienceLens: .marketing,
                onLongPress: { print("Long press - cycling to All") }
            )
        }
        .padding()
        .background(DS.Colors.Background.card)
        .cornerRadius(DS.Spacing.radiusCard)
    }
    .padding()
}
