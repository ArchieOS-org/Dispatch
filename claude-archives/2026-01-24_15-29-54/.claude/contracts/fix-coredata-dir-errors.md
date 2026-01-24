## Interface Lock

**Feature**: Fix CoreData/SwiftData Directory Startup Errors
**Created**: 2026-01-19
**Status**: DONE
**Lock Version**: v1
**UI Review Required**: NO

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [ ] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators (none checked - simple fix):

| Patchset | Gate | Agents | Status |
|----------|------|--------|--------|
| 1 | Compiles | feature-owner | COMPLETE |
| 2 | Tests pass, criteria met | feature-owner, integrator | COMPLETE |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

### Problem Statement

When the app starts, CoreData logs verbose errors because the `Application Support` directory doesn't exist initially. SwiftData recovers automatically, but logs noisy errors like:
- "Failed to stat path '.../Library/Application Support/default.store'"
- "Failed to create file; code = 2"
- "Recovery attempt...was successful!"

**Root Cause**: `DispatchApp.swift` initializes `ModelConfiguration` without pre-creating the Application Support directory. SwiftData eventually creates it during recovery, but logs errors first.

### Acceptance Criteria (3 max)

1. No CoreData "Failed to stat path" or "Failed to create file" errors on app startup
2. Application Support directory is pre-created before ModelContainer initialization
3. Fix only applies to persistent storage mode (not in-memory UI testing mode)

### Non-goals (prevents scope creep)

- No changes to SwiftData schema or model definitions
- No changes to UI testing mode behavior
- No changes to sync or data layer

### Compatibility Plan

- **Backward compatibility**: N/A - no data format changes
- **Default when missing**: N/A
- **Rollback strategy**: Remove directory pre-creation code; SwiftData will continue to self-recover (just with log noise)

---

### Ownership

- **feature-owner**: Pre-create Application Support directory in sharedModelContainer before ModelConfiguration init
- **data-integrity**: Not needed (no schema changes)

---

### Implementation Notes

**File**: `Dispatch/App/DispatchApp.swift`
**Location**: `sharedModelContainer` property (lines 42-49)

**Pattern**:
```swift
// Ensure Application Support directory exists (prevents CoreData startup errors)
// Only needed for persistent storage, not in-memory (UI testing) mode
if !isUITesting {
  let fileManager = FileManager.default
  if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
    try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
  }
}
```

**Key decisions**:
- Use `try?` to silently handle failures (directory may already exist)
- Use `withIntermediateDirectories: true` to create parent directories if needed
- Skip for UI testing mode since in-memory storage doesn't need directory

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: FileManager createDirectory withIntermediateDirectories best practices error handling
CONTEXT7_TAKEAWAYS:
- Swift error handling uses do-catch for recoverable errors
- Errors propagate automatically with `try` keyword
- `try!` asserts call won't throw (crashes if it does)
CONTEXT7_APPLIED:
- General error handling patterns -> verified approach

CONTEXT7_QUERY: try? convert throwing function to optional nil error handling
CONTEXT7_TAKEAWAYS:
- Swift uses `try?` to convert errors to nil (returns Optional)
- Use `try?` when failure is acceptable and you want to ignore the error
- `try!` is unsafe and crashes on error; `try?` is safe
CONTEXT7_APPLIED:
- `try?` for directory creation -> DispatchApp.swift:47

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: Swift (/swiftlang/swift)

| Query | Pattern Used |
|-------|--------------|
| FileManager createDirectory error handling | `try?` to silently ignore errors |
| try? convert throwing to optional | Verified pattern is correct for "fire and forget" directory creation |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A
**Reviewed**: N/A

Not applicable - no UI changes (UI Review Required: NO)

---

### Integrator Verification (PATCHSET 2)

**Date**: 2026-01-19
**Verified by**: integrator

**Build Results**:
- iOS Simulator (iPhone 17): PASS
- macOS: PASS

**Contract Verification**:
- Context7 Attestation: YES (verified)
- UI Review Required: NO (Jobs Critique skipped correctly)
- PATCHSET 1: COMPLETE
- PATCHSET 2: COMPLETE

**Implementation Verified**:
- Fix present in `Dispatch/App/DispatchApp.swift` at lines 42-49
- Pre-creates Application Support directory before ModelConfiguration
- Skips for UI testing mode (in-memory storage)
- Uses `try?` for silent error handling

---

**IMPORTANT**:
- `UI Review Required: NO` - Jobs Critique section is not required; integrator skips this check
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
