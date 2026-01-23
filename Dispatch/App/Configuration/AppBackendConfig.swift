//
//  AppBackendConfig.swift
//  Dispatch
//
//  App-specific configuration for SharedBackend.
//  Uses SupabaseEnvironment to determine which backend to connect to.
//
//  To use local Supabase:
//  1. Run the "Dispatch-Local" scheme
//  2. Or add LOCAL_SUPABASE to SWIFT_ACTIVE_COMPILATION_CONDITIONS
//

import Foundation
import SharedBackend

/// App-specific configuration that provides Supabase credentials to SharedBackend.
/// Automatically selects production or local Supabase based on the active scheme.
struct AppBackendConfig: BackendConfig {
  let supabaseURL: String = SupabaseEnvironment.current.url
  let supabaseAnonKey: String = SupabaseEnvironment.current.anonKey
  let databaseSchema: String = "public"
  let appName: String = "dispatch-ios"
  let customHeaders: [String: String] = [:]
}
