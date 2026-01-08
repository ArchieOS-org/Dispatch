//
//  SupabaseClient.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation
import OSLog
import Supabase

// MARK: - SupabaseService

final class SupabaseService {

  // MARK: Lifecycle

  private init() {
    #if DEBUG
    Self.logger.debug("Initializing Supabase client...")
    Self.logger.debug("URL: \(Secrets.supabaseURL, privacy: .private)")
    Self.logger.debug("Anon Key (prefix): \(String(Secrets.supabaseAnonKey.prefix(30)), privacy: .private)...")
    #endif

    guard let url = URL(string: Secrets.supabaseURL) else {
      fatalError("Invalid Supabase URL: \(Secrets.supabaseURL)")
    }

    #if DEBUG
    Self.logger.debug("URL parsed successfully: \(url.absoluteString, privacy: .private)")
    #endif

    client = SupabaseClient(
      supabaseURL: url,
      supabaseKey: Secrets.supabaseAnonKey,
      options: SupabaseClientOptions(
        db: .init(schema: "public"),
        auth: .init(
          flowType: .pkce,
          emitLocalSessionAsInitialSession: true,
        ),
        global: .init(
          headers: ["x-app-name": "dispatch-ios"]
        ),
      ),
    )

    #if DEBUG
    Self.logger.info("SupabaseClient initialized successfully")
    Self.logger.debug("DB Schema: public")
    Self.logger.debug("Auth Flow: PKCE")
    Self.logger.debug("Custom Headers: x-app-name=dispatch-ios")
    #endif
  }

  // MARK: Internal

  static let shared = SupabaseService()

  let client: SupabaseClient

  // MARK: Private

  private static let logger = Logger(subsystem: "Dispatch", category: "SupabaseService")

}

/// Convenience accessor
var supabase: SupabaseClient {
  SupabaseService.shared.client
}
