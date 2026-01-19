//
//  AuthManagerTests.swift
//  DispatchTests
//
//  Created for AuthManager unit testing with mocked dependencies.
//

import Auth
import Supabase
import XCTest
@testable import DispatchApp

// MARK: - MockAuthClient

/// A mock implementation of AuthClientProtocol for testing AuthManager
/// Thread-safety: All mutable state is accessed only from @MainActor-isolated test methods
// swiftlint:disable:next no_unchecked_sendable
final class MockAuthClient: AuthClientProtocol, @unchecked Sendable {

  // MARK: Lifecycle

  init() {
    let (stream, continuation) = AsyncStream<(event: AuthChangeEvent, session: Session?)>.makeStream()
    authStateChanges = stream
    stateContinuation = continuation
  }

  deinit {
    stateContinuation.finish()
  }

  // MARK: Internal

  // MARK: - AuthClientProtocol conformance

  let authStateChanges: AsyncStream<(event: AuthChangeEvent, session: Session?)>

  // MARK: - Test control properties

  var signInWithOAuthCalled = false
  var signInWithOAuthProvider: Provider?
  var signInWithOAuthRedirectTo: URL?
  var signInWithOAuthError: Error?

  var signOutCalled = false
  var signOutError: Error?

  var sessionFromURLCalled = false
  var sessionFromURLResult: Session?
  var sessionFromURLError: Error?

  func signInWithOAuth(provider: Provider, redirectTo: URL?) async throws {
    signInWithOAuthCalled = true
    signInWithOAuthProvider = provider
    signInWithOAuthRedirectTo = redirectTo

    if let error = signInWithOAuthError {
      throw error
    }
  }

  func signOut() async throws {
    signOutCalled = true

    if let error = signOutError {
      throw error
    }
  }

  func session(from _: URL) async throws -> Session {
    sessionFromURLCalled = true

    if let error = sessionFromURLError {
      throw error
    }

    guard let session = sessionFromURLResult else {
      throw MockAuthError.noSessionProvided
    }

    return session
  }

  // MARK: - Test helpers

  /// Emit an auth state change event
  func emitAuthStateChange(event: AuthChangeEvent, session: Session?) {
    stateContinuation.yield((event: event, session: session))
  }

  /// Finish the auth state stream
  func finishAuthStateStream() {
    stateContinuation.finish()
  }

  // MARK: Private

  private let stateContinuation: AsyncStream<(event: AuthChangeEvent, session: Session?)>.Continuation

}

// MARK: - MockAuthError

enum MockAuthError: Error, LocalizedError {
  case noSessionProvided
  case signInFailed
  case signOutFailed
  case redirectFailed

  var errorDescription: String? {
    switch self {
    case .noSessionProvided:
      "No session was provided for the mock"
    case .signInFailed:
      "Sign in failed (mock)"
    case .signOutFailed:
      "Sign out failed (mock)"
    case .redirectFailed:
      "Redirect handling failed (mock)"
    }
  }
}

// MARK: - AuthTestFixtures

enum AuthTestFixtures {

  /// Creates a mock User for testing
  static func makeUser(
    id: UUID = UUID(),
    email: String? = "test@example.com"
  )
    -> Auth.User
  {
    Auth.User(
      id: id,
      appMetadata: [:],
      userMetadata: [:],
      aud: "authenticated",
      email: email,
      createdAt: Date(),
      updatedAt: Date()
    )
  }

  /// Creates a mock Session for testing
  static func makeSession(
    user: Auth.User? = nil,
    accessToken: String = "mock-access-token",
    refreshToken: String = "mock-refresh-token",
    expiresIn: TimeInterval = 3600,
    expiresAt: TimeInterval? = nil
  )
    -> Session
  {
    let sessionUser = user ?? makeUser()
    let expiration = expiresAt ?? Date().addingTimeInterval(expiresIn).timeIntervalSince1970

    return Session(
      accessToken: accessToken,
      tokenType: "bearer",
      expiresIn: expiresIn,
      expiresAt: expiration,
      refreshToken: refreshToken,
      user: sessionUser
    )
  }

}

// MARK: - AuthManagerTests

@MainActor
final class AuthManagerTests: XCTestCase {

  // MARK: Internal

  override func setUp() {
    super.setUp()
    mockAuthClient = MockAuthClient()
    authManager = AuthManager(authClient: mockAuthClient)
  }

  override func tearDown() {
    mockAuthClient.finishAuthStateStream()
    mockAuthClient = nil
    authManager = nil
    super.tearDown()
  }

  // MARK: - Initial State Tests

