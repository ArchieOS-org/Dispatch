## Interface Lock

**Feature**: Circuit Breaker for Sync Retries
**Created**: 2026-01-18
**Status**: locked
**Lock Version**: v1
**UI Review Required**: NO

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [ ] **Unfamiliar area** (adds dispatch-explorer)

Note: Sync/offline changes involved but no schema changes. This is internal retry logic modification.

### Patchset Plan

Based on checked indicators (none checked - backend-only change):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |

---

### Contract

- New/changed model fields: None (circuit breaker state is in-memory, not persisted)
- DTO/API changes: None
- State/actions added:
  - `CircuitBreakerState` enum (closed, open, halfOpen)
  - `CircuitBreaker` class with failure tracking and cooldown logic
  - New `SyncStatus.circuitBreakerOpen` case for user notification
- Migration required: N

### Acceptance Criteria (3 max)

1. Circuit breaker trips after N (configurable, default 5) consecutive failures across all entities and pauses all sync attempts
2. Cooldown period (exponential backoff: 30s, 60s, 120s, 240s, capped at 5 min) before half-open state allows single probe sync
3. Circuit breaker resets to closed on successful sync; user is notified via SyncStatus when circuit breaker is open

### Non-goals (prevents scope creep)

- No persisting circuit breaker state across app launches (resets on launch)
- No changing per-entity retry logic in RetryCoordinator (must coexist)
- No new UI screens or views (uses existing SyncStatus/SyncErrorBoundary pattern)
- No schema or DTO changes

### Compatibility Plan

- **Backward compatibility**: N/A - internal logic change
- **Default when missing**: N/A
- **Rollback strategy**: Remove CircuitBreaker integration from SyncManager; per-entity retries continue working

---

### Technical Approach

**Location**: Create `Dispatch/Foundation/Persistence/Sync/CircuitBreaker.swift`

**Integration Points**:
- `SyncManager.sync()`: Check circuit breaker before attempting sync
- `SyncManager`: Track consecutive failures across sync() calls
- `SyncStatus`: Add `.circuitBreakerOpen` case for UI notification
- `SyncErrorBoundary`: Already handles SyncStatus changes, will display circuit breaker state

**Circuit Breaker State Machine**:
```
CLOSED (normal) --[N failures]--> OPEN (blocked)
OPEN --[cooldown elapsed]--> HALF_OPEN (probe)
HALF_OPEN --[success]--> CLOSED
HALF_OPEN --[failure]--> OPEN (reset cooldown with backoff)
```

**Failure Tracking**:
- Increment on any sync() error (aggregate across entity types)
- Reset on successful sync()
- Do NOT interfere with per-entity RetryCoordinator logic

---

### Ownership

- **feature-owner**: Implement CircuitBreaker class, integrate with SyncManager, add SyncStatus case, write tests
- **data-integrity**: Not needed (no schema changes)

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: MainActor class isolation thread-safe state management concurrency pattern async await
CONTEXT7_TAKEAWAYS:
- Use @MainActor on class for UI-bound/shared state types
- Static properties can be isolated to MainActor for thread safety
- Task { @MainActor in } for calls from nonisolated contexts
- All accesses to @MainActor class are serialized through main actor
CONTEXT7_APPLIED:
- @MainActor on CircuitBreaker class -> CircuitBreaker.swift:62

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: Swift (/swiftlang/swift)

| Query | Pattern Used |
|-------|--------------|
| MainActor class isolation thread-safe state management | @MainActor on CircuitBreaker class for thread-safe state |

**N/A**: Only valid for pure refactors with no framework/library usage.

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A (UI Review Required: NO)

---

### Test Plan

| Test | Description |
|------|-------------|
| `testCircuitBreakerTripsAfterConsecutiveFailures` | Verify breaker opens after N failures |
| `testCircuitBreakerBlocksSyncWhenOpen` | Verify sync() returns early when breaker is open |
| `testCircuitBreakerCooldownTransitionsToHalfOpen` | Verify state transition after cooldown |
| `testCircuitBreakerResetsOnSuccess` | Verify successful sync closes breaker |
| `testCircuitBreakerExponentialCooldown` | Verify cooldown doubles on repeated failures |
| `testCircuitBreakerCoexistsWithPerEntityRetries` | Verify RetryCoordinator still works |
| `testSyncStatusReflectsCircuitBreakerState` | Verify UI notification via SyncStatus |

---

**IMPORTANT**:
- UI Review Required: NO - no customer-facing UI changes, only SyncStatus enum extension
- integrator verifies builds + tests pass on iOS + macOS
- integrator verifies Context7 Attestation before reporting DONE
