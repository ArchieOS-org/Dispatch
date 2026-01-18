//
//  OverlappingAvatars.swift
//  Dispatch
//
//  Displays up to 3 overlapping user avatars with "+N" overflow indicator.
//

import SwiftUI

/// Displays assignee avatars in an overlapping stack with overflow indicator.
/// Shows UnassignedBadge when no users are assigned.
struct OverlappingAvatars: View {

  // MARK: Lifecycle

  init(
    userIds: [UUID],
    users: [UUID: User],
    maxVisible: Int = 3,
    size: UserAvatar.AvatarSize = .small
  ) {
    self.userIds = userIds
    self.users = users
    self.maxVisible = maxVisible
    self.size = size
  }

  // MARK: Internal

  let userIds: [UUID]
  let users: [UUID: User]
  let maxVisible: Int
  let size: UserAvatar.AvatarSize

  var body: some View {
    if userIds.isEmpty {
      UnassignedBadge()
    } else {
      avatarStack
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
      #if os(macOS)
        .onHover { isHovered = $0 }
        .popover(isPresented: $isHovered, arrowEdge: .bottom) {
          userListPopover
        }
      #else
        .onTapGesture { showPopover = true }
        .popover(isPresented: $showPopover) {
          userListPopover
        }
      #endif
    }
  }

  // MARK: Private

  /// Scaled font size for small avatars (base: 10pt, relative to caption2)
  @ScaledMetric(relativeTo: .caption2)
  private var smallFontSize: CGFloat = 10

  /// Scaled font size for medium avatars (base: 14pt, relative to footnote)
  @ScaledMetric(relativeTo: .footnote)
  private var mediumFontSize: CGFloat = 14

  /// Scaled font size for large avatars (base: 18pt, relative to headline)
  @ScaledMetric(relativeTo: .headline)
  private var largeFontSize: CGFloat = 18

  @State private var isHovered = false
  @State private var showPopover = false

  /// Returns the appropriate scaled font size for the current avatar size
  private var scaledFontSize: CGFloat {
    switch size {
    case .small: smallFontSize
    case .medium: mediumFontSize
    case .large: largeFontSize
    }
  }

  private var overlapOffset: CGFloat {
    -size.dimension * 0.33
  }

  private var visibleUserIds: [UUID] {
    Array(userIds.prefix(maxVisible))
  }

  private var overflowCount: Int {
    max(0, userIds.count - maxVisible)
  }

  private var accessibilityDescription: String {
    let names = userIds.compactMap { users[$0]?.name }
    let unknownCount = userIds.count - names.count

    if names.isEmpty {
      return "Assigned to \(unknownCount) unknown user\(unknownCount == 1 ? "" : "s")"
    }

    var description = "Assigned to "
    if names.count == 1 {
      description += names[0]
    } else if names.count == 2 {
      description += "\(names[0]) and \(names[1])"
    } else {
      let allButLast = names.dropLast().joined(separator: ", ")
      if let lastName = names.last {
        description += "\(allButLast), and \(lastName)"
      }
    }

    if unknownCount > 0 {
      description += ", and \(unknownCount) more"
    }

    return description
  }

  private var avatarStack: some View {
    HStack(spacing: overlapOffset) {
      ForEach(visibleUserIds, id: \.self) { userId in
        avatarView(for: userId)
          .overlay(
            Circle()
              .stroke(DS.Colors.Background.primary, lineWidth: 2)
          )
      }

      if overflowCount > 0 {
        overflowBadge
      }
    }
  }

  private var overflowBadge: some View {
    ZStack {
      Circle()
        .fill(DS.Colors.Background.secondary)
      Text("+\(overflowCount)")
        .font(.system(size: scaledFontSize, weight: .semibold))
        .foregroundStyle(DS.Colors.Text.secondary)
    }
    .frame(width: size.dimension, height: size.dimension)
    .overlay(
      Circle()
        .stroke(DS.Colors.Background.primary, lineWidth: 2)
    )
  }

  private var userListPopover: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      Text("Assigned to")
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.Text.secondary)

      ForEach(userIds, id: \.self) { userId in
        userRow(for: userId)
      }
    }
    .padding(DS.Spacing.md)
    .frame(minWidth: 180)
  }

  @ViewBuilder
  private func avatarView(for userId: UUID) -> some View {
    let user = users[userId]
    UserAvatar(user: user, size: size)
  }

  @ViewBuilder
  private func userRow(for userId: UUID) -> some View {
    let user = users[userId]
    HStack(spacing: DS.Spacing.sm) {
      UserAvatar(user: user, size: .small)
      Text(user?.name ?? "Unknown user")
        .font(DS.Typography.body)
        .foregroundStyle(user != nil ? DS.Colors.Text.primary : DS.Colors.Text.tertiary)
    }
  }

}

// MARK: - Preview

#Preview("OverlappingAvatars - Multiple Users") {
  let users: [UUID: User] = {
    var dict = [UUID: User]()
    let ids = [UUID(), UUID(), UUID(), UUID(), UUID()]
    let names = ["Alice Smith", "Bob Jones", "Carol White", "Dave Brown", "Eve Green"]
    for (id, name) in zip(ids, names) {
      dict[id] = User(
        id: id,
        name: name,
        email: "\(name.lowercased().replacingOccurrences(of: " ", with: "."))@example.com",
        userType: .realtor
      )
    }
    return dict
  }()

  let allIds = Array(users.keys)

  VStack(alignment: .leading, spacing: DS.Spacing.xl) {
    Group {
      Text("Empty (Unassigned)")
        .font(DS.Typography.caption)
      OverlappingAvatars(userIds: [], users: [:])
    }

    Group {
      Text("Single User")
        .font(DS.Typography.caption)
      OverlappingAvatars(userIds: [allIds[0]], users: users)
    }

    Group {
      Text("Two Users")
        .font(DS.Typography.caption)
      OverlappingAvatars(userIds: Array(allIds.prefix(2)), users: users)
    }

    Group {
      Text("Three Users (Max)")
        .font(DS.Typography.caption)
      OverlappingAvatars(userIds: Array(allIds.prefix(3)), users: users)
    }

    Group {
      Text("Five Users (Overflow)")
        .font(DS.Typography.caption)
      OverlappingAvatars(userIds: allIds, users: users)
    }

    Group {
      Text("Unknown User (Cache Miss)")
        .font(DS.Typography.caption)
      OverlappingAvatars(userIds: [UUID()], users: [:])
    }

    Group {
      Text("Medium Size")
        .font(DS.Typography.caption)
      OverlappingAvatars(userIds: Array(allIds.prefix(3)), users: users, size: .medium)
    }
  }
  .padding()
}
