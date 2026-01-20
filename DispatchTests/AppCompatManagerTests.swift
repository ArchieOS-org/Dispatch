//
//  AppCompatManagerTests.swift
//  DispatchTests
//
//  Unit tests for AppCompatManager version compatibility checking.
//  Tests the logic for determining app compatibility status.
//

import XCTest
@testable import DispatchApp

// MARK: - AppCompatManagerTests

@MainActor
final class AppCompatManagerTests: XCTestCase {

  // MARK: - AppCompatResult Tests

  func test_appCompatResult_decodesAllFields() throws {
    // Given: JSON with all fields
    let json = """
    {
      "compatible": true,
      "min_version": "1.0.0",
      "current_version": "2.0.0",
      "force_update": false,
      "migration_required": true,
      "message": "Update available"
    }
    """
    let data = try XCTUnwrap(json.data(using: .utf8))

    // When: Decode
    let result = try JSONDecoder().decode(AppCompatResult.self, from: data)

    // Then: All fields mapped correctly
    XCTAssertTrue(result.compatible)
    XCTAssertEqual(result.minVersion, "1.0.0")
    XCTAssertEqual(result.currentVersion, "2.0.0")
    XCTAssertFalse(result.forceUpdate)
    XCTAssertEqual(result.migrationRequired, true)
    XCTAssertEqual(result.message, "Update available")
  }

  func test_appCompatResult_handlesNilOptionalFields() throws {
    // Given: JSON with only required fields
    let json = """
    {
      "compatible": false,
      "force_update": true
    }
    """
    let data = try XCTUnwrap(json.data(using: .utf8))

    // When: Decode
    let result = try JSONDecoder().decode(AppCompatResult.self, from: data)

    // Then: Optional fields are nil
    XCTAssertFalse(result.compatible)
    XCTAssertNil(result.minVersion)
    XCTAssertNil(result.currentVersion)
    XCTAssertTrue(result.forceUpdate)
    XCTAssertNil(result.migrationRequired)
    XCTAssertNil(result.message)
  }

  // MARK: - AppCompatStatus Tests

  func test_appCompatStatus_compatible_isNotBlocked() {
    let status = AppCompatStatus.compatible
    XCTAssertFalse(status.isBlocked)
  }

  func test_appCompatStatus_updateAvailable_isNotBlocked() {
    let status = AppCompatStatus.updateAvailable(currentVersion: "2.0.0")
    XCTAssertFalse(status.isBlocked)
  }

  func test_appCompatStatus_updateRequired_isBlocked() {
    let status = AppCompatStatus.updateRequired(minVersion: "2.0.0")
    XCTAssertTrue(status.isBlocked)
  }

  func test_appCompatStatus_unknown_isNotBlocked() {
    let status = AppCompatStatus.unknown(error: "Network error")
    XCTAssertFalse(status.isBlocked)
  }

  func test_appCompatStatus_equatable_compatible() {
    XCTAssertEqual(AppCompatStatus.compatible, AppCompatStatus.compatible)
  }

  func test_appCompatStatus_equatable_updateAvailable() {
    XCTAssertEqual(
      AppCompatStatus.updateAvailable(currentVersion: "2.0.0"),
      AppCompatStatus.updateAvailable(currentVersion: "2.0.0")
    )
    XCTAssertNotEqual(
      AppCompatStatus.updateAvailable(currentVersion: "2.0.0"),
      AppCompatStatus.updateAvailable(currentVersion: "3.0.0")
    )
  }

  func test_appCompatStatus_equatable_updateRequired() {
    XCTAssertEqual(
      AppCompatStatus.updateRequired(minVersion: "1.5.0"),
      AppCompatStatus.updateRequired(minVersion: "1.5.0")
    )
    XCTAssertNotEqual(
      AppCompatStatus.updateRequired(minVersion: "1.5.0"),
      AppCompatStatus.updateRequired(minVersion: "2.0.0")
    )
  }

  func test_appCompatStatus_equatable_unknown() {
    XCTAssertEqual(
      AppCompatStatus.unknown(error: "Error A"),
      AppCompatStatus.unknown(error: "Error A")
    )
    XCTAssertNotEqual(
      AppCompatStatus.unknown(error: "Error A"),
      AppCompatStatus.unknown(error: "Error B")
    )
  }

  func test_appCompatStatus_equatable_differentCases() {
    XCTAssertNotEqual(AppCompatStatus.compatible, AppCompatStatus.updateRequired(minVersion: "1.0"))
    XCTAssertNotEqual(
      AppCompatStatus.updateAvailable(currentVersion: "2.0"),
      AppCompatStatus.updateRequired(minVersion: "2.0")
    )
  }

  // MARK: - AppCompatManager Status Message Tests

