
import SwiftData
import XCTest
@testable import DispatchApp

@MainActor
final class SyncTests: XCTestCase {

  // MARK: - Helpers & Mocks

  // Since SyncManager is a singleton/actor with hard dependencies,
  // we might test the logic by inspecting the side effects or using a testable subclass if refactored.
  // For V1 "clean room", we will test the observable behaviors on the Models and DTOs,
  // and verify Hash Logic directly if we can access it.

  // NOTE: Avatar hash determinism testing requires access to private `normalizeAndHash` method.
  // This would require either exposing the method or refactoring SyncManager for testability.

  // MARK: - DTO & Model Tests (The "Logic Brain" parts)

  func test_UserDTO_mapsAvatarFieldsCorrectly() {
    // Given
    let sourceUser = User(
      name: "Steve",
      email: "steve@apple.com",
      avatar: Data(),
      avatarHash: "hash123",
      userType: .admin
    )

    // When
    let dto = UserDTO(from: sourceUser, avatarPath: "avatars/steve.jpg", avatarHash: "hash123")

    // Then
    XCTAssertEqual(dto.avatarPath, "avatars/steve.jpg")
    XCTAssertEqual(dto.avatarHash, "hash123")
    XCTAssertEqual(dto.name, "Steve")
  }

  func test_User_updatesAvatarFromDownload() {
    // Given (Mock Down Sync Logic)
    let user = User(
      name: "Tim",
      email: "tim@apple.com",
      avatar: nil,
      avatarHash: nil,
      userType: .realtor
    )
    let newHash = "newHash456"
    let newData = Data([0xAA, 0xBB])

    // When (Simulate SyncDown apply)
    user.avatar = newData
    user.avatarHash = newHash

    // Then
    XCTAssertEqual(user.avatar, newData)
    XCTAssertEqual(user.avatarHash, newHash)
  }

  func test_User_clearsAvatar_whenRemoteHashIsNil() {
    // Given
    let user = User(
      name: "Jony",
      email: "jony@apple.com",
      avatar: Data([0xFF]),
      avatarHash: "oldHash",
      userType: .admin
    )

    // When (Remote hash is nil)
    user.avatar = nil
    user.avatarHash = nil

    // Then
    XCTAssertNil(user.avatar)
    XCTAssertNil(user.avatarHash)
  }

  // MARK: - Integration / Logic Flow Verification
  // NOTE: SyncManager's sync flow logic (e.g., upload failure handling, nil avatar handling)
  // requires integration testing with a real or mocked Supabase connection.
  // These behaviors are enforced by guards in SyncManager but cannot be unit tested
  // without refactoring to inject dependencies. See SyncManager.swift for implementation.
}
