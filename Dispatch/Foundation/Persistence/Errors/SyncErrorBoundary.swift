//
//  SyncErrorBoundary.swift
//  Dispatch
//
//  ViewModifier that catches sync errors and displays alerts.
//  Provides a consistent pattern for handling sync errors across the app.
//

import SwiftUI

// MARK: - SyncErrorBoundary

/// ViewModifier that catches sync errors and displays alerts to the user.
/// Wraps views to automatically show error alerts when sync fails.
///
/// Usage:
/// ```swift
/// ContentView()
///   .syncErrorBoundary()
/// ```
///
/// The modifier observes the SyncManager's syncStatus and shows an alert
/// when an error occurs. For retryable errors, it provides a retry button.
struct SyncErrorBoundary: ViewModifier {

  // MARK: Internal

  @EnvironmentObject var syncManager: SyncManager

  func body(content: Content) -> some View {
    content
      .onChange(of: syncManager.syncStatus) { _, newStatus in
        handleStatusChange(newStatus)
      }
      .alert(
        "Sync Error",
        isPresented: $showErrorAlert,
        presenting: syncManager.lastSyncErrorMessage
      ) { _ in
        alertActions
      } message: { message in
        Text(message)
      }
      .alert(
        "Sync Paused",
        isPresented: $showCircuitBreakerAlert
      ) {
        Button("OK", role: .cancel) { }
      } message: {
        Text(circuitBreakerMessage)
      }
  }

  // MARK: Private

  @State private var showErrorAlert = false
  @State private var showCircuitBreakerAlert = false
  @State private var lastProcessedError: String?
  @State private var circuitBreakerRemainingSeconds: Int = 0

  @ViewBuilder
  private var alertActions: some View {
    if isRetryable {
      Button("Retry") {
        Task {
          await syncManager.retrySync()
        }
      }
      Button("Dismiss", role: .cancel) {
        // Reset processed error on manual dismiss
        lastProcessedError = nil
      }
    } else {
      Button("OK", role: .cancel) {
        // Reset processed error on manual dismiss
        lastProcessedError = nil
      }
    }
  }

  /// Determines if the current error is retryable based on the sync error.
  /// Uses the SyncError classification system.
  private var isRetryable: Bool {
    guard let error = syncManager.syncError else {
      // Default to retryable if we can't classify (to give user another chance)
      return true
    }
    return SyncError.from(error).isRetryable
  }

  private var circuitBreakerMessage: String {
    if circuitBreakerRemainingSeconds > 60 {
      let minutes = circuitBreakerRemainingSeconds / 60
      return "Sync has been paused due to repeated failures. Will retry in \(minutes) minute\(minutes == 1 ? "" : "s")."
    } else {
      return "Sync has been paused due to repeated failures. Will retry in \(circuitBreakerRemainingSeconds) seconds."
    }
  }

  private func handleStatusChange(_ newStatus: SyncStatus) {
    switch newStatus {
    case .error:
      // Only show alert if this is a new error (avoid duplicate alerts)
      let currentError = syncManager.lastSyncErrorMessage
      if currentError != lastProcessedError {
        lastProcessedError = currentError
        showErrorAlert = true
      }

    case .circuitBreakerOpen(let remainingSeconds):
      // Show circuit breaker alert (only once per trip)
      if !showCircuitBreakerAlert {
        circuitBreakerRemainingSeconds = remainingSeconds
        showCircuitBreakerAlert = true
      }

    case .idle, .syncing, .ok:
      // Reset circuit breaker alert state when status clears
      if showCircuitBreakerAlert {
        showCircuitBreakerAlert = false
      }
    }
  }

}

// MARK: - View Extension

extension View {
  /// Wraps the view in a sync error boundary that shows alerts when sync fails.
  /// Requires SyncManager to be in the environment.
  ///
  /// Example:
  /// ```swift
  /// NavigationStack {
  ///   MyContentView()
  /// }
  /// .syncErrorBoundary()
  /// .environmentObject(SyncManager.shared)
  /// ```
  func syncErrorBoundary() -> some View {
    modifier(SyncErrorBoundary())
  }
}

// MARK: - Preview

#if DEBUG
private struct SyncErrorBoundaryPreview: View {

  // MARK: Internal

  var body: some View {
    VStack(spacing: DS.Spacing.lg) {
      Text("Sync Error Boundary Preview")
        .font(DS.Typography.headline)

      Text("Status: \(statusText)")
        .font(DS.Typography.body)
        .foregroundStyle(DS.Colors.Text.secondary)

      Button("Simulate Error") {
        // In preview mode, we can't actually trigger errors
        // This is just for demonstration
      }
      .buttonStyle(.borderedProminent)
    }
    .syncErrorBoundary()
    .environmentObject(syncManager)
  }

  // MARK: Private

  @StateObject private var syncManager = SyncManager(mode: .preview)

  private var statusText: String {
    switch syncManager.syncStatus {
    case .idle:
      "Idle"
    case .syncing:
      "Syncing..."
    case .ok:
      "OK"
    case .error:
      "Error"
    case .circuitBreakerOpen(let seconds):
      "Paused (\(seconds)s)"
    }
  }
}

#Preview {
  SyncErrorBoundaryPreview()
}
#endif
