//
//  MultiUserPicker.swift
//  Dispatch
//
//  List picker for selecting multiple users as assignees.
//

import SwiftUI

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
    VStack(alignment: .leading, spacing: 0) {
      // User list (current user sorted to top)
      ForEach(sortedUsers, id: \.id) { user in
        userRow(user: user)
      }
    }
    .padding(.vertical, DS.Spacing.sm)
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
      .padding(.horizontal, DS.Spacing.md)
      .padding(.vertical, DS.Spacing.sm)
      .background(isSelected ? DS.Colors.accent.opacity(0.1) : Color.clear)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Preview

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
      VStack(alignment: .leading, spacing: DS.Spacing.md) {
        Text("Selected: \(selected.count)")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.Text.secondary)

        Divider()

        MultiUserPicker(
          selectedUserIds: $selected,
          availableUsers: users,
          currentUserId: users.first?.id ?? UUID()
        )
      }
      .frame(width: 280)
      .background(DS.Colors.Background.primary)
    }
  }

  return PreviewWrapper()
}
