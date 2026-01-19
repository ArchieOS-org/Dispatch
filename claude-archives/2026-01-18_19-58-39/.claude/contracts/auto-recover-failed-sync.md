## Interface Lock

**Feature**: Fix Schema Mismatch and Delta Sync Recovery
**Created**: 2026-01-18
**Status**: locked
**Lock Version**: v2 (scope expanded to include migration and reconciliation fixes)
**UI Review Required**: NO

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [x] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [ ] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 1.5 | Schema ready | data-integrity |
| 2 | Tests pass, criteria met | feature-owner, integrator |

---

### Problem Statement (v2 - Expanded)

Three interconnected blocking issues prevent sync from working after app reinstall or database reset:

#### Issue 1: SwiftData Migration Failure (BLOCKING)
The `lastResetAttempt: Date?` property was added to TaskItem, Activity, and Listing models without proper migration handling. At runtime:
```
CoreData: error: no such column: t0.ZLASTRESETATTEMPT
```

This crashes the app immediately on launch for existing users.

#### Issue 2: Delta Sync Doesn't Recover After DB Reset (BLOCKING)
After deleting the local database, sync fetches 0 records because `lastSyncTime` is stored in UserDefaults (persisted across app reinstalls) but the database is empty:
```
Restored lastSyncTime: 2026-01-18 17:14:35 +0000
syncDown() - fetching records updated since: 2026-01-18T17:14:35Z
FETCH - listings: 0 entities
```

Notes work correctly because they have `reconcileMissingNotes()` which compares remote vs local counts and fetches missing records. Other entities only do delta sync.

#### Issue 3: UserDefaults Reset Doesn't Clear Sync Timestamps
`defaults delete Noah.Dispatch` doesn't clear sync timestamps because they're stored in app-specific UserDefaults. The `lastSyncTime` key is `dispatch.lastSyncTime` in UserDefaults.

### Root Cause Analysis

1. **lastResetAttempt**: Added as a stored property, but SwiftData's lightweight migration failed because the property wasn't marked as ephemeral or given a migration-safe default
2. **Delta sync**: Only fetches records with `updated_at > lastSyncTime`, so an empty database with a stale `lastSyncTime` fetches nothing
3. **Sync timestamps**: Stored in UserDefaults which survives app delete/reinstall via iCloud backup sync

### Solution Overview

#### Fix 1: Make lastResetAttempt Transient
Mark the property with `@Transient` to exclude it from SwiftData persistence entirely. This:
- Eliminates the migration error immediately
- Is semantically correct - `lastResetAttempt` is a local-only runtime value
- No data loss - the property was never successfully persisted anyway

#### Fix 2: Add Reconciliation for All Entity Types
Extend the reconcileMissingNotes pattern to all sync-down entity types:
- `reconcileMissingListings()`
- `reconcileMissingTasks()`
- `reconcileMissingActivities()`
- `reconcileMissingProperties()`
- `reconcileMissingUsers()`

This compares remote IDs vs local IDs and fetches any missing records, ensuring data integrity regardless of `lastSyncTime` state.

#### Fix 3: Reset Sync Timestamps When Database is Empty
Add a check at sync start: if the database has 0 entities of core types (listings, tasks, activities), automatically reset `lastSyncTime` to nil. This triggers full reconciliation mode.

---

### Contract

- New/changed model fields:
  - `TaskItem.lastResetAttempt: Date?` - change to `@Transient`
  - `Activity.lastResetAttempt: Date?` - change to `@Transient`
  - `Listing.lastResetAttempt: Date?` - change to `@Transient`
- DTO/API changes: None (lastResetAttempt is local-only)
- State/actions added:
  - `EntitySyncHandler.reconcileMissingListings(context:) -> Int`
  - `EntitySyncHandler.reconcileMissingTasks(context:) -> Int`
  - `EntitySyncHandler.reconcileMissingActivities(context:) -> Int`
  - `EntitySyncHandler.reconcileMissingProperties(context:) -> Int`
  - `EntitySyncHandler.reconcileMissingUsers(context:) -> Int`
  - `SyncManager.detectAndResetStaleTimestamp()` (auto-reset if DB empty)
- Migration required: N (@Transient bypasses migration - property not persisted)

### Design Decisions

#### 1. Use @Transient for lastResetAttempt

**Decision**: Mark `lastResetAttempt` as transient rather than using VersionedSchema.

**Rationale**:
- The property is semantically ephemeral - it's a runtime cooldown tracker, not persistent data
- Eliminates the migration error immediately without complex migration code
- VersionedSchema adds significant complexity and is overkill for a single optional property
- Deleting the local DB on schema change is too destructive

**Alternative Rejected**: Using VersionedSchema migrations - too complex for this use case.

