//
//  OnboardingLoadingView.swift
//  Dispatch
//
//  Created by DispatchAI on 2025-12-28.
//

import SwiftUI

struct OnboardingLoadingView: View {

  // MARK: Internal

  var body: some View {
    ZStack {
      DS.Colors.Background.primary
        .ignoresSafeArea()

      VStack(spacing: DS.Spacing.lg) {
        Spacer()

        if let error = syncManager.lastSyncErrorMessage {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: errorIconSize))
            .foregroundStyle(DS.Colors.Sync.error)
            .padding(.bottom, DS.Spacing.sm)

          Text("Setup Failed")
            .font(DS.Typography.title3)
            .foregroundStyle(DS.Colors.Text.primary)

          Text(error)
            .font(DS.Typography.body)
            .foregroundStyle(DS.Colors.Text.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

          Button("Retry") {
            syncManager.requestSync()
          }
          .font(DS.Typography.body)
          .padding(.top, DS.Spacing.md)
        } else {
          ProgressView()
            .controlSize(.regular)
            .tint(DS.Colors.Text.primary)

          Text(message)
            .font(DS.Typography.body)
            .foregroundStyle(DS.Colors.Text.secondary)
            .multilineTextAlignment(.center)
            .task {
              // Cycle through messages if it takes a while
              // SwiftUI automatically cancels this task when view disappears
              await cycleMessages()
            }
        }

        Spacer()

        Button("Cancel & Sign Out") {
          Task {
            await AuthManager.shared.signOut()
          }
        }
        .buttonStyle(.plain)
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.Text.tertiary)
        .padding(.bottom, DS.Spacing.lg)
      }
    }
    .tint(DS.Colors.accent)
  }

  // MARK: Private

  /// Scaled error icon size for Dynamic Type support (base: 48pt)
  @ScaledMetric(relativeTo: .largeTitle)
  private var errorIconSize: CGFloat = 48

  @EnvironmentObject private var syncManager: SyncManager
  @State private var message = "Setting up your workspace..."

  private func cycleMessages() async {
    try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
    guard !Task.isCancelled, syncManager.lastSyncErrorMessage == nil else { return }
    withAnimation { message = "Syncing your profile..." }

    try? await Task.sleep(nanoseconds: 4 * 1_000_000_000)
    guard !Task.isCancelled, syncManager.lastSyncErrorMessage == nil else { return }
    withAnimation { message = "Almost there..." }
  }
}

#Preview {
  OnboardingLoadingView()
    .environmentObject(SyncManager(mode: .preview))
}
