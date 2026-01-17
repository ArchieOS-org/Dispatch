//
//  RoleDot.swift
//  Dispatch
//
//  Split-dot indicator showing item audience
//

import SwiftUI

/// A dot indicator showing which roles/audiences an item is visible to.
/// - Admin-only: solid admin-color dot
/// - Marketing-only: solid marketing-color dot
/// - Both: split dot (half admin blue, half marketing green)
struct RoleDot: View {

  // MARK: Internal

  let audiences: Set<Role>
  var size: CGFloat = DS.Spacing.roleDotSize

  var body: some View {
    Group {
      if audiences.contains(.admin), audiences.contains(.marketing) {
        // Split dot for both audiences
        splitDot
      } else if audiences.contains(.admin) {
        // Solid admin dot
        Circle()
          .fill(DS.Colors.RoleColors.admin)
          .frame(width: size, height: size)
      } else if audiences.contains(.marketing) {
        // Solid marketing dot
        Circle()
          .fill(DS.Colors.RoleColors.marketing)
          .frame(width: size, height: size)
      } else {
        // Empty (no audiences) - shouldn't happen normally
        EmptyView()
      }
    }
    .opacity(DS.Spacing.roleIndicatorOpacity)
    .accessibilityLabel(accessibilityDescription)
  }

  /// Generates a descriptive label for VoiceOver based on audiences
  private var accessibilityDescription: String {
    if audiences.contains(.admin), audiences.contains(.marketing) {
      return "Visible to admin and marketing"
    } else if audiences.contains(.admin) {
      return "Visible to admin only"
    } else if audiences.contains(.marketing) {
      return "Visible to marketing only"
    } else {
      return "No audience assigned"
    }
  }

  // MARK: Private

  /// Split dot using Circle().trim() for clean half-circles
  private var splitDot: some View {
    ZStack {
      // Admin half (left side)
      Circle()
        .trim(from: 0, to: 0.5)
        .fill(DS.Colors.RoleColors.admin)
        .rotationEffect(.degrees(-90))

      // Marketing half (right side)
      Circle()
        .trim(from: 0.5, to: 1)
        .fill(DS.Colors.RoleColors.marketing)
        .rotationEffect(.degrees(-90))
    }
    .frame(width: size, height: size)
  }
}

// MARK: - Previews

#Preview("RoleDot - Admin Only") {
  HStack(spacing: DS.Spacing.lg) {
    RoleDot(audiences: [.admin])
    Text("Admin only")
      .font(DS.Typography.body)
  }
  .padding()
}

#Preview("RoleDot - Marketing Only") {
  HStack(spacing: DS.Spacing.lg) {
    RoleDot(audiences: [.marketing])
    Text("Marketing only")
      .font(DS.Typography.body)
  }
  .padding()
}

#Preview("RoleDot - Both Audiences") {
  HStack(spacing: DS.Spacing.lg) {
    RoleDot(audiences: [.admin, .marketing])
    Text("Both audiences")
      .font(DS.Typography.body)
  }
  .padding()
}

#Preview("RoleDot - Comparison") {
  VStack(alignment: .leading, spacing: DS.Spacing.md) {
    HStack(spacing: DS.Spacing.md) {
      RoleDot(audiences: [.admin])
      Text("Admin")
    }
    HStack(spacing: DS.Spacing.md) {
      RoleDot(audiences: [.marketing])
      Text("Marketing")
    }
    HStack(spacing: DS.Spacing.md) {
      RoleDot(audiences: [.admin, .marketing])
      Text("Both")
    }
  }
  .font(DS.Typography.body)
  .padding()
}