#### 2. Reconciliation as Safety Net

**Decision**: Run reconciliation for all entity types on every sync, not just on first sync.

**Rationale**:
- The reconcileMissingNotes pattern already works and is lightweight (just fetches IDs)
- Protects against various edge cases: DB reset, migration issues, partial sync failures
- Minimal performance impact - just one ID-only query per entity type per sync

**Implementation**: Add `reconcileMissingX()` methods that:
1. Fetch all IDs from Supabase (lightweight query)
2. Get all local IDs
3. Find IDs that exist remotely but not locally
4. Fetch full records only for missing IDs

#### 3. Auto-Reset Stale Timestamps

**Decision**: Detect empty database at sync start and auto-reset `lastSyncTime`.

**Rationale**:
- If database is empty but `lastSyncTime` is set, something is wrong
- Resetting triggers full reconciliation which will fetch all data
- Better UX than requiring manual intervention

**Implementation**: At start of `sync()`, count core entities. If all are 0 but lastSyncTime is set, reset it.

### Acceptance Criteria (3 max)

1. App launches without "no such column: ZLASTRESETATTEMPT" error for existing users
2. After fresh database (delete app data or reinstall), full sync pulls ALL data from Supabase
3. Listings, tasks, activities, properties, and users all sync correctly regardless of lastSyncTime state

### Non-goals (prevents scope creep)

- No changes to the auto-recovery cooldown logic (that works correctly)
- No changes to exponential backoff retry logic
- No changes to realtime sync behavior
- No VersionedSchema implementation
- No changes to sync UI (SyncTestHarness)

### Compatibility Plan

- **Backward compatibility**: Existing entities that have `lastResetAttempt` persisted will lose that data (property becomes transient), but this is acceptable since the value is just a cooldown tracker
- **Default when missing**: Transient properties start as nil on each app launch
- **Rollback strategy**: If reconciliation causes issues, remove the `reconcileMissingX()` calls from syncDown; @Transient change cannot be rolled back without another schema change

---

### Ownership

- **feature-owner**: Implement @Transient attribute changes; add reconciliation methods; add auto-reset logic
- **data-integrity**: Review @Transient approach is safe; verify reconciliation queries are correct (COMPLETED - see Schema Migration Review)

---

### Implementation Plan

#### Files to Modify

1. **`Dispatch/Features/WorkItems/Models/TaskItem.swift`**
   - Change line 131: `var lastResetAttempt: Date?` to `@Transient var lastResetAttempt: Date?`

2. **`Dispatch/Features/WorkItems/Models/Activity.swift`**
   - Change line 135: `var lastResetAttempt: Date?` to `@Transient var lastResetAttempt: Date?`

3. **`Dispatch/Features/Listings/Models/Listing.swift`**
   - Change line 100: `var lastResetAttempt: Date?` to `@Transient var lastResetAttempt: Date?`

4. **`Dispatch/Foundation/Persistence/Sync/EntitySyncHandler.swift`**
   - Add `reconcileMissingListings(context:) async throws -> Int`
   - Add `reconcileMissingTasks(context:) async throws -> Int`
   - Add `reconcileMissingActivities(context:) async throws -> Int`
   - Add `reconcileMissingProperties(context:) async throws -> Int`
   - Add `reconcileMissingUsers(context:) async throws -> Int`

5. **`Dispatch/Foundation/Persistence/Sync/SyncManager+Operations.swift`**
   - Call all `reconcileMissingX()` methods in `syncDown()` (after existing syncDownX calls)

6. **`Dispatch/Foundation/Persistence/Sync/SyncManager.swift`**
   - Add `detectAndResetStaleTimestamp()` private method
   - Call it at start of `sync()` before `syncDown()`

7. **`Dispatch/Foundation/Persistence/Sync/RetryCoordinator.swift`**
   - No changes needed (@Transient is transparent to this code)

#### Implementation Pattern for Reconciliation

Follow the existing `reconcileMissingNotes` pattern from `NoteSyncHandler.swift`:

