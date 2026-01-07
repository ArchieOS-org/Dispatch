//
//  AuthManager.swift
//  Dispatch
//
//  Created by DispatchAI on 2025-12-28.
//

import AuthenticationServices
import Combine
import Foundation
import Supabase

@MainActor
final class AuthManager: ObservableObject {

  // MARK: Lifecycle

  private init() {
    Task {
      await restoreSession()
    }
  }

  // MARK: Internal

  static let shared = AuthManager()

  @Published var session: Session?
  @Published var user: User?
  @Published var isLoading = false
  @Published var error: Error?

  /// Derived state
  var isAuthenticated: Bool {
    session != nil
  }

  var currentUserID: UUID? {
    session?.user.id
  }

  func restoreSession() async {
    do {
      session = try await supabase.auth.session
      debugLog.log("Session restored for user: \(session?.user.email ?? "unknown")", category: .auth)
    } catch {
      debugLog.log("No active session found", category: .auth)
    }
  }

  func handleRedirect(_ url: URL) {
    debugLog.log("handleRedirect called with URL: \(url.absoluteString)", category: .auth)
    Task {
      do {
        _ = try await supabase.auth.session(from: url)
        debugLog.log("Session extracted from URL successfully", category: .auth)
        await restoreSession()
      } catch {
        self.error = error
        debugLog.error("Auth redirect failed during session exchange", error: error)
      }
    }
  }

  func signInWithGoogle() async {
    isLoading = true
    error = nil

    do {
      // Native flow: Uses ASWebAuthenticationSession under the hood via Supabase Swift
      // Does NOT use the 'redirectTo' param for iOS apps in the same way as web.
      // The URL Scheme must be registered in Xcode.
      try await supabase.auth.signInWithOAuth(
        provider: .google,
        redirectTo: URL(string: "com.googleusercontent.apps.428022180682-9fm6p0e0l3o8j1bnmf78b5uon8lkhntt://google-auth"),
      )
      // CRITICAL FIX: On iOS, ASWebAuthenticationSession handles the callback internally,
      // so onOpenURL may not fire. We must explicitly refresh the session here.
      await restoreSession()
    } catch {
      self.error = error
      debugLog.error("Google Sign-in failed", error: error)
    }

    isLoading = false
  }

  func signOut() async {
    isLoading = true
    do {
      try await supabase.auth.signOut()
      session = nil
      user = nil
    } catch {
      self.error = error
      debugLog.error("Sign out failed", error: error)
    }
    isLoading = false
  }
}
