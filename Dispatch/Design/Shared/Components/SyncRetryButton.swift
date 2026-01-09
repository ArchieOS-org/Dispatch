//
//  SyncRetryButton.swift
//  Dispatch
//
//  Inline retry button for per-entity sync failures.
//  Shows error icon with tap-to-retry functionality.
//

import SwiftUI

// MARK: - SyncRetryButton

/// Compact retry button shown on work items with failed sync.
/// Displays error icon and brief message, triggers retry on tap.
struct SyncRetryButton: View {
  let errorMessage: String?
  let isRetrying: Bool
  let onRetry: () -> Void

  var body: some View {
    Button(action: onRetry) {
      HStack(spacing: DS.Spacing.xxs) {
        if isRetrying {
          ProgressView()
            .scaleEffect(0.7)
            .frame(width: 14, height: 14)
        } else {
          Image(systemName: DS.Icons.Sync.error)
            .font(.system(size: 12))
            .foregroundStyle(DS.Colors.Sync.error)
        }

        Text(isRetrying ? "Syncing..." : "Retry")
          .font(DS.Typography.caption)
          .foregroundStyle(isRetrying ? DS.Colors.Text.tertiary : DS.Colors.Sync.error)
      }
      .padding(.horizontal, DS.Spacing.sm)
      .padding(.vertical, DS.Spacing.xxs)
      .background(
        Capsule()
          .fill(DS.Colors.Sync.error.opacity(0.1))
      )
    }
    .buttonStyle(.plain)
    .disabled(isRetrying)
    .accessibilityLabel(isRetrying ? "Syncing" : "Retry sync")
    .accessibilityHint(errorMessage.map { "Error: \($0)" } ?? "Tap to retry")
  }
}

// MARK: - SyncErrorRow

/// Variant that shows full error message in a row format
struct SyncErrorRow: View {
  let errorMessage: String
  let isRetrying: Bool
  let onRetry: () -> Void

  var body: some View {
    HStack(spacing: DS.Spacing.sm) {
      Image(systemName: DS.Icons.Alert.warningFill)
        .font(.system(size: 14))
        .foregroundStyle(DS.Colors.warning)

      Text(errorMessage)
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.Text.secondary)
        .lineLimit(2)

      Spacer()

      SyncRetryButton(
        errorMessage: errorMessage,
        isRetrying: isRetrying,
        onRetry: onRetry
      )
    }
    .padding(.horizontal, DS.Spacing.md)
    .padding(.vertical, DS.Spacing.xs)
    .background(DS.Colors.warning.opacity(0.08))
  }
}

#Preview("Sync Retry Button") {
  VStack(spacing: DS.Spacing.lg) {
    SyncRetryButton(
      errorMessage: "Network error",
      isRetrying: false,
      onRetry: { }
    )

    SyncRetryButton(
      errorMessage: nil,
      isRetrying: true,
      onRetry: { }
    )

    SyncErrorRow(
      errorMessage: "Failed to sync. Check your connection.",
      isRetrying: false,
      onRetry: { }
    )

    SyncErrorRow(
      errorMessage: "Network timeout",
      isRetrying: true,
      onRetry: { }
    )
  }
  .padding()
}
