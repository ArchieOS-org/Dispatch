//
//  UserAvatar.swift
//  Dispatch
//
//  Shared Component - User avatar with initials fallback
//  Created by Claude on 2025-12-06.
//

import SwiftUI

/// Displays a user's avatar image or falls back to colored initials.
/// Supports three sizes: small (24pt), medium (32pt), large (44pt).
struct UserAvatar: View {
    let user: User?
    var size: AvatarSize = .small

    enum AvatarSize {
        case small
        case medium
        case large

        var dimension: CGFloat {
            switch self {
            case .small: return DS.Spacing.avatarSmall
            case .medium: return DS.Spacing.avatarMedium
            case .large: return DS.Spacing.avatarLarge
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 14
            case .large: return 18
            }
        }
    }

    private var initials: String {
        guard let user else { return "?" }
        let components = user.name.split(separator: " ")
        let firstInitial = components.first?.prefix(1) ?? ""
        let lastInitial = components.count > 1 ? components.last?.prefix(1) ?? "" : ""
        return "\(firstInitial)\(lastInitial)".uppercased()
    }

    private var backgroundColor: Color {
        guard let user else { return Color.gray }
        // Deterministic color based on user ID
        let colors: [Color] = [
            .blue, .green, .orange, .purple, .pink, .teal, .indigo, .cyan
        ]
        let index = abs(user.id.hashValue) % colors.count
        return colors[index]
    }

    var body: some View {
        Group {
            if let avatarData = user?.avatar,
               let uiImage = UIImage(data: avatarData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(backgroundColor)
                    Text(initials)
                        .font(.system(size: size.fontSize, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: size.dimension, height: size.dimension)
        .clipShape(Circle())
        .accessibilityLabel(user?.name ?? "Unknown user")
    }
}

// MARK: - Preview

#Preview("Avatar Sizes") {
    VStack(spacing: DS.Spacing.lg) {
        HStack(spacing: DS.Spacing.md) {
            UserAvatar(user: nil, size: .small)
            UserAvatar(user: nil, size: .medium)
            UserAvatar(user: nil, size: .large)
        }

        Text("(Initials fallback shown)")
            .font(DS.Typography.caption)
            .foregroundColor(DS.Colors.Text.secondary)
    }
    .padding()
}
