//
//  BindingPatternTests.swift
//  DispatchTests
//
//  Enforces safe Binding patterns to prevent "Publishing changes from within
//  view updates is not allowed" runtime warnings.
//

import XCTest

final class BindingPatternTests: XCTestCase {

  // MARK: Internal

  /// Scans source files for Binding setters that synchronously call dispatch()
  /// or mutate appState without a Task { } wrapper.
  ///
  /// The safe pattern defers mutations to the next run loop:
  ///
  /// ```swift
  /// Binding(
  ///   get: { appState.value },
  ///   set: { newValue in
  ///     Task { @MainActor in
  ///       appState.dispatch(.setValue(newValue))
  ///     }
  ///   }
  /// )
  /// ```
  func testNoSynchronousBindingMutations() throws {
    // 1. Locate Repo Root from this file's path
    let fileURL = URL(fileURLWithPath: #filePath)
    let testsDir = fileURL.deletingLastPathComponent() // DispatchTests
    let repoRoot = testsDir.deletingLastPathComponent() // Dispatch

    let sourceDir = repoRoot.appendingPathComponent("Dispatch")

    // 2. Scan all Swift files
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: sourceDir.path) else {
      XCTFail("Could not find source directory at expected path: \(sourceDir.path)")
      return
    }

    var violations: [(file: String, line: Int, context: String)] = []

    let enumerator = fileManager.enumerator(at: sourceDir, includingPropertiesForKeys: nil)

    while let file = enumerator?.nextObject() as? URL {
      guard file.pathExtension == "swift" else { continue }

      let content: String
      do {
        content = try String(contentsOf: file, encoding: .utf8)
      } catch {
        continue // Skip files that can't be read
      }

      // Find violations in this file
      let fileViolations = findBindingViolations(in: content, filePath: file.path)

      for (line, context) in fileViolations {
        let relativePath = file.path.replacingOccurrences(of: repoRoot.path, with: "")
        violations.append((file: relativePath, line: line, context: context))
      }
    }

    // 3. Assert
    if !violations.isEmpty {
      let violationList = violations.map { "\($0.file):\($0.line) - \($0.context)" }
        .joined(separator: "\n")

      XCTFail("""
        BINDING PATTERN VIOLATION: Found synchronous mutations in Binding setters.

        This causes SwiftUI runtime warnings:
        "Publishing changes from within view updates is not allowed"

        FIX: Wrap dispatch() or appState mutations in Task { @MainActor in ... }

        Violations found:
        \(violationList)
        """)
    }
  }

  // MARK: - Allowed Exceptions

  /// Documents allowed exceptions where synchronous Binding mutations are safe.
  /// Currently: none. All Binding setters with dispatch/appState must use Task.
  func testAllowedExceptionsDocumented() {
    // This test documents that there are NO allowed exceptions.
    // If an exception is ever needed, document it here with justification.
    //
    // Example of how to document an exception:
    // let allowedExceptions = [
    //   "SomeView.swift:42": "Local @State mutation, not AppState"
    // ]
    //
    // For now, all cases must use Task { @MainActor in ... }

    let allowedExceptions: [String: String] = [:]
    XCTAssertTrue(allowedExceptions.isEmpty, "All exceptions must be justified in code comments")
  }

  // MARK: Private

  /// Parses content to find Binding setters with synchronous dispatch/appState mutations.
  /// Returns array of (lineNumber, context) tuples.
  private func findBindingViolations(in content: String, filePath _: String) -> [(Int, String)] {
    var violations: [(Int, String)] = []
    let lines = content.components(separatedBy: .newlines)

    // Track state while scanning
    var inBinding = false
    var inSetClosure = false
    var bindingStartLine = 0
    var braceDepth = 0
    var setCloseDepth = 0
    var hasTaskWrapper = false
    var hasDangerousCall = false
    var dangerousContext = ""

    for (index, line) in lines.enumerated() {
      let lineNumber = index + 1
      let trimmed = line.trimmingCharacters(in: .whitespaces)

      // Detect start of Binding(
      if trimmed.contains("Binding(") || trimmed.contains("Binding (") {
        inBinding = true
        bindingStartLine = lineNumber
        braceDepth = 0
        inSetClosure = false
        hasTaskWrapper = false
        hasDangerousCall = false
        dangerousContext = ""
      }

      guard inBinding else { continue }

      // Track brace depth
      for char in line {
        if char == "{" {
          braceDepth += 1
        } else if char == "}" {
          braceDepth -= 1
        }
      }

      // Detect set: closure start
      if trimmed.contains("set:") && trimmed.contains("{") {
        inSetClosure = true
        setCloseDepth = braceDepth
      }

      if inSetClosure {
        // Check for Task { pattern (the safe wrapper)
        if trimmed.contains("Task {") || trimmed.contains("Task{") {
          hasTaskWrapper = true
        }

        // Check for dangerous patterns
        if trimmed.contains("dispatch(") || trimmed.contains(".dispatch(") {
          hasDangerousCall = true
          dangerousContext = "dispatch() call"
        }
        if trimmed.contains("appState."), !trimmed.contains("appState.lensState") {
          // appState.lensState access in getter is fine; direct mutations are not
          if
            trimmed.contains("appState.dispatch") ||
            (trimmed.contains("appState.") && trimmed.contains("="))
          {
            hasDangerousCall = true
            dangerousContext = "appState mutation"
          }
        }

        // Check if set closure has closed
        if braceDepth < setCloseDepth {
          inSetClosure = false
        }
      }

      // Detect end of Binding (closing paren at depth 0, or explicit pattern)
      //
      // NOTE: This detection logic has known limitations:
      // - Comments containing ")" may trigger false positives
      // - Multi-line expressions with unbalanced parens on a single line may cause issues
      // - Deeply nested closures within Binding setters may not be fully analyzed
      //
      // For authoritative validation, the shell script `scripts/check_binding_patterns.sh`
      // uses Perl recursive regex which properly handles these edge cases.
      // This test serves as a secondary validation layer in the unit test suite.
      let bindingEnded = (braceDepth == 0 && trimmed.contains(")")) ||
        (trimmed == ")" || trimmed == "),")

      if bindingEnded, inBinding {
        // Evaluate: violation if dangerous call without Task wrapper
        if hasDangerousCall, !hasTaskWrapper {
          violations.append((bindingStartLine, dangerousContext))
        }

        // Reset state
        inBinding = false
        inSetClosure = false
      }
    }

    return violations
  }

}
