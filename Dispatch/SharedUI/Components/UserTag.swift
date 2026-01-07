//
//  UserTag.swift
//  Dispatch
//
//  Compact user indicator for list rows
//  Created by Claude on 2025-12-06.
//

import SwiftUI

struct UserTag: View {

  // MARK: Internal

  let user: User

  var body: some View {
    #if os(macOS)
    // macOS: Pill style with full name
    HStack(spacing: 4) {
      Image(systemName: "person.fill")
        .font(.system(size: 8))
      Text(user.name)
        .font(DS.Typography.captionSecondary)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 2)
    .background(Color.gray.opacity(0.1))
    .clipShape(Capsule())
    .foregroundStyle(.secondary)
    #else
    // iOS: Initials/Minimal
    Text(initials)
      .font(DS.Typography.caption)
      .foregroundStyle(.secondary)
    #endif
  }

  // MARK: Private

  private var initials: String {
    let components = user.name.components(separatedBy: .whitespaces)
    if let first = components.first?.first, let last = components.last?.first, components.count > 1 {
      return "\(first)\(last)"
    } else if let first = components.first?.first {
      return "\(first)"
    }
    return ""
  }
}

// MARK: - Preview

#Preview("User Tag") {
  VStack(spacing: 20) {
    UserTag(user: User(name: "Steve Jobs", email: "steve@apple.com", userType: .admin))
    UserTag(user: User(name: "Tim Cook", email: "tim@apple.com", userType: .admin))
    UserTag(user: User(name: "Jony", email: "jony@apple.com", userType: .admin))
  }
}
