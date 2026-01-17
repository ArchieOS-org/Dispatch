//
//  AppBackendConfig.swift
//  Dispatch
//
//  App-specific configuration for SharedBackend.
//  Provides Supabase credentials from Secrets.swift.
//

import Foundation
import SharedBackend

/// App-specific configuration that provides Supabase credentials to SharedBackend.
struct AppBackendConfig: BackendConfig {
  let supabaseURL: String = Secrets.supabaseURL
  let supabaseAnonKey: String = Secrets.supabaseAnonKey
  let databaseSchema: String = "public"
  let appName: String = "dispatch-ios"
  let customHeaders: [String: String] = [:]
}
