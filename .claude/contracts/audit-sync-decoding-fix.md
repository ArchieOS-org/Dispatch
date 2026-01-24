## Interface Lock

**Feature**: Audit Sync Decoding Fix
**Created**: 2026-01-24
**Status**: in_progress
**Lock Version**: v1
**UI Review Required**: NO

---

### Complexity Indicators

- [ ] **Schema changes** - NO
- [ ] **Complex UI** - NO
- [ ] **High-risk flow** - NO
- [x] **Unfamiliar area** - YES (Supabase response handling)

### Patchset Plan

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Investigation complete | swift-debugger |
| 2 | Fix implemented + builds | feature-owner |
| 3 | Verification | integrator |

---

### Problem Statement

Sync is failing with decoding error before assignee sync runs:
```
Error: keyNotFound(CodingKeys(stringValue: "title", intValue: nil)
```

This prevents audit entries from being created because:
1. Task sync starts DELETE+INSERT pattern
2. DELETE succeeds
3. INSERT returns response missing "title" field
4. Decoding fails, sync crashes
5. Assignees never get synced
6. No audit entries created

### Root Cause Analysis (ACTUAL - 2nd investigation)

The ACTUAL issue was in the "check if exists on server" queries:

```swift
// BUG: Selects only 'id' column but tries to decode as full TaskDTO
let serverTasks: [TaskDTO] = try await supabase
  .from("tasks")
  .select("id")  // <-- Only returns {"id": "..."}
  .in("id", values: pendingTaskIds.map { $0.uuidString })
  .execute()
  .value  // <-- Tries to decode as TaskDTO which needs 'title'!
```

The `.select("id")` returns only the `id` column, but the code was trying to decode it as `[TaskDTO]` which expects `title`, `description`, etc.

### Fix (ACTUAL)

Changed the type annotation from full DTO to `IDOnlyDTO` (which already exists in each handler):

```swift
// Before (causing error)
let serverTasks: [TaskDTO] = try await supabase
  .from("tasks")
  .select("id")
  ...

// After (fix)
let serverTasks: [IDOnlyDTO] = try await supabase
  .from("tasks")
  .select("id")
  ...
```

**Files modified:**
1. `TaskSyncHandler.swift:86` - Changed `[TaskDTO]` to `[IDOnlyDTO]`
2. `ListingSyncHandler.swift:93` - Changed `[ListingDTO]` to `[IDOnlyDTO]`

**Not affected (already correct or using full select):**
- ActivitySyncHandler.swift - Uses `.select()` (full), not `.select("id")`
- PropertySyncHandler.swift - Uses `.select()` (full), not `.select("id")`
- All syncDown queries use `.select()` (full)

---

### Context7 Queries

CONTEXT7_QUERY: insert execute discard result without decoding void response
CONTEXT7_TAKEAWAYS:
- When invoking functions without expecting a response, no assignment is needed
- The `.execute()` method returns a response that can be discarded with `_ =`
- Type inference on `.execute().value` causes decoding attempts
CONTEXT7_APPLIED:
- `_ =` assignment to discard result -> All INSERT calls in sync handlers

---

### Acceptance Criteria

1. Sync completes without decoding errors
2. Task/Activity assignee changes sync to Supabase
3. Audit entries appear in audit log tables

---
