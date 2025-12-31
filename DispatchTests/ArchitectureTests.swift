//
//  ArchitectureTests.swift
//  DispatchTests
//
//  Created to enforce Jobs Standard architectural invariants.
//

import XCTest

final class ArchitectureTests: XCTestCase {
    
    // Jobs Standard: "No shared singleton in Views/Tests"
    // We strictly enforce that SyncManager.shared is NOT used in UI code.
    // Dependencies must be injected via @EnvironmentObject.
    func testNoSharedUsageInViews() throws {
        // 1. Locate Repo Root from this file's path
        let fileURL = URL(fileURLWithPath: #filePath)
        let testsDir = fileURL.deletingLastPathComponent() // DispatchTests
        let repoRoot = testsDir.deletingLastPathComponent() // Dispatch
        
        let viewsDir = repoRoot.appendingPathComponent("Dispatch/Views")
        
        // 2. Define Forbidden Pattern
        // Construct it piece-meal so this test doesn't fail itself
        let forbidden = "SyncManager" + "." + "shared"
        
        // 3. Scan
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: viewsDir.path) else {
            XCTFail("Could not find Views directory at expected path: \(viewsDir.path). Check repo structure.")
            return
        }
        
        let enumerator = fileManager.enumerator(at: viewsDir, includingPropertiesForKeys: nil)
        var violations: [String] = []
        
        while let file = enumerator?.nextObject() as? URL {
            if file.pathExtension == "swift" {
                let content = try String(contentsOf: file, encoding: .utf8)
                if content.contains(forbidden) {
                    // Extract relative path for cleaner error message
                    let relativePath = file.path.replacingOccurrences(of: repoRoot.path, with: "")
                    violations.append(relativePath)
                }
            }
        }
        
        // 4. Assert
        if !violations.isEmpty {
            XCTFail("""
            🚨 ARCHITECTURE VIOLATION: Found usage of '\(forbidden)' in Views.
            This violates the Jobs Standard for testability and preview isolation.
            Inject SyncManager via EnvironmentObject instead.
            
            Violating Files:
            \(violations.joined(separator: "\n"))
            """)
        }
    }
}
