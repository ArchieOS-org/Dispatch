## Interface Lock

**Feature**: Exponential Backoff for Sync Retry
**Created**: 2026-01-17
**Status**: locked
**Lock Version**: v1
**UI Review Required**: NO

### Contract
- New/changed model fields: None (retry count is ephemeral in-memory)
- DTO/API changes: None
- State/actions added:
  - `SyncRetryTracker` class (or struct) for per-entity retry count
  - `RetryPolicy` struct with `delay(for:)` and `maxRetries` constants
  - Modified `retrySync()` / `retryTask()` / `retryActivity()` / `retryListing()` to schedule with backoff
- UI events emitted: None (reuses existing failed state display)
- Migration required: N

### Acceptance Criteria (3 max)
1. Failed sync retries use exponential backoff: 1s, 2s, 4s, 8s, 16s, capped at 30s
2. Automatic retry triggers on network restoration and app foreground (max 5 attempts per entity)
3. Retry count resets to 0 on successful sync; after 5 failures entity remains in `.failed` state

### Non-goals
- No new UI for retry status (reuses existing error display)
- No persistent storage of retry count (ephemeral in-memory)
- No per-entity-type retry policies (single policy for all entities)
- No user-configurable retry settings

### Compatibility Plan
- **Backward compatibility**: N/A (no DTO/schema changes)
- **Default when missing**: N/A
- **Rollback strategy**: Remove retry scheduling code; immediate retry behavior restored

### Ownership
- **feature-owner**: Full implementation of retry policy, tracker, and auto-retry hooks
- **data-integrity**: Not needed

### Jobs Critique
- **Status**: PENDING
