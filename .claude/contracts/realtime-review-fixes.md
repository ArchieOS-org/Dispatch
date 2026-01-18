## Interface Lock

**Feature**: Realtime Error Recovery - Code Review Fixes
**Created**: 2026-01-18
**Status**: locked
**Lock Version**: v1
**UI Review Required**: NO

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [x] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [ ] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators (high-risk realtime/sync changes):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |
| 3 | Validation (smoke test) | xcode-pilot |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: `@Published` wrapper for `showRealtimeDegraded` in SyncCoordinator
- Migration required: N

### Review Comments Summary

| # | File | Line | Issue | Severity | Fix | Status |
|---|------|------|-------|----------|-----|--------|
| 1 | SyncCoordinator.swift | 37 | `showRealtimeDegraded` is computed, not reactive | Critical | Make `@Published`, subscribe to SyncManager changes | DONE (PS1) |
| 2 | ChannelLifecycleManager.swift | 356 | `try?` swallows decoding errors | Medium | Add explicit error handling with logging | DONE (PS2) |
| 3 | ChannelLifecycleManager.swift | 362 | Delete events silently dropped on UUID fail | Medium | Log failed UUID extractions | DONE (PS2) |
| 4 | ChannelLifecycleManager.swift | 326 | Premature `.connected` state in `resetAndReconnect` | Medium | Remove line; let `startListening` set state on success | DONE (PS1) |
| 5 | ChannelLifecycleManager.swift | 425 | Race condition in `attemptReconnection` | Medium | Simplify to call `startListening` directly | DONE (PS1) |
| 6 | RealtimeManager.swift | 155 | Broadcast subscription has no retry | Low | Surface broadcast failures (log or callback) | DONE (already logged) |
| 7 | RealtimeManager.swift | 174 | Model context save errors swallowed | Medium | Log save failures | DONE (PS2) |
| 8 | RealtimeRetryTests.swift | 139 | Retry loop never executes in tests | Low | Document limitation or add integration test mode | DONE (PS2) |

### Acceptance Criteria (3 max)

