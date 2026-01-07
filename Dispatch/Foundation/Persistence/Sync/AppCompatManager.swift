//
//  AppCompatManager.swift
//  Dispatch
//
//  Contract-level version compatibility management.
//  Checks app version against server requirements at startup and before sync.
//

import Combine
import Foundation
import Supabase

// MARK: - AppCompatResult

/// Result of version compatibility check
struct AppCompatResult: Codable {
  enum CodingKeys: String, CodingKey {
    case compatible
    case minVersion = "min_version"
    case currentVersion = "current_version"
    case forceUpdate = "force_update"
    case migrationRequired = "migration_required"
    case message
  }

  let compatible: Bool
  let minVersion: String?
  let currentVersion: String?
  let forceUpdate: Bool
  let migrationRequired: Bool?
  let message: String?

}

// MARK: - AppCompatStatus

/// App compatibility status
enum AppCompatStatus: Equatable {
  /// App version is compatible
  case compatible

  /// Update available but not required
  case updateAvailable(currentVersion: String)

  /// Update required - should block usage
  case updateRequired(minVersion: String)

  /// Unable to check (network error, etc.) - allow usage
  case unknown(error: String)

  var isBlocked: Bool {
    if case .updateRequired = self {
      return true
    }
    return false
  }
}

// MARK: - AppCompatManager

/// Manages app version compatibility checks against Supabase
@MainActor
final class AppCompatManager: ObservableObject {

  // MARK: Lifecycle

  private init() {
    debugLog.log("AppCompatManager initialized", category: .sync)
    debugLog.log("  App version: \(appVersion)", category: .sync)
    debugLog.log("  Platform: \(platform)", category: .sync)
  }

  // MARK: Internal

  static let shared = AppCompatManager()

  @Published private(set) var status = AppCompatStatus.compatible
  @Published private(set) var lastCheckTime: Date?

  /// Check if the app can proceed with normal operations
  /// Returns true if compatible or unable to check (fail-open for connectivity issues)
  var canProceed: Bool {
    !status.isBlocked
  }

  /// Human-readable message for current status
  var statusMessage: String {
    switch status {
    case .compatible:
      "App is up to date"
    case .updateAvailable(let version):
      "Update available: v\(version)"
    case .updateRequired(let minVersion):
      "Update required. Minimum version: v\(minVersion)"
    case .unknown(let error):
      "Unable to check for updates: \(error)"
    }
  }

  /// Check version compatibility with server
  /// - Returns: The compatibility status
  @discardableResult
  func checkCompatibility() async -> AppCompatStatus {
    debugLog.log("Checking app compatibility...", category: .sync)
    debugLog.log("  App version: \(appVersion)", category: .sync)
    debugLog.log("  Platform: \(platform)", category: .sync)

    do {
      // Call the RPC function
      let result: AppCompatResult = try await supabase
        .rpc("check_version_compat", params: [
          "p_platform": platform,
          "p_client_version": appVersion,
        ])
        .execute()
        .value

      debugLog.log("Compatibility check result:", category: .sync)
      debugLog.log("  compatible: \(result.compatible)", category: .sync)
      debugLog.log("  min_version: \(result.minVersion ?? "nil")", category: .sync)
      debugLog.log("  current_version: \(result.currentVersion ?? "nil")", category: .sync)
      debugLog.log("  force_update: \(result.forceUpdate)", category: .sync)
      debugLog.log("  message: \(result.message ?? "nil")", category: .sync)

      lastCheckTime = Date()

      if result.forceUpdate, !result.compatible {
        status = .updateRequired(minVersion: result.minVersion ?? "unknown")
      } else if !result.compatible {
        status = .updateAvailable(currentVersion: result.currentVersion ?? "unknown")
      } else {
        status = .compatible
      }

      return status
    } catch {
      debugLog.log("Compatibility check failed: \(error.localizedDescription)", category: .error)

      // On error, allow usage but track the issue
      status = .unknown(error: error.localizedDescription)
      return status
    }
  }

  // MARK: Private

  /// Current app version (read from bundle)
  private var appVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
  }

  /// Platform identifier for server lookup
  private var platform: String {
    #if os(iOS)
    return "ios"
    #elseif os(macOS)
    return "macos"
    #else
    return "unknown"
    #endif
  }

  /// Supabase client (using shared instance)
  private var supabase: SupabaseClient {
    SupabaseService.shared.client
  }

}

// MARK: - Sync Integration

extension AppCompatManager {
  /// Performs pre-sync compatibility check.
  /// Returns true if sync should proceed, false if blocked.
  func preSyncCheck() async -> Bool {
    // Only check periodically (not every sync)
    if let lastCheck = lastCheckTime, Date().timeIntervalSince(lastCheck) < 3600 {
      // Use cached result if checked within the last hour
      return canProceed
    }

    await checkCompatibility()
    return canProceed
  }
}
