//
//  SupabaseClient.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation
import OSLog
import SharedBackend
import Supabase

// MARK: - SupabaseService

/// App-level service that wraps SharedBackend.Backend for backward compatibility.
/// Provides the `supabase` global accessor used throughout the app.
final class SupabaseService {

  // MARK: Lifecycle

  private init() {
    #if DEBUG
    Self.logger.debug("Initializing SupabaseService via SharedBackend...")
    #endif

    do {
      backend = try Backend(config: AppBackendConfig())
      #if DEBUG
      Self.logger.info("SupabaseService initialized successfully via SharedBackend")
      #endif
    } catch {
      fatalError("Failed to initialize SharedBackend: \(error)")
    }
  }

  // MARK: Internal

  static let shared = SupabaseService()

  /// The SharedBackend instance
  let backend: Backend

  /// The underlying SupabaseClient for backward compatibility.
  /// Prefer using backend services (backend.auth, backend.database, etc.) when possible.
  var client: SupabaseClient {
    backend.client
  }

  // MARK: Private

  private static let logger = Logger(subsystem: "Dispatch", category: "SupabaseService")

}

/// Convenience accessor for backward compatibility.
/// Code can continue using `supabase.from(...)`, `supabase.auth`, etc.
var supabase: SupabaseClient {
  SupabaseService.shared.client
}

/// Convenience accessor to the SharedBackend instance.
/// Prefer using this for new code that wants typed service access.
var backend: Backend {
  SupabaseService.shared.backend
}