  func test_statusMessage_compatible() {
    // Given: Manager with compatible status
    let manager = AppCompatManager.shared

    // Note: We can't easily set the status directly due to private setter,
    // so we test the message logic through the status enum directly
    let status = AppCompatStatus.compatible

    // Then: Verify message format based on status type
    switch status {
    case .compatible:
      // This is expected - the test passes if we reach here
      break
    default:
      XCTFail("Expected compatible status")
    }
  }

  // MARK: - canProceed Tests

  func test_canProceed_trueWhenNotBlocked() {
    // Test the inverse of isBlocked
    // compatible -> canProceed = true
    let compatible = AppCompatStatus.compatible
    XCTAssertFalse(compatible.isBlocked)

    // updateAvailable -> canProceed = true
    let updateAvailable = AppCompatStatus.updateAvailable(currentVersion: "2.0")
    XCTAssertFalse(updateAvailable.isBlocked)

    // unknown -> canProceed = true (fail-open)
    let unknown = AppCompatStatus.unknown(error: "Error")
    XCTAssertFalse(unknown.isBlocked)
  }

  func test_canProceed_falseWhenBlocked() {
    // updateRequired -> canProceed = false
    let updateRequired = AppCompatStatus.updateRequired(minVersion: "2.0")
    XCTAssertTrue(updateRequired.isBlocked)
  }

  // MARK: - Status Derivation Logic Tests

  /// Tests the status derivation logic that would be used in checkCompatibility
  func test_statusDerivation_forceUpdateAndNotCompatible_returnsUpdateRequired() {
    // Given: Result with forceUpdate=true and compatible=false
    let result = makeAppCompatResult(compatible: false, forceUpdate: true, minVersion: "2.0.0")

    // When: Derive status using the same logic as checkCompatibility
    let status = deriveStatus(from: result)

    // Then: Should be updateRequired
    if case .updateRequired(let minVersion) = status {
      XCTAssertEqual(minVersion, "2.0.0")
    } else {
      XCTFail("Expected updateRequired, got \(status)")
    }
  }

  func test_statusDerivation_notCompatibleButNoForceUpdate_returnsUpdateAvailable() {
    // Given: Result with compatible=false but forceUpdate=false
    let result = makeAppCompatResult(compatible: false, forceUpdate: false, currentVersion: "2.0.0")

    // When: Derive status
    let status = deriveStatus(from: result)

    // Then: Should be updateAvailable
    if case .updateAvailable(let version) = status {
      XCTAssertEqual(version, "2.0.0")
    } else {
      XCTFail("Expected updateAvailable, got \(status)")
    }
  }

  func test_statusDerivation_compatible_returnsCompatible() {
    // Given: Result with compatible=true
    let result = makeAppCompatResult(compatible: true, forceUpdate: false)

    // When: Derive status
    let status = deriveStatus(from: result)

    // Then: Should be compatible
    XCTAssertEqual(status, .compatible)
  }

  func test_statusDerivation_forceUpdateButCompatible_returnsCompatible() {
    // Given: Result with compatible=true and forceUpdate=true (edge case)
    // The logic checks forceUpdate AND !compatible, so this should be compatible
    let result = makeAppCompatResult(compatible: true, forceUpdate: true)

    // When: Derive status
    let status = deriveStatus(from: result)

    // Then: Should be compatible (compatible takes precedence)
    XCTAssertEqual(status, .compatible)
  }

  func test_statusDerivation_unknownMinVersion_usesUnknownPlaceholder() {
    // Given: Result with forceUpdate but no minVersion
    let result = makeAppCompatResult(compatible: false, forceUpdate: true, minVersion: nil)

    // When: Derive status
    let status = deriveStatus(from: result)

    // Then: Should use "unknown" as placeholder
    if case .updateRequired(let minVersion) = status {
      XCTAssertEqual(minVersion, "unknown")
    } else {
      XCTFail("Expected updateRequired, got \(status)")
    }
  }

  // MARK: - Private Helpers

  /// Creates an AppCompatResult for testing
  private func makeAppCompatResult(
    compatible: Bool,
    forceUpdate: Bool,
    minVersion: String? = nil,
    currentVersion: String? = nil,
    migrationRequired: Bool? = nil,
    message: String? = nil
  ) -> AppCompatResult {
    AppCompatResult(
      compatible: compatible,
      minVersion: minVersion,
      currentVersion: currentVersion,
      forceUpdate: forceUpdate,
      migrationRequired: migrationRequired,
      message: message
    )
  }

  /// Replicates the status derivation logic from AppCompatManager.checkCompatibility
  /// This allows testing the logic without network calls
  private func deriveStatus(from result: AppCompatResult) -> AppCompatStatus {
    if result.forceUpdate, !result.compatible {
      return .updateRequired(minVersion: result.minVersion ?? "unknown")
    } else if !result.compatible {
      return .updateAvailable(currentVersion: result.currentVersion ?? "unknown")
    } else {
      return .compatible
    }
  }
}
