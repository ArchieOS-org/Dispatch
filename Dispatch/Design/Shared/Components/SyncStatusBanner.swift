//
//  SyncStatusBanner.swift
//  Dispatch
//
//  Global sync error banner component
//  Shows when sync fails, auto-hides when resolved
//

import SwiftUI

/// Error banner displayed at top of screen when sync fails.
/// Provides user-friendly message and retry action.
struct SyncStatusBanner: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white)

            Spacer()

            Button("Retry") {
                onRetry()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(Color.red.opacity(0.9))
    }
}

#Preview("Sync Error Banner") {
    VStack {
        SyncStatusBanner(
            message: "Sync failed. Some changes may not be saved.",
            onRetry: {}
        )

        Spacer()
    }
}