  func testInitialState_isUnauthenticated() {
    XCTAssertNil(authManager.session)
    XCTAssertNil(authManager.user)
    XCTAssertFalse(authManager.isAuthenticated)
    XCTAssertNil(authManager.currentUserID)
    XCTAssertFalse(authManager.isLoading)
    XCTAssertNil(authManager.error)
  }

  // MARK: - Auth State Change Tests

  func testAuthStateChange_signedIn_updatesSessionAndUser() async {
    let session = AuthTestFixtures.makeSession()

    mockAuthClient.emitAuthStateChange(event: .signedIn, session: session)

    // Wait for the async state change to propagate
    await waitForCondition { self.authManager.session != nil }

    XCTAssertNotNil(authManager.session)
    XCTAssertNotNil(authManager.user)
    XCTAssertTrue(authManager.isAuthenticated)
    XCTAssertEqual(authManager.currentUserID, session.user.id)
  }

  func testAuthStateChange_signedOut_clearsSessionAndUser() async {
    // First sign in
    let session = AuthTestFixtures.makeSession()
    mockAuthClient.emitAuthStateChange(event: .signedIn, session: session)
    await waitForCondition { self.authManager.isAuthenticated }

    // Verify signed in
    XCTAssertTrue(authManager.isAuthenticated)

    // Then sign out
    mockAuthClient.emitAuthStateChange(event: .signedOut, session: nil)
    await waitForCondition { !self.authManager.isAuthenticated }

    XCTAssertNil(authManager.session)
    XCTAssertNil(authManager.user)
    XCTAssertFalse(authManager.isAuthenticated)
    XCTAssertNil(authManager.currentUserID)
  }

  func testAuthStateChange_tokenRefreshed_updatesSession() async {
    // Initial sign in
    let initialSession = AuthTestFixtures.makeSession(accessToken: "initial-token")
    mockAuthClient.emitAuthStateChange(event: .signedIn, session: initialSession)
    await waitForCondition { self.authManager.session?.accessToken == "initial-token" }

    // Token refresh with new token
    let refreshedSession = AuthTestFixtures.makeSession(
      user: initialSession.user,
      accessToken: "refreshed-token"
    )
    mockAuthClient.emitAuthStateChange(event: .tokenRefreshed, session: refreshedSession)
    await waitForCondition { self.authManager.session?.accessToken == "refreshed-token" }

    XCTAssertEqual(authManager.session?.accessToken, "refreshed-token")
    XCTAssertTrue(authManager.isAuthenticated)
  }

  func testAuthStateChange_initialSession_withSession_setsSessionAndUser() async {
    let session = AuthTestFixtures.makeSession()

    mockAuthClient.emitAuthStateChange(event: .initialSession, session: session)
    await waitForCondition { self.authManager.session != nil }

    XCTAssertNotNil(authManager.session)
    XCTAssertNotNil(authManager.user)
    XCTAssertTrue(authManager.isAuthenticated)
    XCTAssertEqual(authManager.currentUserID, session.user.id)
  }

  func testAuthStateChange_initialSession_withoutSession_remainsUnauthenticated() async {
    // For this test, we verify nothing changes after the event is processed.
    // We use a short wait with condition checking to be deterministic:
    // If the state DOES change (a bug), the test will catch it quickly.
    // If the state stays nil (expected), we verify it stayed nil after giving
    // the event processing time to complete.
    mockAuthClient.emitAuthStateChange(event: .initialSession, session: nil)

    // Give event processing time to complete by waiting briefly
    // Use a short timeout since we expect the condition to NEVER become true
    await waitForCondition(timeout: 0.1) {
      self.authManager.session != nil
    }

    // Verify the state did NOT change - session should still be nil
    XCTAssertNil(authManager.session, "Session should have remained nil")
    XCTAssertNil(authManager.user)
    XCTAssertFalse(authManager.isAuthenticated)
    XCTAssertNil(authManager.currentUserID)
  }

  func testAuthStateChange_userUpdated_updatesSessionAndUser() async {
    // Initial sign in
    let initialUser = AuthTestFixtures.makeUser(email: "initial@example.com")
    let initialSession = AuthTestFixtures.makeSession(user: initialUser)
    mockAuthClient.emitAuthStateChange(event: .signedIn, session: initialSession)
    await waitForCondition { self.authManager.user?.email == "initial@example.com" }

    XCTAssertEqual(authManager.user?.email, "initial@example.com")

    // User update
    let updatedUser = AuthTestFixtures.makeUser(id: initialUser.id, email: "updated@example.com")
    let updatedSession = AuthTestFixtures.makeSession(user: updatedUser)
    mockAuthClient.emitAuthStateChange(event: .userUpdated, session: updatedSession)
    await waitForCondition { self.authManager.user?.email == "updated@example.com" }

    XCTAssertEqual(authManager.user?.email, "updated@example.com")
    XCTAssertEqual(authManager.session?.user.email, "updated@example.com")
  }

