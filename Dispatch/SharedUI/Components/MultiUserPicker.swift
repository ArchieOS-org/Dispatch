//
//  MultiUserPicker.swift
//  Dispatch
//
//  List picker for selecting multiple users as assignees.
//

import SwiftUI

// MARK: - MultiUserPicker

/// Simple list picker for selecting multiple users.
/// Current user is sorted to top of list for easy access.
struct MultiUserPicker: View {

  // MARK: Lifecycle

  init(
    selectedUserIds: Binding<Set<UUID>>,
    availableUsers: [User],
    currentUserId: UUID
  ) {
    _selectedUserIds = selectedUserIds
    self.availableUsers = availableUsers
    self.currentUserId = currentUserId
  }

  // MARK: Internal

  @Binding var selectedUserIds: Set<UUID>

  let availableUsers: [User]
  let currentUserId: UUID

  var body: some View {
    List {
      ForEach(sortedUsers, id: \.id) { user in
        userRow(user: user)
      }
    }
    .listStyle(.plain)
  }

  // MARK: Private

  /// Scaled checkmark size for Dynamic Type support (base: 14pt, relative to footnote)
  @ScaledMetric(relativeTo: .footnote)
  private var checkmarkSize: CGFloat = 14

  private var sortedUsers: [User] {
    availableUsers.sorted { lhs, rhs in
      // Current user first, then alphabetical
      if lhs.id == currentUserId { return true }
      if rhs.id == currentUserId { return false }
      return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
  }

  private func userRow(user: User) -> some View {
    let isSelected = selectedUserIds.contains(user.id)

    return Button {
      if isSelected {
        selectedUserIds.remove(user.id)
      } else {
        selectedUserIds.insert(user.id)
      }
    } label: {
      HStack(spacing: DS.Spacing.sm) {
        UserAvatar(user: user, size: .small)

        VStack(alignment: .leading, spacing: 2) {
          Text(user.name)
            .font(DS.Typography.body)
            .foregroundStyle(DS.Colors.Text.primary)

          if user.id == currentUserId {
            Text("You")
              .font(DS.Typography.caption)
              .foregroundStyle(DS.Colors.Text.tertiary)
          }
        }

        Spacer()

        if isSelected {
          Image(systemName: "checkmark")
            .font(.system(size: checkmarkSize, weight: .semibold))
            .foregroundStyle(DS.Colors.accent)
        }
      }
      .padding(.vertical, DS.Spacing.xs)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .listRowBackground(isSelected ? DS.Colors.accent.opacity(0.1) : Color.clear)
  }
}

// MARK: - MultiUserPickerSheet

/// Standardized sheet wrapper for MultiUserPicker.
/// Provides consistent navigation, toolbar, and presentation across platforms.
struct MultiUserPickerSheet: View {

  // MARK: Lifecycle

  init(
    selectedUserIds: Binding<Set<UUID>>,
    availableUsers: [User],
    currentUserId: UUID,
    onDone: @escaping () -> Void
  ) {
    _selectedUserIds = selectedUserIds
    self.availableUsers = availableUsers
    self.currentUserId = currentUserId
    self.onDone = onDone
  }

  // MARK: Internal

  @Binding var selectedUserIds: Set<UUID>

  let availableUsers: [User]
  let currentUserId: UUID
  var onDone: () -> Void

  var body: some View {
    NavigationStack {
      StandardScreen(
        title: "Assign Users",
        layout: .column,
        scroll: .disabled
      ) {
        MultiUserPicker(
          selectedUserIds: $selectedUserIds,
          availableUsers: availableUsers,
          currentUserId: currentUserId
        )
      } toolbarContent: {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            onDone()
          }
        }
      }
    }
    #if os(iOS)
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    #elseif os(macOS)
    .frame(minWidth: 300, minHeight: 400)
    #endif
  }
}

// MARK: - Previews

#Preview("MultiUserPicker") {
  struct PreviewWrapper: View {
    @State private var selected = Set<UUID>()

    let users: [User] = {
      let names = ["Alice Smith", "Bob Jones", "Carol White", "Dave Brown", "Eve Green"]
      return names.map { name in
        User(
          id: UUID(),
          name: name,
          email: "\(name.lowercased().replacingOccurrences(of: " ", with: "."))@example.com",
          userType: .realtor
        )
      }
    }()

    var body: some View {
      NavigationStack {
        MultiUserPicker(
          selectedUserIds: $selected,
          availableUsers: users,
          currentUserId: users.first?.id ?? UUID()
        )
        .navigationTitle("Select Users")
      }
      #if os(macOS)
      .frame(width: 320, height: 400)
      #endif
    }
  }

  return PreviewWrapper()
}

#Preview("MultiUserPickerSheet") {
  struct PreviewWrapper: View {
    @State private var selected = Set<UUID>()
    @State private var showSheet = true

    let users: [User] = {
      let names = ["Alice Smith", "Bob Jones", "Carol White", "Dave Brown", "Eve Green"]
      return names.map { name in
        User(
          id: UUID(),
          name: name,
          email: "\(name.lowercased().replacingOccurrences(of: " ", with: "."))@example.com",
          userType: .realtor
        )
      }
    }()

    var body: some View {
      Text("Selected: \(selected.count)")
        .sheet(isPresented: $showSheet) {
          MultiUserPickerSheet(
            selectedUserIds: $selected,
            availableUsers: users,
            currentUserId: users.first?.id ?? UUID(),
            onDone: { showSheet = false }
          )
        }
    }
  }

  return PreviewWrapper()
}