```swift
func reconcileMissingListings(context: ModelContext) async throws -> Int {
  // 1. Fetch all listing IDs from server (lightweight query)
  let remoteDTOs: [IDOnlyDTO] = try await supabase
    .from("listings")
    .select("id")
    .execute()
    .value
  let remoteIds = Set(remoteDTOs.map { $0.id })
  debugLog.log("  Remote listings: \(remoteIds.count)", category: .sync)

  // 2. Get all local listing IDs
  let localDescriptor = FetchDescriptor<Listing>()
  let localListings = try context.fetch(localDescriptor)
  let localIds = Set(localListings.map { $0.id })
  debugLog.log("  Local listings: \(localIds.count)", category: .sync)

  // 3. Find IDs that exist on server but not locally
  let missingIds = remoteIds.subtracting(localIds)

  guard !missingIds.isEmpty else {
    debugLog.log("  No missing listings", category: .sync)
    return 0
  }

  debugLog.log("  Warning: Found \(missingIds.count) missing listings, fetching...", category: .sync)

  // 4. Fetch full listing data for missing IDs (batch query)
  let missingDTOs: [ListingDTO] = try await supabase
    .from("listings")
    .select()
    .in("id", values: Array(missingIds).map { $0.uuidString })
    .execute()
    .value

  // 5. Upsert missing listings
  for dto in missingDTOs {
    try upsertListing(dto: dto, context: context)
  }

  debugLog.log("  Reconciled \(missingDTOs.count) missing listings", category: .sync)
  return missingDTOs.count
}
```

#### Implementation Pattern for Auto-Reset

```swift
private func detectAndResetStaleTimestamp() {
  guard let container = modelContainer else { return }
  guard lastSyncTime != nil else { return } // Already needs full sync

  let context = container.mainContext

  do {
    let listingCount = try context.fetchCount(FetchDescriptor<Listing>())
    let taskCount = try context.fetchCount(FetchDescriptor<TaskItem>())
    let activityCount = try context.fetchCount(FetchDescriptor<Activity>())

    // If all core entity types are empty but we have a lastSyncTime, something is wrong
    if listingCount == 0 && taskCount == 0 && activityCount == 0 {
      debugLog.log(
        "Warning: Database appears empty but lastSyncTime is set - resetting for full reconciliation",
        category: .sync
      )
      resetLastSyncTime()
    }
  } catch {
    debugLog.error("Failed to check entity counts", error: error)
  }
}
```

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: SwiftData @Attribute ephemeral property behavior existing data migration
CONTEXT7_TAKEAWAYS:
- @Transient macro (NOT @Attribute(.ephemeral)) excludes property from SwiftData persistence
- Transient properties are not saved to disk, exist only in memory
- Adding @Transient to existing property removes it from schema (no migration needed)
- Value resets to nil/default on each app launch
CONTEXT7_APPLIED:
- @Transient on lastResetAttempt -> TaskItem.swift, Activity.swift, Listing.swift (CORRECTED)

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftData, Supabase Swift

| Query | Pattern Used |
|-------|--------------|
| @Transient property exclude from persistence | @Transient macro on lastResetAttempt properties |
| count query select id from table postgREST Swift | .select("id") for ID-only queries in reconcileMissingX methods |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A (no UI changes)
**Reviewed**: N/A

#### Checklist

N/A - UI Review Required: NO

#### Verdict Notes

No UI changes in this feature. Jobs Critique not required.

---

### Enforcement Summary

| Check | Enforced By | Consequence |
|-------|-------------|-------------|
| UI Review Required: NO | N/A | Jobs Critique skipped |
| Lock Version changed | all agents | Must stop and re-read contract |
| Acceptance criteria met | integrator | Required for DONE |
| Context7 Queries logged | integrator | Warning if missing (not blocking) |

---

### Questions Resolved

1. **Why not use VersionedSchema for the migration?**
   - `lastResetAttempt` is semantically ephemeral (runtime cooldown tracker)
   - VersionedSchema adds complexity without benefit
   - @Transient macro is the correct solution

2. **Why run reconciliation on every sync?**
   - Lightweight (ID-only queries)
   - Catches edge cases: reinstall, migration issues, partial failures
   - Follows proven pattern from reconcileMissingNotes

3. **What triggers auto-reset of lastSyncTime?**
   - Database has 0 listings, 0 tasks, AND 0 activities
   - But lastSyncTime is set (indicating prior sync)
   - This indicates database was reset without clearing UserDefaults

4. **Where is lastSyncTime stored?**
   - UserDefaults key: `dispatch.lastSyncTime`
   - Also: `dispatch.lastSyncNotes`, `dispatch.lastSyncListingTypes`, `dispatch.lastSyncActivityTemplates`
   - All should be reset when database is detected as empty

---

### Schema Migration Review (PATCHSET 1.5 - data-integrity)

**Reviewed by**: data-integrity agent
**Date**: 2026-01-18
**Verdict**: APPROVED with correction

#### Issue 1: Ephemeral Attribute Approach - CORRECTED

**CRITICAL CORRECTION**: The contract incorrectly specified `@Attribute(.ephemeral)`. The correct SwiftData macro is `@Transient`.

Context7 documentation confirms:
- `@Transient` macro excludes properties from SwiftData persistence
- There is no `@Attribute(.ephemeral)` option in SwiftData
- `@Attribute` options include: `.unique`, `.spotlight`, `.allowsCloudEncryption`, but NOT `.ephemeral`