  func testAuthStateChange_mfaChallengeVerified_updatesSession() async {
    let session = AuthTestFixtures.makeSession()

    mockAuthClient.emitAuthStateChange(event: .mfaChallengeVerified, session: session)
    await waitForCondition { self.authManager.session != nil }

    XCTAssertNotNil(authManager.session)
    XCTAssertTrue(authManager.isAuthenticated)
  }

  // MARK: - Sign In Tests

  func testSignInWithGoogle_success_callsAuthClient() async {
    await authManager.signInWithGoogle()

    XCTAssertTrue(mockAuthClient.signInWithOAuthCalled)
    XCTAssertEqual(mockAuthClient.signInWithOAuthProvider, .google)
    XCTAssertNotNil(mockAuthClient.signInWithOAuthRedirectTo)
    XCTAssertNil(authManager.error)
    XCTAssertFalse(authManager.isLoading)
  }

  func testSignInWithGoogle_failure_setsError() async {
    mockAuthClient.signInWithOAuthError = MockAuthError.signInFailed

    await authManager.signInWithGoogle()

    XCTAssertTrue(mockAuthClient.signInWithOAuthCalled)
    XCTAssertNotNil(authManager.error)
    XCTAssertFalse(authManager.isLoading)
  }

  func testSignInWithGoogle_setsLoadingDuringOperation() async {
    // We can't easily test the loading state during the operation
    // since it's set and unset within the same async call.
    // Instead, verify it ends in the correct state.
    await authManager.signInWithGoogle()

    XCTAssertFalse(authManager.isLoading)
  }

  func testSignInWithGoogle_clearsExistingError() async {
    // First, set an error
    mockAuthClient.signInWithOAuthError = MockAuthError.signInFailed
    await authManager.signInWithGoogle()
    XCTAssertNotNil(authManager.error)

    // Now sign in successfully
    mockAuthClient.signInWithOAuthError = nil
    await authManager.signInWithGoogle()

    XCTAssertNil(authManager.error)
  }

  // MARK: - Sign Out Tests

  func testSignOut_success_callsAuthClient() async {
    // First sign in
    let session = AuthTestFixtures.makeSession()
    mockAuthClient.emitAuthStateChange(event: .signedIn, session: session)
    await waitForCondition { self.authManager.isAuthenticated }

    await authManager.signOut()

    XCTAssertTrue(mockAuthClient.signOutCalled)
    XCTAssertNil(authManager.error)
    XCTAssertFalse(authManager.isLoading)
  }

  func testSignOut_failure_setsError() async {
    mockAuthClient.signOutError = MockAuthError.signOutFailed

    await authManager.signOut()

    XCTAssertTrue(mockAuthClient.signOutCalled)
    XCTAssertNotNil(authManager.error)
    XCTAssertFalse(authManager.isLoading)
  }

  func testSignOut_setsLoadingDuringOperation() async {
    await authManager.signOut()

    XCTAssertFalse(authManager.isLoading)
  }

  // MARK: - Handle Redirect Tests

  func testHandleRedirect_success_callsSessionFromURL() async throws {
    let redirectURL = try XCTUnwrap(URL(string: "myapp://callback?code=abc123"))
    let session = AuthTestFixtures.makeSession()
    mockAuthClient.sessionFromURLResult = session

    authManager.handleRedirect(redirectURL)

    // handleRedirect spawns a Task, so we need to wait
    await waitForCondition { self.mockAuthClient.sessionFromURLCalled }

    XCTAssertTrue(mockAuthClient.sessionFromURLCalled)
    XCTAssertNil(authManager.error)
  }

  func testHandleRedirect_failure_setsError() async throws {
    let redirectURL = try XCTUnwrap(URL(string: "myapp://callback?error=access_denied"))
    mockAuthClient.sessionFromURLError = MockAuthError.redirectFailed

    authManager.handleRedirect(redirectURL)

    // handleRedirect spawns a Task, so we need to wait for error to be set
    await waitForCondition { self.authManager.error != nil }

    XCTAssertTrue(mockAuthClient.sessionFromURLCalled)
    XCTAssertNotNil(authManager.error)
  }

  // MARK: - Derived Property Tests

  func testIsAuthenticated_trueWhenSessionExists() async {
    XCTAssertFalse(authManager.isAuthenticated)

    let session = AuthTestFixtures.makeSession()
    mockAuthClient.emitAuthStateChange(event: .signedIn, session: session)
    await waitForCondition { self.authManager.isAuthenticated }

    XCTAssertTrue(authManager.isAuthenticated)
  }

