## Interface Lock

**Feature**: Realtime Error Recovery with User Notification
**Created**: 2026-01-18
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [x] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [ ] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |
| 2.5 | Design bar | jobs-critic, ui-polish |

---

### Contract

- New/changed model fields: None (state lives in RealtimeManager/ChannelLifecycleManager)
- DTO/API changes: None
- State/actions added:
  - `RealtimeConnectionState` enum: `.connected`, `.reconnecting(attempt:)`, `.degraded`
  - `RealtimeManager.connectionState: RealtimeConnectionState` (published)
  - `RealtimeManager.startReconnection()` method
  - `SyncCoordinator.showRealtimeDegraded: Bool` (UI binding)
- Migration required: N

### Acceptance Criteria (3 max)

1. [x] Realtime subscription failures trigger automatic retry with exponential backoff (1s, 2s, 4s, 8s, 16s, max 30s) - reuse existing `RetryPolicy`
2. [x] After 5 consecutive failures (per RetryPolicy.maxRetries), UI shows non-intrusive indicator (sync status area) that realtime is degraded; app continues functioning via polling fallback
3. [x] When network is restored OR realtime reconnects successfully, error state clears automatically and indicator disappears

### Non-goals (prevents scope creep)

- No new dedicated error screen or modal
- No changes to existing SyncStatus enum (we add parallel RealtimeConnectionState)
- No polling fallback implementation in this PR (just indicator + auto-recovery attempts)
- No user-triggerable "reconnect now" button (may add in future)

### Compatibility Plan

- **Backward compatibility**: N/A - internal state only, no persisted data
- **Default when missing**: N/A
- **Rollback strategy**: Revert PR; behavior returns to current silent failure mode

---

### Technical Approach

#### Current State (Problem)

1. `ChannelLifecycleManager.startListening()` catches subscription errors at line 91-97 but only logs and returns
2. `RealtimeManager.startBroadcastListening()` catches subscription errors at line 143-146 but only logs and returns
3. No retry mechanism exists for realtime channel failures
4. No user-visible indication when realtime is not working
5. `SyncStatus` enum handles sync errors but not realtime-specific connection state

#### Proposed Solution

**1. Add RealtimeConnectionState enum** (new file or in RealtimeManager.swift):
```swift
enum RealtimeConnectionState: Equatable {
  case connected
  case reconnecting(attempt: Int, maxAttempts: Int)
  case degraded // exceeded max retries, user should be notified
}
```

**2. Add retry logic to ChannelLifecycleManager**:
- On subscription failure, start reconnection loop using existing `RetryPolicy` (1s, 2s, 4s, 8s, 16s, cap at 30s)
- Track attempt count
- After `RetryPolicy.maxRetries` (5) failures, set state to `.degraded`
- Continue attempting reconnection in background at max interval (30s)

**3. Surface connection state to UI**:
- `RealtimeManager` publishes `connectionState`
- `SyncCoordinator` observes and exposes `showRealtimeDegraded: Bool`
- Existing sync status indicator area shows subtle "realtime unavailable" when degraded

**4. Auto-recovery**:
- When `SyncCoordinator.handleNetworkChange` detects network restored, trigger `RealtimeManager.attemptReconnection()`
- On successful subscription, reset to `.connected` and clear any UI indicator

#### Files to Modify

| File | Changes |
|------|---------|
| `Dispatch/Foundation/Persistence/Sync/ChannelLifecycleManager.swift` | Add retry loop on subscription failure, publish connection state |
| `Dispatch/Foundation/Persistence/Sync/RealtimeManager.swift` | Expose `connectionState`, coordinate with ChannelLifecycleManager, add `attemptReconnection()` |
| `Dispatch/App/State/SyncCoordinator.swift` | Observe realtime state, expose `showRealtimeDegraded`, trigger reconnect on network restore |
| `Dispatch/Foundation/Persistence/Enums/` or inline | Add `RealtimeConnectionState` enum |
| `Dispatch/SharedUI/Components/` (TBD) | Subtle degraded indicator in sync status area |

#### Estimated File Count: 5-6 files

---

### Ownership

- **feature-owner**: End-to-end implementation of retry logic, state management, and UI indicator
- **data-integrity**: Not needed (no schema changes)

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: Supabase Swift realtime channel subscription error handling reconnection retry pattern
CONTEXT7_TAKEAWAYS:
- Use `channel.subscribeWithError()` which throws on failure (vs silent `subscribe()`)
- Monitor connection status via `supabase.realtimeV2.statusChange` async stream
- Status changes: disconnected, connecting, connected
- Use `supabase.removeChannel(channel)` or `channel.unsubscribe()` to clean up
- Handle errors with specific error types from Supabase SDK