**Corrected Implementation**:
```swift
// WRONG (does not exist):
@Attribute(.ephemeral) var lastResetAttempt: Date?

// CORRECT:
@Transient var lastResetAttempt: Date?
```

**Validation of `lastResetAttempt` as local-only**:
1. Confirmed NOT in Supabase schema:
   - `tasks` table: no `last_reset_attempt` column
   - `activities` table: no `last_reset_attempt` column
   - `listings` table: no `last_reset_attempt` column
2. Confirmed NOT in DTOs:
   - `TaskDTO.swift`: no `lastResetAttempt` property
   - `ActivityDTO.swift`: no `lastResetAttempt` property
   - `ListingDTO.swift`: no `lastResetAttempt` property
3. Usage is purely local: Used only in `RetryCoordinator.swift` for cooldown tracking

**Data Loss Assessment**: NONE
- Property was added recently and caused migration failures
- No existing users have valid persisted data for this property
- Even if they did, it's a cooldown tracker - losing it just resets the cooldown

**Other Properties Review**:
Reviewed other local-only properties in the same models:
- `syncStateRaw: EntitySyncState?` - Correctly NOT ephemeral (tracks sync state between launches)
- `lastSyncError: String?` - Correctly NOT ephemeral (valuable for debugging across restarts)
- `retryCount: Int` - Correctly NOT ephemeral (persists retry attempts across restarts)

Only `lastResetAttempt` should be transient because:
- It's a runtime cooldown tracker (24-hour window)
- Resetting on app launch is acceptable behavior (gives another recovery attempt)
- The other sync-related properties need persistence for proper sync state management

#### Issue 2 & 3: Sync Timestamp Storage - DOCUMENTED

**Sync timestamps are stored in UserDefaults** (not Keychain):

| Key | Purpose | Location |
|-----|---------|----------|
| `dispatch.lastSyncTime` | Main sync timestamp | `SyncManager.swift:101` |
| `dispatch.lastSyncNotes` | Notes-specific sync | `NoteSyncHandler.swift:43` |
| `dispatch.lastSyncListingTypes` | Listing types sync | `ListingSyncHandler.swift:29` |
| `dispatch.lastSyncActivityTemplates` | Activity templates sync | `ActivitySyncHandler.swift:29` |

**Why UserDefaults survives reinstall**: iCloud backup syncs UserDefaults, so timestamps persist even when app data is deleted.

**Recommended fix**: The `detectAndResetStaleTimestamp()` approach in the contract correctly addresses this by resetting all timestamps when the database is empty.

#### Data-Integrity Plan

- **Lane**: Guarded (additive change - marking property as non-persisted)
- **Migration**: None required - `@Transient` removes property from schema
- **SQL**: None - SwiftData-only change
- **Approval Needed**: No - this is a safe change that fixes a blocking bug
- **Sync/DTO Notes**: No changes needed - property is already local-only

#### Files to Update (corrected)

1. `Dispatch/Features/WorkItems/Models/TaskItem.swift:131`
   - Change: `var lastResetAttempt: Date?`
   - To: `@Transient var lastResetAttempt: Date?`

2. `Dispatch/Features/WorkItems/Models/Activity.swift:135`
   - Change: `var lastResetAttempt: Date?`
   - To: `@Transient var lastResetAttempt: Date?`

3. `Dispatch/Features/Listings/Models/Listing.swift:100`
   - Change: `var lastResetAttempt: Date?`
   - To: `@Transient var lastResetAttempt: Date?`

#### Context7 Verification

CONTEXT7_QUERY: @Attribute ephemeral property exclude from persistence transient not saved to database
CONTEXT7_TAKEAWAYS:
- @Transient macro excludes property from SwiftData persistence
- Use @Transient for temporary data or computed properties
- Property value resets to nil/default on each app launch
- @Attribute options include .unique, .spotlight, .allowsCloudEncryption but NOT .ephemeral
CONTEXT7_APPLIED:
- @Transient on lastResetAttempt -> TaskItem.swift, Activity.swift, Listing.swift (CORRECTED from @Attribute(.ephemeral))

---

### Revision History

- **v1** (2026-01-18): Original contract for auto-recovery feature
- **v2** (2026-01-18): Expanded scope to include migration fix (ephemeral attribute) and reconciliation for all entity types
- **v2.1** (2026-01-18): PATCHSET 1.5 - data-integrity review completed. CRITICAL: Corrected `@Attribute(.ephemeral)` to `@Transient` (the correct SwiftData macro). Documented sync timestamp storage locations. APPROVED for implementation.