1. Views observing `SyncCoordinator.showRealtimeDegraded` re-render when realtime state changes (Comment #1)
2. Silent failures in realtime event handling are replaced with explicit logging (Comments #2, #3, #6, #7)
3. Race conditions and premature state transitions are eliminated (Comments #4, #5)

### Non-goals (prevents scope creep)

- No retry mechanism for broadcast subscription failures (Comment #6 is logging only, not full retry)
- No testable delay abstraction for retry loop (Comment #8 is documentation, not implementation)
- No new UI components or indicators

### Compatibility Plan

- **Backward compatibility**: N/A (internal implementation fixes)
- **Default when missing**: N/A
- **Rollback strategy**: Revert commit; no data changes

---

### Ownership

- **feature-owner**: Fix all 8 review comments across 4 files
- **data-integrity**: Not needed

---

### Implementation Notes

#### Comment #1 - SwiftUI Reactivity Fix (Critical)

Current code (SyncCoordinator.swift:37):
```swift
var showRealtimeDegraded: Bool {
  syncManager.realtimeConnectionState == .degraded
}
```

Issue: Computed property doesn't trigger SwiftUI re-renders when underlying state changes.

Fix approach:
- Add `@Published private(set) var showRealtimeDegraded = false`
- Subscribe to `syncManager.$realtimeConnectionState` in init
- Update `showRealtimeDegraded` when state changes to/from `.degraded`

Context7 recommended for: Combine publishers with SwiftUI ObservableObject patterns.

#### Comment #2 & #3 - Silent Failure Logging

Add `debugLog.error()` calls when:
- DTO decoding fails (line 356-359)
- UUID extraction fails for delete events (line 362-365)

#### Comment #4 - Premature State

Remove line 326 (`updateConnectionState(.connected)`) from `resetAndReconnect`. The state should only transition to `.connected` after `startListening` successfully subscribes.

#### Comment #5 - Race Condition Simplification

Current `attemptReconnection` (lines 425-446):
1. Creates channel
2. Subscribes
3. Immediately unsubscribes
4. Calls `startListening`

Simplify to:
1. Just call `startListening` directly
2. Check `isListening` result

#### Comment #6 & #7 - Additional Silent Failures

- RealtimeManager.swift:155-158: Log broadcast subscription failure (already logs, consider if retry needed - answer: no, just ensure logging is sufficient)
- RealtimeManager.swift:174: Replace `try?` with `do/catch` and log save failures

#### Comment #8 - Test Coverage Documentation

Add comment to test file explaining:
- Test mode intentionally skips retry loop for deterministic behavior
- Real retry logic is covered by RetryPolicy unit tests
- Integration testing requires live Supabase connection

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: assign(to:) with @Published property publisher subscription pattern memory management
CONTEXT7_TAKEAWAYS:
- `assign` subscriber requires failure type `<Never>` for the pipeline
- Use `.receive(on: RunLoop.main)` for UI thread safety
- `assign(to:on:)` pattern shown for KVO-compliant objects
- `@Published` wrapper creates publisher accessed via `$propertyName`
- Subscription is cancellable and conforms to `Cancellable` protocol

CONTEXT7_APPLIED:
- `.receive(on: RunLoop.main).assign(to: &$showRealtimeDegraded)` -> SyncCoordinator.swift:29-30

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: Combine (via /websites/heckj_github_io_swiftui-notes)

| Query | Pattern Used |
|-------|--------------|
| assign(to:) with @Published property publisher subscription pattern | `$publisher.map {...}.receive(on: RunLoop.main).assign(to: &$property)` |

**Note**: Context7 docs showed `assign(to:on:)` pattern. The `assign(to:)` overload taking inout `Published.Publisher` (iOS 14+) was verified against existing working code in the codebase which already had the fix applied.

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A
**Reviewed**: N/A

UI Review Required is NO - Jobs Critique not applicable for this contract.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE

---

### PATCHSET 2 Completion (Logging/Documentation Fixes)

**Completed**: 2026-01-18
**Status**: All 5 logging/documentation issues resolved

#### Changes Made:

1. **Comment #2 - ChannelLifecycleManager.swift:356** - DTO decoding error logging
   - Replaced `try?` with explicit `do/catch` block
   - Added `debugLog.error("Failed to decode \(String(describing: type))", error: error)`

2. **Comment #3 - ChannelLifecycleManager.swift:364** - Delete event UUID extraction logging
   - Added `else` branch to log failed UUID extractions
   - Added `debugLog.error("Failed to extract UUID from delete event, record: \(action.oldRecord)")`

3. **Comment #6 - RealtimeManager.swift:155** - Broadcast subscription failure
   - Already had logging at line 156: `debugLog.error("Broadcast subscription failed", error: error)`
   - No changes needed

4. **Comment #7 - RealtimeManager.swift:174** - Model context save error logging
   - Replaced `try?` with explicit `do/catch` block
   - Added `debugLog.error("Failed to save model context after broadcast event", error: error)`

5. **Comment #8 - RealtimeRetryTests.swift:139** - Test coverage documentation
   - Added comprehensive documentation comment explaining:
     - Why retry loop is skipped in test mode (deterministic behavior)
     - Current test coverage strategy (RetryPolicy unit tests, state enum tests)
     - Future improvement suggestions (DelayProvider protocol, integration test mode)

#### Test Updates:
- Updated `test_showRealtimeDegraded_trueWhenDegraded` to be async with Combine propagation delay
- Updated `test_showRealtimeDegraded_returnsFalseAfterReconnection` to be async with Combine propagation delay

#### Build/Test Status:
- iOS Simulator build: PASS
- macOS build: PASS
- SwiftLint: 0 violations
- Relevant tests: PASS (some pre-existing flaky tests when run in parallel, pass in isolation)
