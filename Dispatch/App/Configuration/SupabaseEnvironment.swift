//
//  SupabaseEnvironment.swift
//  Dispatch
//
//  Provides environment-aware Supabase configuration.
//  Use the "Dispatch-Local" scheme to connect to local Docker Supabase.
//
//  To find your Mac's local IP for iPhone testing:
//  1. System Settings > Network > Wi-Fi > Details > IP Address
//  2. Or run: ipconfig getifaddr en0
//
//  Update LOCAL_SUPABASE_HOST below with your Mac's IP address.
//

import Foundation

// MARK: - Local Supabase Configuration

/// Host for local Supabase Docker instance.
/// Update this to your Mac's local IP when testing from a physical iPhone.
/// Use "127.0.0.1" for simulator testing, or your Mac's IP (e.g., "192.168.1.100") for device testing.
private let LOCAL_SUPABASE_HOST = "127.0.0.1"

/// Port for local Supabase API (default Docker setup)
private let LOCAL_SUPABASE_PORT = "54321"

/// Anon key from local Supabase Docker setup
private let LOCAL_SUPABASE_ANON_KEY = "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"

// MARK: - SupabaseEnvironment

/// Determines which Supabase environment to use based on compile-time flags.
enum SupabaseEnvironment {

  case production
  case local

  // MARK: Internal

  /// The current environment, determined at compile time.
  /// Set LOCAL_SUPABASE flag in the scheme's build settings to use local Supabase.
  static var current: SupabaseEnvironment {
    #if LOCAL_SUPABASE
    return .local
    #else
    return .production
    #endif
  }

  /// The Supabase URL for this environment
  var url: String {
    switch self {
    case .production:
      Secrets.supabaseURL
    case .local:
      "http://\(LOCAL_SUPABASE_HOST):\(LOCAL_SUPABASE_PORT)"
    }
  }

  /// The Supabase anon key for this environment
  var anonKey: String {
    switch self {
    case .production:
      Secrets.supabaseAnonKey
    case .local:
      LOCAL_SUPABASE_ANON_KEY
    }
  }

  /// Human-readable description of the environment
  var description: String {
    switch self {
    case .production:
      "Production"
    case .local:
      "Local (\(LOCAL_SUPABASE_HOST):\(LOCAL_SUPABASE_PORT))"
    }
  }
}
