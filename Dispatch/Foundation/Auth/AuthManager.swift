//
//  AuthManager.swift
//  Dispatch
//
//  Created by DispatchAI on 2025-12-28.
//

import Auth
import AuthenticationServices
import Combine
import Foundation
import Supabase

@MainActor
final class AuthManager: ObservableObject {

  // MARK: Lifecycle

  private init() {
    startAuthStateListener()
  }

  deinit {
    authStateTask?.cancel()
  }

  // MARK: Internal

  static let shared = AuthManager()

  @Published var session: Session?
  @Published var user: Auth.User?
  @Published var isLoading = false
  @Published var error: Error?

  /// Derived state
  var isAuthenticated: Bool {
    session != nil
  }

  var currentUserID: UUID? {
    session?.user.id
  }

  func handleRedirect(_ url: URL) {
    debugLog.log("handleRedirect called with URL: \(url.absoluteString)", category: .auth)
    Task {
      do {
        let session = try await supabase.auth.session(from: url)
        debugLog.log(
          "Session extracted from URL successfully for user: \(session.user.email ?? "unknown")",
          category: .auth
        )
        // Note: authStateChanges stream will automatically pick up this session change
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
        redirectTo: URL(string: "com.googleusercontent.apps.428022180682-9fm6p0e0l3o8j1bnmf78b5uon8lkhntt://google-auth")
      )
      // Note: authStateChanges stream will automatically update session state
      debugLog.log("Google OAuth flow completed, waiting for auth state update", category: .auth)
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
      // Note: authStateChanges stream will automatically clear session/user state
      debugLog.log("Sign out completed, waiting for auth state update", category: .auth)
    } catch {
      self.error = error
      debugLog.error("Sign out failed", error: error)
    }
    isLoading = false
  }

  // MARK: Private

  private var authStateTask: Task<Void, Never>?

  private func startAuthStateListener() {
    authStateTask?.cancel()
    authStateTask = Task {
      for await (event, session) in supabase.auth.authStateChanges {
        await handleAuthStateChange(event: event, newSession: session)
      }
    }
  }

  private func handleAuthStateChange(event: AuthChangeEvent, newSession: Session?) async {
    switch event {
    case .initialSession:
      session = newSession
      if let validSession = newSession {
        user = validSession.user
        debugLog.log(
          "Initial session loaded for user: \(validSession.user.email ?? "unknown")",
          category: .auth
        )
      } else {
        user = nil
        debugLog.log("No initial session found", category: .auth)
      }

    case .signedIn:
      session = newSession
      if let validSession = newSession {
        user = validSession.user
        debugLog.log("User signed in: \(validSession.user.email ?? "unknown")", category: .auth)
      }

    case .signedOut:
      session = nil
      user = nil
      debugLog.log("User signed out", category: .auth)

    case .tokenRefreshed:
      session = newSession
      if let validSession = newSession {
        debugLog.log("Token refreshed for user: \(validSession.user.email ?? "unknown")", category: .auth)
      }

    case .userUpdated:
      session = newSession
      if let validSession = newSession {
        user = validSession.user
        debugLog.log("User updated: \(validSession.user.email ?? "unknown")", category: .auth)
      }

    case .passwordRecovery:
      debugLog.log("Password recovery initiated", category: .auth)

    case .mfaChallengeVerified:
      session = newSession
      debugLog.log("MFA challenge verified", category: .auth)

    @unknown default:
      debugLog.log("Unknown auth event received", category: .auth)
    }
  }

}