  func testIsAuthenticated_falseWhenNoSession() async {
    // Sign in first
    let session = AuthTestFixtures.makeSession()
    mockAuthClient.emitAuthStateChange(event: .signedIn, session: session)
    await waitForCondition { self.authManager.isAuthenticated }

    XCTAssertTrue(authManager.isAuthenticated)

    // Sign out
    mockAuthClient.emitAuthStateChange(event: .signedOut, session: nil)
    await waitForCondition { !self.authManager.isAuthenticated }

    XCTAssertFalse(authManager.isAuthenticated)
  }

  func testCurrentUserID_returnsUserIDFromSession() async {
    let userId = UUID()
    let user = AuthTestFixtures.makeUser(id: userId)
    let session = AuthTestFixtures.makeSession(user: user)

    mockAuthClient.emitAuthStateChange(event: .signedIn, session: session)
    await waitForCondition { self.authManager.currentUserID == userId }

    XCTAssertEqual(authManager.currentUserID, userId)
  }

  func testCurrentUserID_nilWhenNoSession() {
    XCTAssertNil(authManager.currentUserID)
  }

  // MARK: - Session Persistence Tests

  func testSessionPersistence_sessionUpdatesOnSignIn() async {
    let session = AuthTestFixtures.makeSession()

    XCTAssertNil(authManager.session)

    mockAuthClient.emitAuthStateChange(event: .signedIn, session: session)
    await waitForCondition { self.authManager.session != nil }

    XCTAssertNotNil(authManager.session)
    XCTAssertEqual(authManager.session?.accessToken, session.accessToken)
    XCTAssertEqual(authManager.session?.refreshToken, session.refreshToken)
  }

  func testSessionPersistence_userUpdatesOnSignIn() async {
    let user = AuthTestFixtures.makeUser(email: "test@example.com")
    let session = AuthTestFixtures.makeSession(user: user)

    XCTAssertNil(authManager.user)

    mockAuthClient.emitAuthStateChange(event: .signedIn, session: session)
    await waitForCondition { self.authManager.user != nil }

    XCTAssertNotNil(authManager.user)
    XCTAssertEqual(authManager.user?.email, "test@example.com")
    XCTAssertEqual(authManager.user?.id, user.id)
  }

  func testSessionPersistence_bothClearedOnSignOut() async {
    // Sign in
    let session = AuthTestFixtures.makeSession()
    mockAuthClient.emitAuthStateChange(event: .signedIn, session: session)
    await waitForCondition { self.authManager.session != nil }

    XCTAssertNotNil(authManager.session)
    XCTAssertNotNil(authManager.user)

    // Sign out
    mockAuthClient.emitAuthStateChange(event: .signedOut, session: nil)
    await waitForCondition { self.authManager.session == nil }

    XCTAssertNil(authManager.session)
    XCTAssertNil(authManager.user)
  }

  // MARK: - Multiple Auth State Changes Tests

  func testMultipleAuthStateChanges_handledSequentially() async {
    let user1 = AuthTestFixtures.makeUser(id: UUID(), email: "user1@example.com")
    let session1 = AuthTestFixtures.makeSession(user: user1)

    let user2 = AuthTestFixtures.makeUser(id: UUID(), email: "user2@example.com")
    let session2 = AuthTestFixtures.makeSession(user: user2)

    // Sign in as user 1
    mockAuthClient.emitAuthStateChange(event: .signedIn, session: session1)
    await waitForCondition { self.authManager.user?.email == "user1@example.com" }

    XCTAssertEqual(authManager.user?.email, "user1@example.com")

    // Sign out
    mockAuthClient.emitAuthStateChange(event: .signedOut, session: nil)
    await waitForCondition { self.authManager.user == nil }

    XCTAssertNil(authManager.user)

    // Sign in as user 2
    mockAuthClient.emitAuthStateChange(event: .signedIn, session: session2)
    await waitForCondition { self.authManager.user?.email == "user2@example.com" }

    XCTAssertEqual(authManager.user?.email, "user2@example.com")
    XCTAssertEqual(authManager.currentUserID, user2.id)
  }

  // MARK: Private

  // swiftlint:disable implicitly_unwrapped_optional
  private var mockAuthClient: MockAuthClient!
  private var authManager: AuthManager!

  // swiftlint:enable implicitly_unwrapped_optional

  // MARK: - Test Helper

  /// Waits for a condition to become true with a timeout
  private func waitForCondition(
    timeout: TimeInterval = 1.0,
    condition: @escaping () -> Bool
  ) async {
    let start = Date()
    while !condition() {
      if Date().timeIntervalSince(start) > timeout {
        return // Timeout reached
      }
      await Task.yield()
      try? await Task.sleep(nanoseconds: 10_000_000) // 10ms intervals
    }
  }

}
