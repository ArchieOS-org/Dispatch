## Interface Lock

**Feature**: Split RealtimeManager God Object
**Created**: 2026-01-17
**Status**: DONE
**Lock Version**: v1
**UI Review Required**: NO
**Completed**: 2026-01-17 (PATCHSET 1+2 combined)

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [ ] **Unfamiliar area** (adds dispatch-explorer)

**Note**: This is an internal refactor with no schema, UI, or API changes. Standard 2-patchset plan with intermediate milestone.

### Patchset Plan

| Patchset | Gate | Agents | Details |
|----------|------|--------|---------|
| 1 | Compiles | feature-owner | Extract BroadcastEventParser + ChannelLifecycleManager |
| 2 | Tests pass, criteria met | feature-owner, integrator | RealtimeManager coordinator + RealtimeManagerTests.swift |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None (internal refactor)
- Migration required: N

### Extractions Required

#### 1. BroadcastEventParser

**Location**: `Dispatch/Foundation/Persistence/Sync/BroadcastEventParser.swift`

**Responsibility**: Event parsing and DTO routing

**Methods to extract** (from RealtimeManager lines 450-679):
- `handleBroadcastEvent(_:container:)` - main event router
- `handleTaskBroadcast(payload:context:)`
- `handleActivityBroadcast(payload:context:)`
- `handleListingBroadcast(payload:context:)`
- `handleUserBroadcast(payload:context:)`
- `handleNoteBroadcast(payload:context:)`

**Protocol**: Define `BroadcastEventParserDelegate` for DTO delivery (mirrors existing delegate pattern)

**Target**: < 300 lines

#### 2. ChannelLifecycleManager

**Location**: `Dispatch/Foundation/Persistence/Sync/ChannelLifecycleManager.swift`

**Responsibility**: Channel state management (subscribe, unsubscribe, reconnect)

**Methods to extract** (from RealtimeManager lines 91-359):
- `startListening()` - channel setup and subscription
- `stopListening()` - channel teardown
- `startBroadcastListening()` - broadcast channel setup
- `cancelAllTasks()` / `awaitAllTasks()` / `clearTaskReferences()` - task lifecycle
- All postgres_changes stream handlers (lines 174-292)
- All Task references (lines 75-86)

**Protocol**: Define `ChannelLifecycleDelegate` for state change notifications

**Target**: < 300 lines

#### 3. RealtimeManager (Coordinator)

**Location**: `Dispatch/Foundation/Persistence/Sync/RealtimeManager.swift` (refactored)

**Responsibility**: Coordinates BroadcastEventParser and ChannelLifecycleManager

**Retains**:
- `RealtimeManagerDelegate` protocol (public API)
- Mode and feature flag properties
- Helper methods: `mapRealtimeStatus()`, `extractUUID()`

**Target**: < 300 lines

### Acceptance Criteria (3 max)

1. BroadcastEventParser handles all event parsing and DTO routing, < 300 lines
2. ChannelLifecycleManager handles all channel state management, < 300 lines
3. RealtimeManagerTests.swift covers event parsing (all types), self-echo filtering, and channel lifecycle (subscribe/unsubscribe/reconnect)

### Non-goals (prevents scope creep)

- No behavior changes to realtime event handling
- No changes to channel management patterns
- No modifications to DTOs or delegate protocol
- No changes to postgres_changes handlers (retain for Phase 1 migration)

### Compatibility Plan

- **Backward compatibility**: N/A (internal refactor only)
- **Default when missing**: N/A
- **Rollback strategy**: Revert to original 867-line RealtimeManager.swift

---

### Ownership

- **feature-owner**: Extract components, refactor coordinator, create tests
- **data-integrity**: Not needed

---

### Test Requirements

**File**: `DispatchTests/Sync/RealtimeManagerTests.swift`

#### Event Parsing Tests
- [ ] Parse INSERT event for each table (tasks, activities, listings, users, notes)
- [ ] Parse UPDATE event for each table
- [ ] Parse DELETE event for each table
- [ ] Handle malformed payload gracefully
- [ ] Handle unknown event version

#### Self-Echo Filtering Tests
- [ ] Skip event when originUserId matches currentUserID
- [ ] Process event when originUserId differs from currentUserID
- [ ] Process event when originUserId is nil (system-originated)
- [ ] Skip in-flight entities (tasks, activities, notes)

#### Channel Lifecycle Tests
- [ ] Subscribe creates channel and sets isListening = true
- [ ] Unsubscribe tears down channel and sets isListening = false
- [ ] Skip listening when not authenticated
- [ ] Skip listening when already listening
- [ ] Cancel all tasks on shutdown
- [ ] Status mapping (subscribed/subscribing/unsubscribing/unsubscribed)

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: postgres_changes channel types AsyncStream InsertAction UpdateAction DeleteAction postgresChange return type
CONTEXT7_TAKEAWAYS:
- `postgresChange` returns an AsyncStream that can be iterated with `for await`
- No explicit type names like `PostgresChangeInsertStream` - they are anonymous AsyncStream types
- Use type inference or `some` keyword instead of explicit type names
CONTEXT7_APPLIED:
- Remove TableStreams struct, use inline stream variables -> ChannelLifecycleManager.swift

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: Supabase Swift (/supabase/supabase-swift)

| Query | Pattern Used |
|-------|--------------|
| postgres_changes channel types AsyncStream InsertAction UpdateAction DeleteAction | Type inference for stream variables, no explicit type names |

**N/A**: Only valid for pure refactors with no framework/library usage.
**Note**: Context7 was essential for understanding that postgresChange returns opaque AsyncStream types.

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A
**Reviewed**: N/A

UI Review Required: NO - This is an internal refactor with no UI changes. Jobs Critique is skipped.

---

### Implementation Notes

**Context7 Recommendation**: Feature-owner SHOULD query Context7 for:
- Swift async/await patterns (if restructuring Task lifecycle)
- Swift protocol design (for clean delegate interfaces)

**Line Count Verification**: Integrator MUST verify each extracted component is < 300 lines using `wc -l`.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
