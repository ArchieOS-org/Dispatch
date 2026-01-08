//
//  RealtorPill.swift
//  Dispatch
//
//  Tappable pill displaying realtor name with navigation to profile.
//  Part of ID-based navigation migration.
//

import SwiftUI

/// A tappable pill that displays a realtor's name and navigates to their profile.
struct RealtorPill: View {

  // MARK: Internal

  let user: User

  var body: some View {
    NavigationLink(value: AppRoute.realtor(user.id)) {
      Text(user.name)
        .font(DS.Typography.bodySecondary)
        .foregroundColor(DS.Colors.Text.primary)
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
        .background(DS.Colors.success.opacity(0.15))
        .clipShape(Capsule())
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Preview

#Preview("RealtorPill") {
  NavigationStack {
    VStack(spacing: 20) {
      RealtorPill(user: User(name: "John Smith", email: "john@example.com", userType: .realtor))
      RealtorPill(user: User(name: "Sarah Jones", email: "sarah@example.com", userType: .realtor))
    }
    .padding()
  }
}
