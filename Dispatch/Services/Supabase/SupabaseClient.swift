//
//  SupabaseClient.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation
import Supabase

// MARK: - Supabase Client Singleton
internal final class SupabaseService {
    internal static let shared = SupabaseService()

    internal let client: SupabaseClient

    private init() {
        #if DEBUG
        print("[SupabaseService] Initializing Supabase client...")
        print("[SupabaseService]   URL: \(Secrets.supabaseURL)")
        print("[SupabaseService]   Anon Key (prefix): \(String(Secrets.supabaseAnonKey.prefix(30)))...")
        #endif

        guard let url = URL(string: Secrets.supabaseURL) else {
            fatalError("Invalid Supabase URL: \(Secrets.supabaseURL)")
        }

        #if DEBUG
        print("[SupabaseService]   URL parsed successfully: \(url)")
        #endif

        self.client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: Secrets.supabaseAnonKey,
            options: SupabaseClientOptions(
                db: .init(schema: "public"),
                auth: .init(
                    flowType: .pkce,
                    emitLocalSessionAsInitialSession: true
                ),
                global: .init(
                    headers: ["x-app-name": "dispatch-ios"]
                )
            )
        )

        #if DEBUG
        print("[SupabaseService] ✅ SupabaseClient initialized successfully")
        print("[SupabaseService]   DB Schema: public")
        print("[SupabaseService]   Auth Flow: PKCE")
        print("[SupabaseService]   Custom Headers: x-app-name=dispatch-ios")
        #endif
    }
}

// Convenience accessor
internal var supabase: SupabaseClient {
    SupabaseService.shared.client
}
