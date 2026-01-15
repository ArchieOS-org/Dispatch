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
            .font(.system(size: 48))
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
            .onAppear {
              // Cycle through messages if it takes a while
              cycleMessages()
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

  @EnvironmentObject private var syncManager: SyncManager
  @State private var message = "Setting up your workspace..."

  private func cycleMessages() {
    Task {
      try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
      guard syncManager.lastSyncErrorMessage == nil else { return }
      withAnimation { message = "Syncing your profile..." }

      try? await Task.sleep(nanoseconds: 4 * 1_000_000_000)
      guard syncManager.lastSyncErrorMessage == nil else { return }
      withAnimation { message = "Almost there..." }
    }
  }
}

#Preview {
  OnboardingLoadingView()
    .environmentObject(SyncManager(mode: .preview))
}