CONTEXT7_APPLIED:
- `subscribeWithError()` pattern -> ChannelLifecycleManager.swift:84, 429

CONTEXT7_QUERY: Swift async await Task.sleep retry loop exponential backoff pattern
CONTEXT7_TAKEAWAYS:
- Use `Task.sleep(for: .seconds(delay))` for backoff delays
- Check `Task.isCancelled` in loops for clean cancellation
- Use `try await` with do-catch to handle cancellation during sleep
- Task groups with `withThrowingTaskGroup` for concurrent operations with timeout

CONTEXT7_APPLIED:
- Task.sleep pattern -> ChannelLifecycleManager.swift:404-410
- Task.isCancelled check -> ChannelLifecycleManager.swift:384

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: Supabase Swift (`/supabase/supabase-swift`), Swift (`/swiftlang/swift`)

| Query | Pattern Used |
|-------|--------------|
| Supabase realtime reconnection | `subscribeWithError()` + `statusChange` stream |
| Swift async retry with backoff | `Task.sleep(for:)` + `Task.isCancelled` in while loop |

**N/A**: Only valid for pure refactors with no framework/library usage.

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-18 14:30

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes

RealtimeDegradedIndicator is a well-designed status component:

**Strengths:**
- Minimal component: icon + text + subtle background pill. No unnecessary chrome.
- Uses all DS tokens correctly: DS.Icons.Sync.error, DS.Typography.caption, DS.Colors.Sync.error, DS.Colors.Text.secondary, DS.Colors.Background.secondary, DS.Spacing values.
- Pulsing animation (1.5s easeInOut) is subtle and purposeful - indicates ongoing reconnection.
- Accessibility: Combined element with descriptive label ("Live updates paused. Reconnecting in background.").
- Copy "Live updates paused" is clear, non-technical, human-friendly.
- Positioned consistently with existing OfflineIndicator (bottom-left corner, vertical stack).
- Properly subordinate to main content - does not compete for attention.

**No issues found.** Component meets design bar for a non-intrusive status indicator.

---

### Implementation Notes

**Context7 recommended for**:
- Supabase Realtime reconnection patterns (resolve-library-id for supabase-swift)
- SwiftUI @Published property wrapper patterns for state propagation
- Combine/async stream patterns for monitoring connection state

**Testing requirements**:
- Unit tests for retry logic with mocked subscription failures
- Unit tests for state transitions (connected -> reconnecting -> degraded -> connected)
- Unit tests verifying retry count increment and backoff delays
- Unit tests verifying state clears on successful reconnection

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE

---

### PATCHSET 2 Implementation Notes

**Completed**: 2026-01-18

**Files Created/Modified**:
1. `Dispatch/Design/Shared/Components/RealtimeDegradedIndicator.swift` (NEW) - Subtle UI indicator for degraded realtime state
2. `Dispatch/App/ContentView.swift` - Added indicator display in bottom-left corner with OfflineIndicator
3. `DispatchTests/Sync/RealtimeManagerTests.swift` - Updated MockChannelLifecycleDelegate with connectionStateDidChange
4. `DispatchTests/Persistence/Sync/RealtimeRetryTests.swift` (NEW) - Comprehensive tests for retry logic

**Test Coverage** (38 tests pass):
- RealtimeConnectionStateTests (6 tests) - Enum equality/inequality
- ChannelLifecycleManagerRetryTests (13 tests) - Retry logic, state management, backoff
- SyncCoordinatorRealtimeTests (5 tests) - showRealtimeDegraded binding
- SyncManagerRealtimeStateTests (4 tests) - State storage and propagation
- RealtimeManagerConnectionStateTests (3 tests) - Manager state tests
- BackoffDelayCalculationTests (3 tests) - Exponential backoff math
- StateTransitionSequenceTests (2 tests) - State machine verification

**UI Indicator Design**:
- Uses DS.Icons.Sync.error with pulsing animation
- "Live updates paused" text in DS.Typography.caption
- Positioned in bottom-left corner with OfflineIndicator
- Follows DESIGN_SYSTEM.md patterns
- Non-intrusive, doesn't block user interaction
- Accessibility: Combined element with descriptive label

**Builds Verified**:
- iOS Simulator: PASS
- macOS: PASS
