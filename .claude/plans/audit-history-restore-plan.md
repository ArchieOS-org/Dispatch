# Audit History + Restore: Implementation Plan

> **Version**: 1.7
> **Contract**: `.claude/contracts/audit-history-restore.md`
> **Created**: 2026-01-22
> **Updated**: 2026-01-22 (v1.7 - Risk zone fixes + tombstone delete sync)

---

## RISK ZONE FIXES (v1.7)

> **3 risk zones addressed: Database hardening, Swift/UI correctness, and tombstone-based delete sync (SHIP BLOCKER).**

### Risk Zone 1: Database (5 items)

| Fix | Problem | Solution |
|-----|---------|----------|
| **Fix 1A: Standardize restore SQL exception strings** | SQL raises verbose messages, but Swift `RestoreError.from()` expects specific prefixes | Update `restore_entity()` EXCEPTION blocks to use `FK_MISSING:%` and `UNIQUE_CONFLICT:%` prefixes; update `RestoreError.from()` to parse these |
| **Fix 1B: Document PK assumption** | Trigger uses `NEW.id` / `OLD.id` without documenting requirement | Add note: all audited tables MUST have `id UUID` as primary key |
| **Fix 1C: Schema evolution guidance** | Old snapshots may fail restore if new columns added without defaults | Add section: new columns MUST be `NULL` or have `DEFAULT` values |
| **Fix 1D: RLS guidance** | `FORCE ROW LEVEL SECURITY` would break table owner's trigger bypass | Add note: Do NOT use `FORCE ROW LEVEL SECURITY` on audit tables |
| **Fix 1E: Ownership column verification** | No verification that ownership columns match actual schema | Add checklist confirming ownership columns: listings->owned_by, properties->owner_id, tasks->created_by, activities->declared_by, users->id |

**Locations:**
- **Fix 1A**: See Phase 4c (`restore_entity`) EXCEPTION blocks + Section D RestoreError.from()
- **Fix 1B-1E**: See new Section B.1 "Database Design Notes"

### Risk Zone 2: Swift/UI (4 items)

| Fix | Problem | Solution |
|-----|---------|----------|
| **Fix 2A: Wrap groupedList in List** | `groupedList` returns Section which must be inside List | Update RecentlyDeletedView body to wrap groupedList in List |
| **Fix 2B: Document onRestore integration discipline** | `onRestore: nil` gating not documented for call sites | Add guidance: use nil in normal detail views, non-nil only in deleted entity contexts |
| **Fix 2C: Use .task(id: entityId)** | `.task` may re-fire on unrelated state changes | Update HistorySection to use `.task(id: entityId)` |
| **Fix 2D: Change AuditEntry from @Model to struct** | @Model would cause SwiftData accumulation without eviction; AuditEntry is fetch-only DTO | Convert AuditEntry to plain struct (not SwiftData @Model) |

**Locations:**
- **Fix 2A**: See RecentlyDeletedView in Section E3
- **Fix 2B**: See new Section E1.1 "onRestore Integration Discipline"
- **Fix 2C**: See HistorySection in Section E1
- **Fix 2D**: See AuditEntry in Section D

### Risk Zone 3: Tombstone-Based Delete Sync (SHIP BLOCKER)

| Issue | Problem | Solution |
|-------|---------|----------|
| **Missing tombstone queue** | Local deletes never reach Supabase without explicit sync mechanism | Add Phase 5 with PendingDeletion SwiftData model, delete flow, and sync loop |

**Location:** See new Section D.5 "Phase 5: Delete Sync with Tombstones"

---

## COMPILE + IMPROVEMENT FIXES (v1.6)

> **4 compile fixes + 2 high-leverage improvements. All code blocks updated to match.**

### Compile Fixes

| Fix | Problem | Solution |
|-----|---------|----------|
| **Fix 1: AuditableEntity.color missing** | `RecentlyDeletedRow` uses `entry.entityType.color` but enum doesn't implement it | Add `color` computed property extension on `AuditableEntity` with SwiftUI import |
| **Fix 2: Tuple not Identifiable for navigation** | `@State private var restoredEntityNavigation: (type: AuditableEntity, id: UUID)?` won't compile with `.navigationDestination(item:)` | Replace with `RestoredNavTarget` struct conforming to `Identifiable, Hashable` |
| **Fix 3: Restore action shown when onRestore is nil** | `HistorySection` shows restore even when `onRestore` closure is nil (correctness bug) | Gate restore UI on `onRestore != nil` and guard inside `restoreEntry()` |
| **Fix 4: AuditAction.color missing SwiftUI import** | `AuditAction` enum uses `Color` but file needs SwiftUI imported | Add `import SwiftUI` to AuditAction file |

### High-Leverage Improvements

| Improvement | Problem | Solution |
|-------------|---------|----------|
| **Improvement A: More efficient get_recently_deleted** | Current UNION ALL does global ORDER BY across all matching deletes - scans too many rows | Pre-limit each table FIRST with CTEs, then UNION, then global sort + limit |
| **Improvement B: Stringify normalizer for diff values** | `String(describing:)` can produce "Optional(...)" style strings in diffs | Add `stringify(_:)` helper function that handles nil, String, NSNumber cleanly |

**Locations:**
- **Fix 1**: See AuditableEntity extension in Section D
- **Fix 2**: See RecentlyDeletedView in Section E3 (RestoredNavTarget struct)
- **Fix 3**: See HistorySection historyList and restoreEntry() in Section E1
- **Fix 4**: See AuditAction enum note in Section D
- **Improvement A**: See Phase 4b get_recently_deleted in Section B
- **Improvement B**: See HistoryDetailView.computeDiffs() in Section E2

---

## COMPILE-CLEAN FIXES (v1.5 - Every Code Block Compiles)

> **All code contradictions fixed. Every code block now matches documented fixes.**

| Issue | Problem | Fix |
|-------|---------|-----|
| **Contradiction 1: HistoryEntryRow used entry.summary** | Plan said Issue A fixed, but code block still showed `Text(entry.summary)` | Updated to use `AuditSummaryBuilder(entry:actorName:entityType:).build()`, added `actorName` computed property |
| **Contradiction 2: ForEach missing id: \.id** | Plan said Issue E fixed, but code blocks showed `ForEach(displayedEntries) {` | All ForEach on AuditEntry arrays now use `id: \.id` |
| **Contradiction 3: computeDiffs() was a stub** | Plan said Issue B fixed, but HistoryDetailView still had `nil // Placeholder` | Replaced with full implementation including `formatDiffValue()` helper |
| **Contradiction 4: RecentlyDeletedRow used entry.displayName** | Code used non-existent property | Fixed to use `entry.displayTitle` |
| **Contradiction 5: RecentlyDeletedView missing supabase** | Struct definition omitted property | Added `let supabase: SupabaseClient` |
| **Issue 5: Duplicate summary logic** | DTO had computeSummary() AND AuditSummaryBuilder | DTO now returns simple action names only ("Created", "Updated"), builder handles human sentences |
| **Issue 6: No navigation after restore** | After restore from Recently Deleted, user stuck on list | Added `restoredEntityNavigation` state, `destinationView(for:id:)` routing, navigation after restore |
| **Issue 7: Missing test scenarios** | No brutal edge case tests documented | Added Section I with 5 non-negotiable test scenarios |

**Locations:**
- **Contradiction 1**: See HistoryEntryRow in Section E1
- **Contradiction 2**: See historyList and groupedList ForEach loops
- **Contradiction 3**: See HistoryDetailView.computeDiffs() in Section E2
- **Contradiction 4**: See RecentlyDeletedRow in Section E3
- **Contradiction 5**: See RecentlyDeletedView in Section E3
- **Issue 5**: See AuditEntryDTO.computeSummary() in Section D
- **Issue 6**: See RecentlyDeletedView.restoreEntry() in Section E3
- **Issue 7**: See Section I - Test Scenarios

---

## ADDITIONAL FIXES (v1.5 - Entity History Hot Path)

> **This fix addresses the #1 daily query performance bottleneck.**

| Issue | Problem | Fix |
|-------|---------|-----|
| **Issue 4: Missing composite index for entity history** | The real daily hot path is entity history: `WHERE record_pk = $1 ORDER BY changed_at DESC LIMIT ...`. Single-column indexes on `record_pk` and `changed_at` are insufficient - requires composite index for optimal performance. | Add composite indexes: `CREATE INDEX ... ON audit.X_log (record_pk, changed_at DESC);` for all 5 audit tables. |

**Location:** See Phase 1 - new composite indexes after table creation (alongside partial DELETE indexes)

---

## ADDITIONAL FIXES (v1.4 - Database Hardening)

> **These fixes address 3 robustness/performance issues.**

| Issue | Problem | Fix |
|-------|---------|-----|
| **Issue F: Restore session flag can mislabel inserts** | `set_config('audit.action','RESTORE', true)` persists for the transaction. Side-effect inserts would also log as RESTORE. | Clear flag immediately after INSERT in `restore_entity()`: `PERFORM set_config('audit.action', '', true);` Also make `audit.log_changes()` defensive - only accept INSERT or RESTORE. |
| **Issue G: UUID cast safety not complete** | `NULLIF(field, '')::UUID` handles empty strings, but invalid UUID strings like `"null"` or garbage data still explode. | Use regex guard pattern: `CASE WHEN (field) ~* '^[0-9a-f]{8}-...$' THEN (field)::uuid ELSE NULL END` |
| **High-Leverage: Partial indexes for DELETE queries** | `get_recently_deleted()` will hammer `action='DELETE' ORDER BY changed_at DESC` queries. | Add partial indexes: `CREATE INDEX ... ON audit.X_log (changed_at DESC) WHERE action = 'DELETE';` |

**Locations:**
- **Issue F FIX**: See Phase 2 (trigger function) + Phase 4c (`restore_entity`)
- **Issue G FIX**: See Phase 4a, 4b, 4c + RLS policies - all UUID casts use regex guard
- **Partial indexes FIX**: See Phase 1 - new indexes after table creation

---

## CRITICAL FIXES (v1.1 - Database)

> **These fixes address 4 database issues that would break RPC + restore functionality.**

| Issue | Problem | Fix |
|-------|---------|-----|
| **DB Issue 1: Pluralization bugs** | `p_entity_type || 's_log'` produces "propertys_log", "activitys_log" | Use hard mapping function `audit.get_table_names()` |
| **DB Issue 2: Empty search_path breaks auth.uid()** | `SET search_path = ''` may prevent `auth.uid()` from resolving | Change to `SET search_path = pg_catalog, public, auth, audit` |
| **DB Issue 3: UPDATE no-op spam** | Trigger logs all UPDATEs even when nothing changed | Split triggers: INSERT/DELETE (no guard), UPDATE (with `WHEN OLD.* IS DISTINCT FROM NEW.*`) |
| **DB Issue 4: Brittle restore logging** | DELETE hack `changed_at >= now() - interval '5 seconds'` is fragile | Use session config flag: `set_config('audit.action', 'RESTORE', true)` |

**See Phase 2, 3, and 4 for corrected SQL.**

---

## SWIFT/UI FIXES (v1.2)

> **These fixes address 3 Swift/UI issues for better UX.**

| Issue | Problem | Fix |
|-------|---------|-----|
| **Swift Issue 1: Restore RPC mismatch** | Swift called `restore_{entity_type}()` but SQL uses unified `restore_entity()` | Update `AuditSyncHandler.restoreEntity()` to call `restore_entity(p_entity_type, p_entity_id)` |
| **Swift Issue 2: UI text not human enough** | Summaries like "Status changed" instead of "Alex changed status to Active" | Add `AuditSummaryBuilder` that generates human sentences with actor names |
| **Swift Issue 3: UI polish needed** | History not collapsed by default, no restore feedback | Add `showAllHistory` state (default 5 events), "Show all" button, restore success toast + refresh |

**Locations:**
- **Issue 1**: See `AuditSyncHandler.restoreEntity()` in Section D
- **Issue 2**: See `AuditSummaryBuilder` after DTO Layer in Section D
- **Issue 3**: See `HistorySection` in Section E1

---

## BLOCKER + POLISH FIXES (v1.3)

> **These fixes address 3 compile blockers and 3 polish gaps.**

### Blocker Fixes

| Issue | Problem | Fix |
|-------|---------|-----|
| **Blocker 2A: Duplicate fieldLabels** | `private static let fieldLabels` in DTO AND `extension AuditEntryDTO { static let fieldLabels }` = redeclare error | Remove duplicate. Keep ONE `static let fieldLabels` (internal access so AuditSummaryBuilder can use it) |
| **Blocker 2B: Builder takes wrong type** | `AuditSummaryBuilder` takes `AuditEntryDTO` but UI has `AuditEntry`. DTO is converted to model and drops `oldRow`/`newRow` | Preserve row data on model via `@Transient var oldRow/newRow`, update builder to take `AuditEntry` + `entityType`, update `toModel()` to copy row data |
| **Blocker 3: Undefined supabase** | `AuditSyncHandler(supabase: supabase)` references undefined variable in HistorySection | Add `supabase: SupabaseClient` parameter to HistorySection |

### Polish Fixes

| Issue | Problem | Fix |
|-------|---------|-----|
| **Polish 6: Toast not rendered** | `restoreToastMessage` is set but never displayed in UI | Add toast overlay to HistorySection body |
| **Polish 7: Vague RESTORE copy** | "You restored this" doesn't say what kind of object | Update AuditSummaryBuilder to include entity type: "You restored this listing" |
| **Polish 8: No diff navigation** | Plan says "tap row opens diff view" but HistoryEntryRow has no NavigationLink | Wrap UPDATE rows in NavigationLink to HistoryDetailView |

**See corrected code in Sections D and E below.**

---

## DATABASE BLOCKER FIXES (v1.3)

> **These fixes address 3 additional database blockers discovered during implementation.**

| Blocker | Problem | Fix |
|---------|---------|-----|
| **Blocker 1: RESTORE audit entry loses `old_row`** | Session-flag approach logs RESTORE action, but `old_row` is NULL because it's still an INSERT-trigger write. Kills meaningful restore diffs and forensics. | After INSERT succeeds in `restore_entity()`, UPDATE the audit row to populate `old_row` with the snapshot from the DELETE record. |
| **Blocker 4: `get_recently_deleted()` returns unsorted + can exceed `p_limit`** | FOREACH loop returns results per table, so final list is not globally ordered by `changed_at` and can return up to ~5x `p_limit`. | Rewrite to use UNION ALL with global `ORDER BY changed_at DESC LIMIT p_limit`. |
| **Blocker 5: UUID casting can explode on empty strings** | `(old_row->>'owned_by')::UUID` throws if stored as empty string `""`. | Use `NULLIF(old_row->>'field', '')::UUID` pattern everywhere. |

**Locations:**
- **Blocker 1 FIX**: See Phase 4c (`restore_entity`) - UPDATE after INSERT to populate `old_row`
- **Blocker 4 FIX**: See Phase 4b (`get_recently_deleted`) - UNION ALL rewrite with global sort/limit
- **Blocker 5 FIX**: See Phase 4a, 4b, 4c - all ownership field casts use `NULLIF(..., '')::UUID`

---

## SWIFT/UI COMPILE FIXES (v1.4)

> **These fixes address 6 Swift/UI issues that would prevent compilation or runtime correctness.**

### Issue A: AuditSummaryBuilder not actually used

**Problem:** `HistoryEntryRow` renders `entry.summary` (basic DTO string like "Status changed") instead of human-readable sentences from `AuditSummaryBuilder`.

**Fix (Updated v1.5):**
1. AuditSummaryBuilder takes `actorName` for personalized sentences ("You created..." or "Alex created..."):
```swift
struct AuditSummaryBuilder {
  let entry: AuditEntry
  let actorName: String  // "You", user's name, or "System"
  let entityType: AuditableEntity

  func build() -> String {
    switch entry.action {
    case .insert: return "\(actorName) created this \(entityType.displayName.lowercased())"
    case .delete: return "\(actorName) deleted this \(entityType.displayName.lowercased())"
    case .restore: return "\(actorName) restored this \(entityType.displayName.lowercased())"
    case .update: return buildUpdateSummary()
    }
  }
  // ... update summary logic with actorName prefix
}
```

2. In HistoryEntryRow, add `actorName` computed property and use the builder:
```swift
// In HistoryEntryRow struct:
private var actorName: String {
  guard let userId = entry.changedBy else { return "System" }
  if userId == currentUserId { return "You" }
  if let user = userLookup(userId) { return user.name }
  return "Someone"
}

// In body:
Text(AuditSummaryBuilder(entry: entry, actorName: actorName, entityType: entry.entityType).build())
  .font(DS.Typography.caption)
  .foregroundColor(DS.Colors.Text.secondary)
```

### Issue B: HistoryDetailView computeDiffs() is a stub

**Problem:** `computeDiffs()` returns `nil`. Diff view doesn't work.

**Fix:** Implement real diff computation:
```swift
private func computeDiffs() -> [FieldDiff]? {
  guard let oldRow = entry.oldRow, let newRow = entry.newRow else { return nil }

  let ignored = Set(["id", "sync_status", "pending_changes", "created_at", "updated_at"])
  let keys = Set(oldRow.keys).union(newRow.keys).subtracting(ignored)

  let diffs = keys.compactMap { key -> FieldDiff? in
    let oldVal = String(describing: oldRow[key]?.value ?? "")
    let newVal = String(describing: newRow[key]?.value ?? "")
    guard oldVal != newVal else { return nil }

    let label = AuditEntryDTO.fieldLabels[key] ?? key.replacingOccurrences(of: "_", with: " ").capitalized
    return FieldDiff(field: label, oldValue: oldVal.isEmpty ? "none" : oldVal,
                     newValue: newVal.isEmpty ? "none" : newVal)
  }

  return diffs.sorted { $0.field < $1.field }
}
```

### Issue C: RecentlyDeletedView missing supabase

**Problem:** `supabase` referenced but not a property.

**Fix:** Add parameter:
```swift
struct RecentlyDeletedView: View {
  let supabase: SupabaseClient
  // ...
}
```

### Issue D: RecentlyDeletedRow references non-existent properties

**Problem:**
- `entry.entityType.color` - `AuditableEntity` has no `color`
- `entry.displayName` - `AuditEntry` has no `displayName`

**Fix 1:** Add `color` to `AuditableEntity`:
```swift
var color: Color {
  switch self {
  case .listing: DS.Colors.Status.open
  case .property: DS.Colors.Status.inProgress
  case .task: DS.Colors.Status.inProgress
  case .user: DS.Colors.Status.open
  case .activity: DS.Colors.Status.inProgress
  }
}
```

**Fix 2:** Add `displayTitle` to `AuditEntry`:
```swift
extension AuditEntry {
  var displayTitle: String {
    let row = newRow ?? oldRow
    switch entityType {
    case .listing:
      if let address = row?["address"]?.value as? String, !address.isEmpty { return address }
      return "Listing"
    case .task:
      if let title = row?["title"]?.value as? String, !title.isEmpty { return title }
      return "Task"
    case .property:
      if let address = row?["address"]?.value as? String, !address.isEmpty { return address }
      return "Property"
    case .activity:
      if let type = row?["activity_type"]?.value as? String, !type.isEmpty { return type }
      return "Activity"
    case .user:
      if let name = row?["name"]?.value as? String, !name.isEmpty { return name }
      return "Realtor"
    }
  }
}
```

Then use `entry.displayTitle` in RecentlyDeletedRow.

### Issue E: AuditEntry not Identifiable for ForEach

**Problem:** `ForEach(displayedEntries)` requires Identifiable.

**Fix:** Use explicit id:
```swift
ForEach(displayedEntries, id: \.id) { entry in
  // ...
}
```

Apply to all ForEach on AuditEntry arrays.

---

## Context7 Queries

CONTEXT7_QUERY: SwiftUI DisclosureGroup collapsible sections expandable timeline history list
CONTEXT7_TAKEAWAYS:
- Use `DisclosureGroup` with `isExpanded` binding for collapsible sections
- `Section(_:isExpanded:content:)` provides native collapsible sections in Lists
- Control expansion state programmatically via `@State` properties
- Disclosure indicator appears automatically in sidebar-styled Lists
- Nested DisclosureGroups supported for hierarchical content
CONTEXT7_APPLIED:
- DisclosureGroup pattern -> HistorySection with expandable state

CONTEXT7_QUERY: SwiftUI two column layout before after comparison diff view styling
CONTEXT7_TAKEAWAYS:
- Use `.formStyle(.columns)` for two-column label/value layout
- ColumnsFormStyle renders trailing-aligned labels, leading-aligned values
- NavigationSplitView for side-by-side comparisons at screen level
- VStack with HStack rows for custom diff styling
CONTEXT7_APPLIED:
- VStack/HStack pattern -> DiffRow with OLD/NEW labels

CONTEXT7_QUERY: Swift async throws error handling Result type RPC call patterns
CONTEXT7_TAKEAWAYS:
- Use `Result<T>` enum for manual error propagation
- `try await` for async functions that throw
- Catch specific error types for granular handling
- Swift native error handling preferred over Result in modern async code
CONTEXT7_APPLIED:
- async throws pattern -> AuditSyncHandler.restoreEntity()

CONTEXT7_QUERY: Supabase Swift client RPC function call with parameters error handling
CONTEXT7_TAKEAWAYS:
- Call RPC with `supabase.rpc("function_name", params: Encodable).execute()`
- Define parameter struct conforming to `Encodable` for typed params
- Handle `PostgrestError` for database errors with `.message` and `.code`
- Use `.value` to decode response into typed result
- GET mode available via `get: true` for read-only RPCs
CONTEXT7_APPLIED:
- RPC pattern -> audit.restore_X() function calls

---

## A) Architecture Overview

### System Design Philosophy

**"Nothing is ever truly lost. Mistakes are reversible. History is transparent. Everything stays fast."**

### End-to-End Data Flow

```
                                WRITE PATH
                                    |
                                    v
+------------------+    TRIGGER    +------------------+
|   public.X       | ------------> |   audit.X_log    |
|   (entity table) |   BEFORE      |   (audit table)  |
|                  |   I/U/D       |   (PRIVATE)      |
+------------------+               +------------------+
        |                                   |
        | Hard Delete                       | Preserved Forever
        v                                   v
    [Row Gone]                      [Full Snapshot]

                                   READ PATH (RPC-ONLY)
                                       |
                                       v
+------------------+    RPC        +------------------+
|   Swift App      | ------------> | public.get_     |
|   (AuditEntry)   |               | entity_history()|
+------------------+               | SECURITY DEFINER|
        ^                          +------------------+
        |                                   |
        |   JSON response                   | Internal query
        +-----------------------------------+
                                            v
                                   +------------------+
                                   |   audit.X_log    |
                                   |   (authorized    |
                                   |   via JSONB)     |
                                   +------------------+

                                  RESTORE PATH
                                       |
                                       v
+------------------+    RPC        +------------------+
|   Swift App      | ------------> | public.restore_ |
|   (Restore CTA)  |               | entity()        |
+------------------+               | SECURITY DEFINER|
        |                          +------------------+
        v                                   |
+------------------+                        | 1. Auth from old_row
|   New entity     |                        | 2. set_config('audit.action', 'RESTORE')
|   in public.X    |                        | 3. INSERT to public.X
+------------------+                        v
        ^                          +------------------+
        |                          |   audit.X_log    |
        +--------------------------| RESTORE entry    |
           trigger checks session  +------------------+
           flag, logs RESTORE
           (not INSERT)
```

**Why RPC-Only?**
- `audit` schema is private (not exposed via PostgREST)
- Authorization from `old_row`/`new_row` JSONB works for deleted rows
- SECURITY DEFINER functions can access private schema
- Consistent API surface for all audit operations

### Key Architectural Decisions

| Decision | Rationale |
|----------|-----------|
| **Hard Delete + Audit Trail** | Cleaner queries (no `WHERE deleted_at IS NULL`), audit table is source of truth |
| **BEFORE Trigger with SECURITY DEFINER** | Captures OLD/NEW before mutation, bypasses RLS for logging |
| **Per-Table Audit Tables** | Table-specific indexes, easier to query/partition, type-safe JSONB |
| **RPC-Only Access** | Audit schema is private; app accesses via `public.get_entity_history()`, `public.get_recently_deleted()`, `public.restore_entity()` |
| **No FK on changed_by** | Prevents audit INSERT failures if referenced user is deleted |
| **RESTORE action type** | Distinguishes restore from normal INSERT in history timeline |
| **Authorize from JSONB** | RLS uses `old_row`/`new_row` ownership fields (not live table) so DELETE logs are visible |

### Component Ownership

| Component | Layer | Owner |
|-----------|-------|-------|
| `audit.X_log` tables | Database | data-integrity |
| `audit.log_changes()` trigger | Database | data-integrity |
| `public.get_entity_history()` RPC | Database | data-integrity |
| `public.get_recently_deleted()` RPC | Database | data-integrity |
| `public.restore_entity()` RPC | Database | data-integrity |
| `AuditEntry` model | Swift | feature-owner |
| `AuditEntryDTO` | Swift | feature-owner |
| `AuditSyncHandler` | Swift | feature-owner |
| `HistorySection` | SwiftUI | feature-owner |
| `RecentlyDeletedView` | SwiftUI | feature-owner |

---

## B) Database Migration Plan

> **Coordination**: data-integrity agent owns all database changes. This section is reference only.

### CRITICAL DESIGN DECISIONS (v2 - Review Feedback Applied)

| Issue | Problem | Solution |
|-------|---------|----------|
| **RLS on deleted rows** | `record_pk IN (SELECT id FROM public.X)` fails for DELETE logs (row gone) | Authorize from `old_row`/`new_row` ownership fields in JSONB |
| **Private schema access** | Swift cannot call `.from("audit.X_log")` - only `public` schema exposed | Create public RPC functions as the ONLY API |
| **FK on changed_by** | If referenced user deleted, audit INSERT fails, breaking real writes | No FK - resolve display name in app |
| **Confusing restore history** | After restore, INSERT trigger logs "INSERT" showing as "Created" | Add RESTORE action type, explicit audit entry after restore |

### Phase 1: Create Audit Schema and Tables

```sql
-- Create audit schema (PRIVATE - not exposed via PostgREST API)
CREATE SCHEMA IF NOT EXISTS audit;

-- Audit log structure (per entity table)
-- Example: audit.listings_log

CREATE TABLE audit.listings_log (
  audit_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- CRITICAL: Include RESTORE action for clear history after restore
  action        TEXT NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE', 'RESTORE')),
  changed_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- CRITICAL: NO FK on changed_by - prevents audit INSERT failure if user deleted
  changed_by    UUID,  -- No FK reference - resolve display name in app
  record_pk     UUID NOT NULL,  -- The listing.id
  old_row       JSONB,          -- Full row before change (NULL for INSERT)
  new_row       JSONB,          -- Full row after change (NULL for DELETE)
  table_schema  TEXT NOT NULL DEFAULT 'public',
  table_name    TEXT NOT NULL DEFAULT 'listings'
);

-- Indexes for common queries
CREATE INDEX idx_listings_log_record_pk ON audit.listings_log(record_pk);
CREATE INDEX idx_listings_log_changed_at ON audit.listings_log(changed_at DESC);
CREATE INDEX idx_listings_log_changed_by ON audit.listings_log(changed_by);
CREATE INDEX idx_listings_log_action ON audit.listings_log(action);

-- FIX v1.4 (High-Leverage): Partial index for recently-deleted hot path
-- get_recently_deleted() queries action='DELETE' ORDER BY changed_at DESC frequently
CREATE INDEX idx_listings_log_deleted_recent
ON audit.listings_log (changed_at DESC)
WHERE action = 'DELETE';

-- FIX v1.5: Composite index for entity history hot path (the #1 daily query)
-- get_entity_history() queries: WHERE record_pk = $1 ORDER BY changed_at DESC LIMIT ...
-- This is a bigger performance win than single-column indexes alone
CREATE INDEX idx_listings_log_record_pk_changed_at
ON audit.listings_log (record_pk, changed_at DESC);

-- Repeat for: audit.properties_log, audit.tasks_log, audit.users_log

-- audit.activities_log - Activities use `declared_by` for ownership
CREATE TABLE audit.activities_log (
  audit_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action        TEXT NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE', 'RESTORE')),
  changed_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  changed_by    UUID,  -- No FK - resolve in app
  record_pk     UUID NOT NULL,  -- The activity.id
  old_row       JSONB,
  new_row       JSONB,
  table_schema  TEXT NOT NULL DEFAULT 'public',
  table_name    TEXT NOT NULL DEFAULT 'activities'
);

-- Indexes matching other audit tables
CREATE INDEX idx_activities_log_record_pk ON audit.activities_log(record_pk);
CREATE INDEX idx_activities_log_changed_at ON audit.activities_log(changed_at DESC);
CREATE INDEX idx_activities_log_changed_by ON audit.activities_log(changed_by);
CREATE INDEX idx_activities_log_action ON audit.activities_log(action);

-- FIX v1.4 (High-Leverage): Partial index for recently-deleted hot path
CREATE INDEX idx_activities_log_deleted_recent
ON audit.activities_log (changed_at DESC)
WHERE action = 'DELETE';

-- FIX v1.5: Composite index for entity history hot path
CREATE INDEX idx_activities_log_record_pk_changed_at
ON audit.activities_log (record_pk, changed_at DESC);

-- FIX v1.4: Partial indexes for all other audit tables (DELETE hot path)
CREATE INDEX idx_properties_log_deleted_recent
ON audit.properties_log (changed_at DESC)
WHERE action = 'DELETE';

CREATE INDEX idx_tasks_log_deleted_recent
ON audit.tasks_log (changed_at DESC)
WHERE action = 'DELETE';

CREATE INDEX idx_users_log_deleted_recent
ON audit.users_log (changed_at DESC)
WHERE action = 'DELETE';

-- FIX v1.5: Composite indexes for entity history hot path (remaining tables)
CREATE INDEX idx_properties_log_record_pk_changed_at
ON audit.properties_log (record_pk, changed_at DESC);

CREATE INDEX idx_tasks_log_record_pk_changed_at
ON audit.tasks_log (record_pk, changed_at DESC);

CREATE INDEX idx_users_log_record_pk_changed_at
ON audit.users_log (record_pk, changed_at DESC);
```

**Key Design Decisions:**
1. **RESTORE action** - Distinguishes restore from normal INSERT in history (shows "Restored" not "Created")
2. **No FK on changed_by** - If user is deleted, audit writes still succeed; app resolves name or shows "Unknown"

### Phase 1.5: Database Design Notes (v1.7)

> **FIX 1B, 1C, 1D, 1E**: Critical design constraints that must be maintained.

#### FIX 1B: Primary Key Assumption

**WARNING**: All audited tables MUST have `id UUID` as primary key.

The trigger function uses `NEW.id` / `OLD.id` to capture the record's primary key:
```sql
USING 'INSERT', changed_by_id, NEW.id, NULL, to_jsonb(NEW), ...
USING 'DELETE', changed_by_id, OLD.id, to_jsonb(OLD), NULL, ...
```

If a table uses a different PK column name, the trigger will fail or capture wrong data.

**Before adding a new audited table:**
- [ ] Verify table has `id UUID PRIMARY KEY`
- [ ] If PK is named differently, update trigger function OR rename column

#### FIX 1C: Schema Evolution Guidance

**WARNING**: New columns MUST be added as `NULL` or with `DEFAULT` values.

When restoring from an old snapshot (`old_row` JSONB), the INSERT uses:
```sql
INSERT INTO public.%I SELECT * FROM jsonb_populate_record(NULL::public.%I, $1)
```

If a new column was added with `NOT NULL` and no default, restore will fail:
- Old snapshot lacks the column
- `jsonb_populate_record` returns NULL for missing keys
- INSERT violates NOT NULL constraint

**Migration checklist for schema changes:**
- [ ] New column is NULLABLE, OR
- [ ] New column has a DEFAULT value
- [ ] If neither possible, write a data migration to backfill audit snapshots

#### FIX 1D: RLS Configuration

**WARNING**: Do NOT use `FORCE ROW LEVEL SECURITY` on audit tables.

By default, the table owner bypasses RLS. This is required because:
- `audit.log_changes()` trigger runs as SECURITY DEFINER
- It needs to INSERT into audit tables regardless of RLS policies
- `FORCE ROW LEVEL SECURITY` would make even the owner subject to RLS

**RLS setup for audit tables:**
```sql
-- CORRECT: Enable RLS but don't force it
ALTER TABLE audit.listings_log ENABLE ROW LEVEL SECURITY;

-- WRONG: This breaks the trigger
ALTER TABLE audit.listings_log FORCE ROW LEVEL SECURITY;  -- NEVER DO THIS
```

#### FIX 1E: Ownership Column Verification

**Checklist**: Ownership columns must match the actual schema for RLS authorization from JSONB.

| Table | Ownership Column | Verified |
|-------|------------------|----------|
| listings | `owned_by` | [ ] |
| properties | `owner_id` | [ ] |
| tasks | `created_by` | [ ] |
| activities | `declared_by` | [ ] |
| users | `id` (self) | [ ] |

**If a column is renamed:**
1. Update RPC functions (`get_entity_history`, `get_recently_deleted`, `restore_entity`)
2. Update RLS policies on audit tables
3. Old audit rows will still use old column name in JSONB - handle both in queries

### Phase 2: Create Generic Trigger Function

> **FIXES APPLIED (v1.1)**:
> - **Issue 2 FIX**: Changed `SET search_path = ''` to `SET search_path = pg_catalog, public, auth, audit` so `auth.uid()` resolves reliably
> - **Issue 4 FIX**: Added session config flag check - if `audit.action = 'RESTORE'`, log as RESTORE instead of INSERT (no brittle DELETE hack needed)
>
> **FIXES APPLIED (v1.4)**:
> - **Issue F FIX**: Made session flag handling defensive - only accept 'INSERT' or 'RESTORE' as valid actions. Any other session flag value defaults to 'INSERT'. This prevents mislabeling if flag persists unexpectedly.

```sql
-- HELPER: Get correct table names (fixes Issue 1 - pluralization)
-- This function maps entity_type to proper table/audit table names
CREATE OR REPLACE FUNCTION audit.get_table_names(p_entity_type TEXT)
RETURNS TABLE (entity_table TEXT, audit_table TEXT)
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  CASE p_entity_type
    WHEN 'listing' THEN
      RETURN QUERY SELECT 'listings'::TEXT, 'listings_log'::TEXT;
    WHEN 'property' THEN
      RETURN QUERY SELECT 'properties'::TEXT, 'properties_log'::TEXT;
    WHEN 'activity' THEN
      RETURN QUERY SELECT 'activities'::TEXT, 'activities_log'::TEXT;
    WHEN 'task' THEN
      RETURN QUERY SELECT 'tasks'::TEXT, 'tasks_log'::TEXT;
    WHEN 'user' THEN
      RETURN QUERY SELECT 'users'::TEXT, 'users_log'::TEXT;
    ELSE
      RAISE EXCEPTION 'INVALID_ENTITY_TYPE: %', p_entity_type;
  END CASE;
END;
$$;

-- MAIN TRIGGER FUNCTION
CREATE OR REPLACE FUNCTION audit.log_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
-- FIX Issue 2: Include required schemas so auth.uid() resolves reliably
SET search_path = pg_catalog, public, auth, audit
AS $$
DECLARE
  audit_table TEXT;
  changed_by_id UUID;
  v_action TEXT;
BEGIN
  -- Derive audit table from source table (trigger attached to public.X)
  audit_table := TG_TABLE_NAME || '_log';
  changed_by_id := auth.uid();

  IF TG_OP = 'INSERT' THEN
    -- FIX Issue 4: Check session flag for RESTORE action
    -- If restore RPC set 'audit.action' to 'RESTORE', use that instead of 'INSERT'
    -- FIX Issue F (v1.4): Defensive - only accept INSERT or RESTORE, default to INSERT
    -- This prevents mislabeling if the session flag persists from side-effect inserts
    v_action :=
      CASE
        WHEN current_setting('audit.action', true) = 'RESTORE' THEN 'RESTORE'
        ELSE 'INSERT'
      END;

    EXECUTE format(
      'INSERT INTO audit.%I (action, changed_by, record_pk, old_row, new_row, table_schema, table_name)
       VALUES ($1, $2, $3, $4, $5, $6, $7)',
      audit_table
    ) USING v_action, changed_by_id, NEW.id, NULL, to_jsonb(NEW), TG_TABLE_SCHEMA, TG_TABLE_NAME;
    RETURN NEW;

  ELSIF TG_OP = 'UPDATE' THEN
    -- Note: UPDATE trigger has WHEN guard (see Phase 3), so we only get here if row changed
    EXECUTE format(
      'INSERT INTO audit.%I (action, changed_by, record_pk, old_row, new_row, table_schema, table_name)
       VALUES ($1, $2, $3, $4, $5, $6, $7)',
      audit_table
    ) USING 'UPDATE', changed_by_id, NEW.id, to_jsonb(OLD), to_jsonb(NEW), TG_TABLE_SCHEMA, TG_TABLE_NAME;
    RETURN NEW;

  ELSIF TG_OP = 'DELETE' THEN
    EXECUTE format(
      'INSERT INTO audit.%I (action, changed_by, record_pk, old_row, new_row, table_schema, table_name)
       VALUES ($1, $2, $3, $4, $5, $6, $7)',
      audit_table
    ) USING 'DELETE', changed_by_id, OLD.id, to_jsonb(OLD), NULL, TG_TABLE_SCHEMA, TG_TABLE_NAME;
    RETURN OLD;
  END IF;

  RETURN NULL;
END;
$$;
```

### Phase 3: Attach Triggers

> **FIX Issue 3 APPLIED (v1.1)**: Split into separate triggers:
> - **INSERT/DELETE trigger**: No WHEN clause (always fires)
> - **UPDATE trigger**: Has `WHEN (OLD.* IS DISTINCT FROM NEW.*)` guard to prevent audit spam from no-op sync operations

```sql
-- ============================================================
-- LISTINGS
-- ============================================================
-- INSERT/DELETE trigger (no guard - always fires)
CREATE TRIGGER audit_listings_insert_delete
  BEFORE INSERT OR DELETE ON public.listings
  FOR EACH ROW EXECUTE FUNCTION audit.log_changes();

-- UPDATE trigger (with WHEN guard to prevent no-op spam)
CREATE TRIGGER audit_listings_update
  BEFORE UPDATE ON public.listings
  FOR EACH ROW
  WHEN (OLD.* IS DISTINCT FROM NEW.*)
  EXECUTE FUNCTION audit.log_changes();

-- ============================================================
-- PROPERTIES
-- ============================================================
CREATE TRIGGER audit_properties_insert_delete
  BEFORE INSERT OR DELETE ON public.properties
  FOR EACH ROW EXECUTE FUNCTION audit.log_changes();

CREATE TRIGGER audit_properties_update
  BEFORE UPDATE ON public.properties
  FOR EACH ROW
  WHEN (OLD.* IS DISTINCT FROM NEW.*)
  EXECUTE FUNCTION audit.log_changes();

-- ============================================================
-- TASKS
-- ============================================================
CREATE TRIGGER audit_tasks_insert_delete
  BEFORE INSERT OR DELETE ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION audit.log_changes();

CREATE TRIGGER audit_tasks_update
  BEFORE UPDATE ON public.tasks
  FOR EACH ROW
  WHEN (OLD.* IS DISTINCT FROM NEW.*)
  EXECUTE FUNCTION audit.log_changes();

-- ============================================================
-- USERS
-- ============================================================
CREATE TRIGGER audit_users_insert_delete
  BEFORE INSERT OR DELETE ON public.users
  FOR EACH ROW EXECUTE FUNCTION audit.log_changes();

CREATE TRIGGER audit_users_update
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  WHEN (OLD.* IS DISTINCT FROM NEW.*)
  EXECUTE FUNCTION audit.log_changes();

-- ============================================================
-- ACTIVITIES
-- ============================================================
CREATE TRIGGER audit_activities_insert_delete
  BEFORE INSERT OR DELETE ON public.activities
  FOR EACH ROW EXECUTE FUNCTION audit.log_changes();

CREATE TRIGGER audit_activities_update
  BEFORE UPDATE ON public.activities
  FOR EACH ROW
  WHEN (OLD.* IS DISTINCT FROM NEW.*)
  EXECUTE FUNCTION audit.log_changes();
```

### Phase 4: Create Public RPC Functions (THE ONLY API)

**CRITICAL: These are the ONLY way the Swift app accesses audit data.**
The `audit` schema is private (not exposed via PostgREST). All access goes through these public functions.

> **FIX Issue 1 APPLIED (v1.1)**: All RPC functions use `audit.get_table_names()` helper instead of naive `|| 's_log'` concatenation.
> This correctly maps: property -> properties_log, activity -> activities_log, etc.

> **FIX Issue 2 APPLIED (v1.1)**: Changed `SET search_path = ''` to `SET search_path = pg_catalog, public, auth, audit` in all functions.

#### 4a: Get Entity History

> **v1.3 FIX (Blocker 5)**: All ownership field casts use `NULLIF(..., '')::UUID` to handle empty strings safely.

```sql
-- get_entity_history: Fetch audit history for a specific entity
-- Called by: AuditSyncHandler.fetchHistory()
-- CRITICAL: Authorizes from old_row/new_row JSONB, NOT live table
-- FIX Issue 1: Uses audit.get_table_names() for correct pluralization
-- FIX Issue 2: Uses proper search_path for auth.uid() resolution
-- FIX Blocker 5 (v1.3): Uses NULLIF(..., '')::UUID to handle empty strings
-- FIX Issue G (v1.4): Uses regex guard for bulletproof UUID casting
CREATE OR REPLACE FUNCTION public.get_entity_history(
  p_entity_type TEXT,
  p_entity_id UUID,
  p_limit INT DEFAULT 50
)
RETURNS TABLE (
  audit_id UUID,
  action TEXT,
  changed_at TIMESTAMPTZ,
  changed_by UUID,
  record_pk UUID,
  old_row JSONB,
  new_row JSONB,
  table_schema TEXT,
  table_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
-- FIX Issue 2: Include required schemas so auth.uid() resolves
SET search_path = pg_catalog, public, auth, audit
AS $$
DECLARE
  v_current_user UUID;
  v_audit_table TEXT;
BEGIN
  v_current_user := auth.uid();

  IF v_current_user IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED: Must be authenticated';
  END IF;

  -- FIX Issue 1: Use helper function for correct pluralization
  -- This maps: property -> properties_log, activity -> activities_log, etc.
  SELECT t.audit_table INTO v_audit_table
  FROM audit.get_table_names(p_entity_type) t;

  -- Return history entries where user is authorized
  -- CRITICAL: Authorize from old_row/new_row JSONB, NOT from live table
  -- This works for DELETE logs where the live row no longer exists
  -- FIX Blocker 5: NULLIF handles empty strings that would explode on UUID cast
  -- FIX Issue G (v1.4): Regex guard handles invalid UUID strings like "null" or garbage
  -- Pattern: ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ (case-insensitive)
  RETURN QUERY EXECUTE format(
    'SELECT audit_id, action, changed_at, changed_by, record_pk, old_row, new_row, table_schema, table_name
     FROM audit.%I
     WHERE record_pk = $1
       AND (
         -- User made the change
         changed_by = $2
         OR
         -- User owns via old_row (works for DELETE/UPDATE even if row deleted)
         -- FIX Issue G: Regex guard for bulletproof UUID casting
         (CASE WHEN (old_row->>''owned_by'') ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'' THEN (old_row->>''owned_by'')::UUID ELSE NULL END) = $2
         OR (CASE WHEN (old_row->>''owner_id'') ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'' THEN (old_row->>''owner_id'')::UUID ELSE NULL END) = $2
         OR (CASE WHEN (old_row->>''created_by'') ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'' THEN (old_row->>''created_by'')::UUID ELSE NULL END) = $2
         OR (CASE WHEN (old_row->>''declared_by'') ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'' THEN (old_row->>''declared_by'')::UUID ELSE NULL END) = $2
         OR (CASE WHEN (old_row->>''id'') ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'' THEN (old_row->>''id'')::UUID ELSE NULL END) = $2
         OR
         -- User owns via new_row (for INSERT/UPDATE)
         (CASE WHEN (new_row->>''owned_by'') ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'' THEN (new_row->>''owned_by'')::UUID ELSE NULL END) = $2
         OR (CASE WHEN (new_row->>''owner_id'') ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'' THEN (new_row->>''owner_id'')::UUID ELSE NULL END) = $2
         OR (CASE WHEN (new_row->>''created_by'') ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'' THEN (new_row->>''created_by'')::UUID ELSE NULL END) = $2
         OR (CASE WHEN (new_row->>''declared_by'') ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'' THEN (new_row->>''declared_by'')::UUID ELSE NULL END) = $2
         OR (CASE WHEN (new_row->>''id'') ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'' THEN (new_row->>''id'')::UUID ELSE NULL END) = $2
       )
     ORDER BY changed_at DESC
     LIMIT $3',
    v_audit_table
  ) USING p_entity_id, v_current_user, p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_entity_history(TEXT, UUID, INT) TO authenticated;
```

#### 4b: Get Recently Deleted

> **v1.3 FIXES APPLIED**:
> - **Blocker 4 FIX**: Rewritten to use UNION ALL with global `ORDER BY changed_at DESC LIMIT p_limit`. Old FOREACH loop returned unsorted results and could exceed p_limit.
> - **Blocker 5 FIX**: All ownership field casts use `NULLIF(..., '')::UUID` to handle empty strings safely.

```sql
-- get_recently_deleted: Fetch recently deleted items (optionally filtered by type)
-- Called by: AuditSyncHandler.fetchRecentlyDeleted()
-- CRITICAL: Authorizes from old_row JSONB (deleted rows don't exist in live table)
-- FIX Issue 1: Uses audit.get_table_names() for correct pluralization
-- FIX Issue 2: Uses proper search_path for auth.uid() resolution
-- FIX Blocker 4 (v1.3): Uses UNION ALL with global ORDER BY + LIMIT (not per-table FOREACH)
-- FIX Blocker 5 (v1.3): Uses NULLIF(..., '')::UUID to handle empty strings
-- FIX Issue G (v1.4): Uses regex guard for bulletproof UUID casting
CREATE OR REPLACE FUNCTION public.get_recently_deleted(
  p_entity_type TEXT DEFAULT NULL,  -- NULL = all types
  p_limit INT DEFAULT 50
)
RETURNS TABLE (
  audit_id UUID,
  action TEXT,
  changed_at TIMESTAMPTZ,
  changed_by UUID,
  record_pk UUID,
  old_row JSONB,
  new_row JSONB,
  table_schema TEXT,
  table_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
-- FIX Issue 2: Include required schemas so auth.uid() resolves
SET search_path = pg_catalog, public, auth, audit
AS $$
DECLARE
  v_current_user UUID;
  v_audit_table TEXT;
  v_sql TEXT;
BEGIN
  v_current_user := auth.uid();

  IF v_current_user IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED: Must be authenticated';
  END IF;

  -- FIX Blocker 4: Build UNION ALL query for global sort + limit
  -- Old approach: FOREACH loop returned per-table results (unsorted, could exceed limit)
  -- New approach: Single query with UNION ALL, then global ORDER BY + LIMIT

  IF p_entity_type IS NOT NULL THEN
    -- Single entity type: simple query
    SELECT t.audit_table INTO v_audit_table
    FROM audit.get_table_names(p_entity_type) t;

    -- FIX Blocker 5: NULLIF handles empty strings
    -- FIX Issue G (v1.4): Regex guard handles invalid UUID strings
    RETURN QUERY EXECUTE format(
      'SELECT audit_id, action, changed_at, changed_by, record_pk, old_row, new_row, table_schema, table_name
       FROM audit.%I
       WHERE action = ''DELETE''
         AND (
           changed_by = $1
           OR (CASE WHEN (old_row->>''owned_by'') ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'' THEN (old_row->>''owned_by'')::UUID ELSE NULL END) = $1
           OR (CASE WHEN (old_row->>''owner_id'') ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'' THEN (old_row->>''owner_id'')::UUID ELSE NULL END) = $1
           OR (CASE WHEN (old_row->>''created_by'') ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'' THEN (old_row->>''created_by'')::UUID ELSE NULL END) = $1
           OR (CASE WHEN (old_row->>''declared_by'') ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'' THEN (old_row->>''declared_by'')::UUID ELSE NULL END) = $1
           OR (CASE WHEN (old_row->>''id'') ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'' THEN (old_row->>''id'')::UUID ELSE NULL END) = $1
         )
       ORDER BY changed_at DESC
       LIMIT $2',
      v_audit_table
    ) USING v_current_user, p_limit;

  ELSE
    -- All entity types: UNION ALL with global sort/limit
    -- FIX Blocker 5: NULLIF handles empty strings in all ownership checks
    -- FIX Issue G (v1.4): Regex guard handles invalid UUID strings like "null" or garbage
    -- Improvement A (v1.6): Pre-limit each table FIRST with CTEs, then UNION, then global sort/limit
    -- This is more efficient than scanning all matching deletes across all tables before limiting
    v_sql := '
      WITH listings_del AS (
        SELECT audit_id, action, changed_at, changed_by, record_pk, old_row, new_row, table_schema, table_name
        FROM audit.listings_log
        WHERE action = ''DELETE''
          AND (changed_by = $1 OR (CASE WHEN (old_row->>''owned_by'') ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'' THEN (old_row->>''owned_by'')::UUID ELSE NULL END) = $1)
        ORDER BY changed_at DESC
        LIMIT $2
      ),
      properties_del AS (
        SELECT audit_id, action, changed_at, changed_by, record_pk, old_row, new_row, table_schema, table_name
        FROM audit.properties_log
        WHERE action = ''DELETE''
          AND (changed_by = $1 OR (CASE WHEN (old_row->>''owner_id'') ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'' THEN (old_row->>''owner_id'')::UUID ELSE NULL END) = $1)
        ORDER BY changed_at DESC
        LIMIT $2
      ),
      tasks_del AS (
        SELECT audit_id, action, changed_at, changed_by, record_pk, old_row, new_row, table_schema, table_name
        FROM audit.tasks_log
        WHERE action = ''DELETE''
          AND (changed_by = $1 OR (CASE WHEN (old_row->>''created_by'') ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'' THEN (old_row->>''created_by'')::UUID ELSE NULL END) = $1)
        ORDER BY changed_at DESC
        LIMIT $2
      ),
      users_del AS (
        SELECT audit_id, action, changed_at, changed_by, record_pk, old_row, new_row, table_schema, table_name
        FROM audit.users_log
        WHERE action = ''DELETE''
          AND (changed_by = $1 OR (CASE WHEN (old_row->>''id'') ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'' THEN (old_row->>''id'')::UUID ELSE NULL END) = $1)
        ORDER BY changed_at DESC
        LIMIT $2
      ),
      activities_del AS (
        SELECT audit_id, action, changed_at, changed_by, record_pk, old_row, new_row, table_schema, table_name
        FROM audit.activities_log
        WHERE action = ''DELETE''
          AND (changed_by = $1 OR (CASE WHEN (old_row->>''declared_by'') ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'' THEN (old_row->>''declared_by'')::UUID ELSE NULL END) = $1)
        ORDER BY changed_at DESC
        LIMIT $2
      ),
      combined AS (
        SELECT * FROM listings_del
        UNION ALL SELECT * FROM properties_del
        UNION ALL SELECT * FROM tasks_del
        UNION ALL SELECT * FROM users_del
        UNION ALL SELECT * FROM activities_del
      )
      SELECT * FROM combined
      ORDER BY changed_at DESC
      LIMIT $2';

    RETURN QUERY EXECUTE v_sql USING v_current_user, p_limit;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_recently_deleted(TEXT, INT) TO authenticated;
```

#### 4c: Restore Entity (with RESTORE action logging)

> **ALL 4 FIXES APPLIED (v1.1)**:
> - **Issue 1 FIX**: Uses `audit.get_table_names()` for correct pluralization
> - **Issue 2 FIX**: Uses `SET search_path = pg_catalog, public, auth, audit` for `auth.uid()` resolution
> - **Issue 4 FIX**: Uses session config flag `set_config('audit.action', 'RESTORE', true)` instead of brittle DELETE hack
>   - The trigger function checks this flag and logs RESTORE instead of INSERT
>   - No need to delete auto-generated INSERT entries - they're never created as INSERT
>
> **v1.3 FIXES APPLIED**:
> - **Blocker 1 FIX**: After INSERT succeeds, UPDATE the RESTORE audit entry to populate `old_row` with the snapshot from the DELETE record. This preserves meaningful restore diffs and forensics.
> - **Blocker 5 FIX**: All ownership field casts use `NULLIF(..., '')::UUID` to handle empty strings safely.
>
> **v1.4 FIXES APPLIED**:
> - **Issue F FIX**: Clear session flag immediately after INSERT to prevent side-effect inserts from being mislabeled as RESTORE.
> - **Issue G FIX**: Uses regex guard pattern for bulletproof UUID casting in ownership check.

```sql
-- restore_entity: Unified restore function for all entity types
-- Called by: AuditSyncHandler.restoreEntity()
-- CRITICAL: Uses session flag so trigger logs RESTORE action (not INSERT)
-- FIX Issue 1: Uses audit.get_table_names() for correct pluralization
-- FIX Issue 2: Uses proper search_path for auth.uid() resolution
-- FIX Issue 4: Uses session config flag instead of brittle DELETE hack
-- FIX Blocker 1 (v1.3): UPDATE audit row after INSERT to populate old_row
-- FIX Blocker 5 (v1.3): Uses NULLIF(..., '')::UUID to handle empty strings
-- FIX Issue F (v1.4): Clear session flag immediately after INSERT
-- FIX Issue G (v1.4): Uses regex guard for bulletproof UUID casting
CREATE OR REPLACE FUNCTION public.restore_entity(
  p_entity_type TEXT,
  p_entity_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
-- FIX Issue 2: Include required schemas so auth.uid() resolves
SET search_path = pg_catalog, public, auth, audit
AS $$
DECLARE
  v_current_user UUID;
  v_old_row JSONB;
  v_original_owner UUID;
  v_audit_table TEXT;
  v_entity_table TEXT;
  v_new_id UUID;
BEGIN
  v_current_user := auth.uid();

  IF v_current_user IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED: Must be authenticated';
  END IF;

  -- FIX Issue 1: Use helper function for correct pluralization
  -- This maps: property -> properties, activity -> activities, etc.
  SELECT t.entity_table, t.audit_table INTO v_entity_table, v_audit_table
  FROM audit.get_table_names(p_entity_type) t;

  -- Find the most recent DELETE record
  EXECUTE format(
    'SELECT old_row FROM audit.%I
     WHERE record_pk = $1 AND action = ''DELETE''
     ORDER BY changed_at DESC LIMIT 1',
    v_audit_table
  ) INTO v_old_row USING p_entity_id;

  IF v_old_row IS NULL THEN
    RAISE EXCEPTION 'NO_DELETE_RECORD: No deleted record found for % %', p_entity_type, p_entity_id;
  END IF;

  -- CRITICAL: Authorization from audit row's old_row JSONB
  -- This works even though the live row is deleted
  -- FIX Blocker 5: NULLIF handles empty strings that would explode on UUID cast
  -- FIX Issue G (v1.4): Regex guard handles invalid UUID strings like "null" or garbage
  v_original_owner := COALESCE(
    CASE WHEN (v_old_row->>'owned_by') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (v_old_row->>'owned_by')::UUID ELSE NULL END,
    CASE WHEN (v_old_row->>'owner_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (v_old_row->>'owner_id')::UUID ELSE NULL END,
    CASE WHEN (v_old_row->>'created_by') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (v_old_row->>'created_by')::UUID ELSE NULL END,
    CASE WHEN (v_old_row->>'declared_by') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (v_old_row->>'declared_by')::UUID ELSE NULL END,  -- For activities table
    CASE WHEN (v_old_row->>'id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (v_old_row->>'id')::UUID ELSE NULL END  -- For users table (self)
  );

  IF v_original_owner IS NULL OR v_original_owner != v_current_user THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Not authorized to restore this %', p_entity_type;
  END IF;

  -- FIX Issue 4: Set session flag BEFORE the INSERT
  -- The trigger function checks current_setting('audit.action', true)
  -- If it equals 'RESTORE', it logs RESTORE instead of INSERT
  -- This is deterministic and clean - no brittle time-based DELETE needed
  PERFORM set_config('audit.action', 'RESTORE', true);

  -- Restore the row
  -- The INSERT trigger will fire, but it will log RESTORE (not INSERT)
  -- because we set the session flag above
  EXECUTE format(
    'INSERT INTO public.%I
     SELECT * FROM jsonb_populate_record(NULL::public.%I, $1)
     ON CONFLICT (id) DO NOTHING
     RETURNING id',
    v_entity_table, v_entity_table
  ) INTO v_new_id USING v_old_row;

  -- FIX Issue F (v1.4): Clear session flag IMMEDIATELY after INSERT
  -- This prevents any side-effect inserts (now or in future code) from being mislabeled as RESTORE
  -- The flag persists for the transaction, so we must clear it explicitly
  PERFORM set_config('audit.action', '', true);

  IF v_new_id IS NULL THEN
    RAISE EXCEPTION 'ALREADY_EXISTS: Failed to restore % % - record may already exist', p_entity_type, p_entity_id;
  END IF;

  -- FIX Blocker 1 (v1.3): Populate old_row on the RESTORE audit entry
  -- The trigger wrote a RESTORE entry with old_row=NULL (it's an INSERT-path write).
  -- We UPDATE that audit row to include the snapshot from the DELETE record.
  -- This enables meaningful restore diffs and forensics:
  --   - old_row = state before deletion (what was lost)
  --   - new_row = state after restore (what was recovered)
  EXECUTE format(
    'UPDATE audit.%I
     SET old_row = $1
     WHERE record_pk = $2
       AND action = ''RESTORE''
       AND changed_by = $3
       AND changed_at = (
         SELECT MAX(changed_at)
         FROM audit.%I
         WHERE record_pk = $2
           AND action = ''RESTORE''
           AND changed_by = $3
       )',
    v_audit_table, v_audit_table
  ) USING v_old_row, p_entity_id, v_current_user;

  -- FIX Issue F (v1.4): Session flag was already cleared immediately after INSERT
  -- This ensures any subsequent operations in this transaction use normal INSERT logging

  RETURN v_new_id;

EXCEPTION
  -- FIX 1A (v1.7): Standardize exception strings for Swift RestoreError.from() parsing
  -- Format: PREFIX:entity_type - Swift extracts the entity type after the colon
  WHEN foreign_key_violation THEN
    RAISE EXCEPTION 'FK_MISSING:%', p_entity_type;
  WHEN unique_violation THEN
    RAISE EXCEPTION 'UNIQUE_CONFLICT:%', p_entity_type;
END;
$$;

GRANT EXECUTE ON FUNCTION public.restore_entity(TEXT, UUID) TO authenticated;
```

### Phase 5: Remove Soft Delete Columns (Staged)

| Stage | Timing | Action |
|-------|--------|--------|
| 5a | PATCHSET 2 | Stop using `deleted_at` in app; switch to hard delete |
| 5b | Post-rollout (2 weeks) | `ALTER TABLE public.X DROP COLUMN IF EXISTS deleted_at;` |

---

## C) RLS/Security Plan

### CRITICAL: RLS Authorizes from Audit Row, NOT Live Table

**Problem with naive RLS:**
```sql
-- WRONG: Deleted rows don't exist in live table!
-- Users can't see DELETE logs or restore their own deleted items
USING (record_pk IN (SELECT id FROM public.listings WHERE TRUE))
```

**Solution: Authorize from `old_row`/`new_row` ownership fields:**
```sql
-- CORRECT: Works for deleted rows
USING (
  -- User made the change
  changed_by = (SELECT auth.uid())
  OR
  -- User owns via old_row (for DELETE/UPDATE - row may be deleted)
  (old_row->>'owned_by')::UUID = (SELECT auth.uid())
  OR
  -- User owns via new_row (for INSERT/UPDATE)
  (new_row->>'owned_by')::UUID = (SELECT auth.uid())
)
```

### Audit Tables: RLS as Defense-in-Depth

The audit schema is private (not exposed via PostgREST), so RLS on audit tables is defense-in-depth.
All app access goes through public RPC functions which handle authorization internally.

```sql
-- Enable RLS on audit tables (defense-in-depth)
ALTER TABLE audit.listings_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit.properties_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit.tasks_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit.users_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit.activities_log ENABLE ROW LEVEL SECURITY;

-- Policy: Authorize from audit row ownership, NOT live table
-- This works for DELETE logs where the live row no longer exists
-- FIX Issue G (v1.4): Uses regex guard for bulletproof UUID casting

CREATE POLICY "audit_listings_select"
ON audit.listings_log FOR SELECT
TO authenticated
USING (
  changed_by = (SELECT auth.uid())
  OR (CASE WHEN (old_row->>'owned_by') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (old_row->>'owned_by')::UUID ELSE NULL END) = (SELECT auth.uid())
  OR (CASE WHEN (new_row->>'owned_by') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (new_row->>'owned_by')::UUID ELSE NULL END) = (SELECT auth.uid())
);

CREATE POLICY "audit_properties_select"
ON audit.properties_log FOR SELECT
TO authenticated
USING (
  changed_by = (SELECT auth.uid())
  OR (CASE WHEN (old_row->>'owner_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (old_row->>'owner_id')::UUID ELSE NULL END) = (SELECT auth.uid())
  OR (CASE WHEN (new_row->>'owner_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (new_row->>'owner_id')::UUID ELSE NULL END) = (SELECT auth.uid())
);

CREATE POLICY "audit_tasks_select"
ON audit.tasks_log FOR SELECT
TO authenticated
USING (
  changed_by = (SELECT auth.uid())
  OR (CASE WHEN (old_row->>'created_by') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (old_row->>'created_by')::UUID ELSE NULL END) = (SELECT auth.uid())
  OR (CASE WHEN (new_row->>'created_by') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (new_row->>'created_by')::UUID ELSE NULL END) = (SELECT auth.uid())
);

CREATE POLICY "audit_users_select"
ON audit.users_log FOR SELECT
TO authenticated
USING (
  changed_by = (SELECT auth.uid())
  OR (CASE WHEN (old_row->>'id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (old_row->>'id')::UUID ELSE NULL END) = (SELECT auth.uid())
  OR (CASE WHEN (new_row->>'id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (new_row->>'id')::UUID ELSE NULL END) = (SELECT auth.uid())
);

CREATE POLICY "audit_activities_select"
ON audit.activities_log FOR SELECT
TO authenticated
USING (
  changed_by = (SELECT auth.uid())
  OR (CASE WHEN (old_row->>'declared_by') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (old_row->>'declared_by')::UUID ELSE NULL END) = (SELECT auth.uid())
  OR (CASE WHEN (new_row->>'declared_by') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (new_row->>'declared_by')::UUID ELSE NULL END) = (SELECT auth.uid())
);

-- NO INSERT/UPDATE/DELETE policies for authenticated users
-- Audit writes ONLY via SECURITY DEFINER trigger function
```

### Access Matrix

| Role | Read Audit Logs | Restore Entities | Write to Audit |
|------|-----------------|------------------|----------------|
| Anonymous | No | No | No |
| Authenticated | Via public RPC only | Own entities via RPC | No (trigger only) |
| Service Role | Yes (bypass) | Yes (bypass) | Yes (bypass) |

### Restore Authorization (Checked in RPC from JSONB)

| Entity | Ownership Field in old_row | Who Can Restore |
|--------|----------------------------|-----------------|
| Listing | `old_row->>'owned_by'` | Original owner |
| Property | `old_row->>'owner_id'` | Original owner |
| Task | `old_row->>'created_by'` | Original creator |
| User | `old_row->>'id'` | Self only |
| Activity | `old_row->>'declared_by'` | Original creator |

### Why RPC-Only Access

1. **Private schema**: `audit` schema not exposed via PostgREST API
2. **Authorization from JSONB**: Can authorize access to DELETE logs using ownership fields in the preserved row snapshot
3. **SECURITY DEFINER**: RPC functions run as function owner, can access private schema
4. **Explicit search_path**: Uses `pg_catalog, public, auth, audit` - includes only required schemas while preventing injection (see Issue 2 fix)
5. **Consistent API**: Single interface for history, recently deleted, and restore

---

## D) App Integration Plan

> **CRITICAL**: The `audit` schema is private. All access MUST go through public RPC functions.
> Direct table queries like `.from("audit.listings_log")` will fail with permission errors.

### Swift Models

```swift
// Dispatch/Features/Audit/Models/AuditEntry.swift

import Foundation

// FIX 2D (v1.7): Changed from @Model to struct
// Rationale:
// - AuditEntry is a fetch-only DTO from Supabase RPC
// - We don't need local persistence of audit entries
// - They're fetched fresh each time the history is viewed
// - @Model would cause SwiftData accumulation without eviction strategy
// - Using @Model adds unnecessary complexity and memory overhead
struct AuditEntry: Identifiable {
  let id: UUID
  let action: AuditAction
  let changedAt: Date
  let changedBy: UUID?
  let entityType: AuditableEntity
  let entityId: UUID
  let summary: String  // Human-readable, computed from diff

  // Row data for summary building and diff display
  // Populated by DTO.toModel() and used by AuditSummaryBuilder
  var oldRow: [String: AnyCodable]?
  var newRow: [String: AnyCodable]?

  init(
    id: UUID,
    action: AuditAction,
    changedAt: Date,
    changedBy: UUID?,
    entityType: AuditableEntity,
    entityId: UUID,
    summary: String,
    oldRow: [String: AnyCodable]? = nil,
    newRow: [String: AnyCodable]? = nil
  ) {
    self.id = id
    self.action = action
    self.changedAt = changedAt
    self.changedBy = changedBy
    self.entityType = entityType
    self.entityId = entityId
    self.summary = summary
    self.oldRow = oldRow
    self.newRow = newRow
  }
}

// FIX 4 (v1.6): AuditAction uses Color, so file needs `import SwiftUI`
// Ensure AuditAction.swift has: import SwiftUI

enum AuditAction: String, Codable {
  case insert = "INSERT"
  case update = "UPDATE"
  case delete = "DELETE"
  case restore = "RESTORE"  // Distinct from INSERT - entity was restored from deletion

  var displayName: String {
    switch self {
    case .insert: "Created"
    case .update: "Updated"
    case .delete: "Deleted"
    case .restore: "Restored"  // Distinct from "Created"
    }
  }

  var icon: String {
    switch self {
    case .insert: "plus.circle"
    case .update: "pencil.circle"
    case .delete: "trash.circle"
    case .restore: "arrow.uturn.backward.circle"  // Restore-specific icon
    }
  }

  var color: Color {
    switch self {
    case .insert: DS.Colors.Status.open
    case .update: DS.Colors.Status.inProgress
    case .delete: DS.Colors.Status.deleted
    case .restore: DS.Colors.Status.open  // Green like created - positive action
    }
  }
}

enum AuditableEntity: String, Codable, CaseIterable {
  case listing
  case property
  case task
  case user  // realtors
  case activity  // NEW

  var displayName: String {
    switch self {
    case .listing: "Listing"
    case .property: "Property"
    case .task: "Task"
    case .user: "Realtor"
    case .activity: "Activity"
    }
  }

  var icon: String {
    switch self {
    case .listing: DS.Icons.Entity.listing
    case .property: "building.2"
    case .task: DS.Icons.Entity.task
    case .user: DS.Icons.Entity.user
    case .activity: DS.Icons.Entity.activity  // or "clock.arrow.circlepath"
    }
  }
}

// FIX 1 (v1.6): Add color property for RecentlyDeletedRow
// NOTE: This extension requires `import SwiftUI` at top of file
extension AuditableEntity {
  var color: Color {
    switch self {
    case .listing: DS.Colors.Status.open
    case .property: DS.Colors.Status.inProgress
    case .task: DS.Colors.Status.inProgress
    case .user: DS.Colors.Status.open
    case .activity: DS.Colors.Status.inProgress
    }
  }
}
```

### DTO Layer

```swift
// Dispatch/Features/Audit/DTOs/AuditEntryDTO.swift

import Foundation

struct AuditEntryDTO: Codable {
  let auditId: UUID
  let action: String
  let changedAt: Date
  let changedBy: UUID?
  let recordPk: UUID
  let oldRow: [String: AnyCodable]?
  let newRow: [String: AnyCodable]?
  let tableSchema: String
  let tableName: String

  enum CodingKeys: String, CodingKey {
    case auditId = "audit_id"
    case action
    case changedAt = "changed_at"
    case changedBy = "changed_by"
    case recordPk = "record_pk"
    case oldRow = "old_row"
    case newRow = "new_row"
    case tableSchema = "table_schema"
    case tableName = "table_name"
  }

  // FIX Blocker 2B: Copy row data to model for AuditSummaryBuilder
  // FIX 2D (v1.7): Updated for struct initializer (includes row data in init)
  func toModel() -> AuditEntry {
    AuditEntry(
      id: auditId,
      action: AuditAction(rawValue: action) ?? .update,
      changedAt: changedAt,
      changedBy: changedBy,
      entityType: entityTypeFromTable(),
      entityId: recordPk,
      summary: computeSummary(),
      oldRow: self.oldRow,
      newRow: self.newRow
    )
  }

  private func entityTypeFromTable() -> AuditableEntity {
    switch tableName {
    case "listings": .listing
    case "properties": .property
    case "tasks": .task
    case "users": .user
    case "activities": .activity
    default: .listing
    }
  }

  // FIX Issue 5 (v1.5): Simple action name only - human sentences built by AuditSummaryBuilder at render time
  // This is the basic summary stored in the model. For human-readable display with actor names
  // ("You changed price..."), use AuditSummaryBuilder at display time when you have the actor name.
  private func computeSummary() -> String {
    switch action {
    case "INSERT": return "Created"
    case "DELETE": return "Deleted"
    case "RESTORE": return "Restored"
    case "UPDATE": return "Updated"
    default: return "Modified"
    }
  }

  // MARK: - Human-Readable Field Labels

  // FIX Blocker 2A: Use internal access (not private) so AuditSummaryBuilder can use it
  // REMOVED duplicate extension - this is the single source of truth
  /// Maps database column names to user-friendly labels
  static let fieldLabels: [String: String] = [
    // Listing fields
    "stage": "Status",
    "price": "Price",
    "assigned_to": "Assignment",
    "due_date": "Due date",
    "address": "Address",
    "mls_number": "MLS number",
    "owned_by": "Owner",
    "listing_date": "Listing date",
    "expiration_date": "Expiration date",
    "listing_type": "Listing type",
    "commission_rate": "Commission rate",
    "notes": "Notes",
    "real_dirt": "Real dirt",

    // Property fields
    "owner_id": "Owner",
    "property_type": "Property type",
    "bedrooms": "Bedrooms",
    "bathrooms": "Bathrooms",
    "square_feet": "Square feet",
    "lot_size": "Lot size",
    "year_built": "Year built",

    // Task fields
    "title": "Title",
    "description": "Description",
    "status": "Status",
    "priority": "Priority",
    "completed_at": "Completed at",
    "listing_id": "Listing",
    "property_id": "Property",

    // Activity fields
    "declared_by": "Created by",
    "activity_type": "Type",
    "outcome": "Outcome",
    "contact_method": "Contact method",

    // User fields
    "name": "Name",
    "email": "Email",
    "phone": "Phone",
    "license_number": "License number",
    "brokerage": "Brokerage",

    // Common fields
    "created_at": "Created at",
    "updated_at": "Updated at"
  ]

  // FIX Issue 5 (v1.5): REMOVED computeFieldChanges() and areEqual() - no longer used
  // DTO.computeSummary() now returns simple action names only ("Created", "Updated", etc.)
  // Human-readable summaries are built by AuditSummaryBuilder at render time
}
```

### AuditSummaryBuilder (v1.3 FIX - Human-Readable Summaries)

> **FIX (Swift/UI Issue 2)**: Instead of "Status changed" or "3 fields changed",
> generates sentences like **"Alex changed status to Active"** or
> **"You changed price from $699k to $679k"**.
>
> **FIX Blocker 2B**: Takes `AuditEntry` (model) instead of `AuditEntryDTO`
> **FIX Polish 7**: Includes entity type: "You restored this listing"
>
> Call at display time when actor name is available.

```swift
// Dispatch/Features/Audit/Helpers/AuditSummaryBuilder.swift

import Foundation

/// Builds human-readable summaries for audit entries with actor names.
/// FIX Blocker 2B: Takes AuditEntry (model) not AuditEntryDTO
/// FIX Polish 7: Includes entityType for "restored this listing" copy
struct AuditSummaryBuilder {
  let entry: AuditEntry         // CHANGED from AuditEntryDTO (v1.3 Blocker 2B)
  let actorName: String         // "You", user's name, or "System"
  let entityType: AuditableEntity  // FIX Polish 7: For "restored this listing" copy

  /// Build a human-readable summary sentence.
  /// FIX Polish 7: All action types include entity type in copy
  func build() -> String {
    switch entry.action {
    case .insert: return "\(actorName) created this \(entityType.displayName.lowercased())"
    case .delete: return "\(actorName) deleted this \(entityType.displayName.lowercased())"
    case .restore: return "\(actorName) restored this \(entityType.displayName.lowercased())"
    case .update: return buildUpdateSummary()
    }
  }

  private func buildUpdateSummary() -> String {
    guard let oldRow = entry.oldRow, let newRow = entry.newRow else {
      return "\(actorName) made changes"
    }

    let systemFields = Set(["id", "sync_status", "pending_changes", "created_at", "updated_at"])
    let changedFields = newRow.keys.filter { key in
      guard !systemFields.contains(key) else { return false }
      guard let oldValue = oldRow[key], let newValue = newRow[key] else { return false }
      return String(describing: oldValue.value) != String(describing: newValue.value)
    }

    guard !changedFields.isEmpty else { return "\(actorName) made changes" }

    let priorityFields = ["status", "stage", "price", "assigned_to", "title", "name"]
    let topField = priorityFields.first { changedFields.contains($0) } ?? changedFields.first!

    if changedFields.count == 1 {
      return buildSingleFieldSummary(field: topField, oldRow: oldRow, newRow: newRow)
    }

    let humanLabels = changedFields.map { humanLabel(for: $0) }
    if humanLabels.count == 2 {
      return "\(actorName) changed \(humanLabels[0]) and \(humanLabels[1])"
    } else if humanLabels.count == 3 {
      return "\(actorName) changed \(humanLabels[0]), \(humanLabels[1]), and \(humanLabels[2])"
    } else {
      let summary = buildSingleFieldSummary(field: topField, oldRow: oldRow, newRow: newRow)
      let otherCount = changedFields.count - 1
      return "\(summary) and \(otherCount) other field\(otherCount == 1 ? "" : "s")"
    }
  }

  private func buildSingleFieldSummary(field: String, oldRow: [String: AnyCodable], newRow: [String: AnyCodable]) -> String {
    let label = humanLabel(for: field)
    let oldValue = formatValue(oldRow[field], for: field)
    let newValue = formatValue(newRow[field], for: field)

    if ["status", "stage"].contains(field) {
      return "\(actorName) changed \(label.lowercased()) to \(newValue)"
    }
    return "\(actorName) changed \(label.lowercased()) from \(oldValue) to \(newValue)"
  }

  private func humanLabel(for field: String) -> String {
    AuditEntryDTO.fieldLabels[field] ?? field.replacingOccurrences(of: "_", with: " ").capitalized
  }

  private func formatValue(_ value: AnyCodable?, for field: String) -> String {
    guard let value else { return "none" }
    let raw = String(describing: value.value)

    if field == "price", let number = Double(raw) {
      let formatter = NumberFormatter()
      formatter.numberStyle = .currency
      formatter.maximumFractionDigits = 0
      return formatter.string(from: NSNumber(value: number)) ?? raw
    }

    if ["status", "stage"].contains(field) {
      return raw.replacingOccurrences(of: "_", with: " ").capitalized
    }

    return raw.isEmpty ? "none" : raw
  }
}

// FIX Blocker 2A: REMOVED duplicate extension - fieldLabels is now internal on AuditEntryDTO
// AuditSummaryBuilder accesses via AuditEntryDTO.fieldLabels directly
```

### Sync Handler

> **RPC-Only Access**: The `audit` schema is private. All access goes through public RPC functions.
> Never use `.from("audit.X")` - it will fail with permission errors.

```swift
// Dispatch/Features/Audit/Sync/AuditSyncHandler.swift

import Foundation
import Supabase
import SwiftData

@MainActor
final class AuditSyncHandler {

  private let supabase: SupabaseClient

  init(supabase: SupabaseClient) {
    self.supabase = supabase
  }

  // MARK: - RPC Parameter Types

  /// Parameters for get_entity_history RPC
  struct HistoryParams: Encodable {
    let pEntityType: String
    let pEntityId: UUID
    let pLimit: Int

    enum CodingKeys: String, CodingKey {
      case pEntityType = "p_entity_type"
      case pEntityId = "p_entity_id"
      case pLimit = "p_limit"
    }
  }

  /// Parameters for get_recently_deleted RPC
  struct RecentlyDeletedParams: Encodable {
    let pEntityType: String?  // nil = all types
    let pLimit: Int

    enum CodingKeys: String, CodingKey {
      case pEntityType = "p_entity_type"
      case pLimit = "p_limit"
    }
  }

  /// Parameters for restore_X RPC functions
  struct RestoreParams: Encodable {
    let pRecordPk: UUID

    enum CodingKeys: String, CodingKey {
      case pRecordPk = "p_record_pk"
    }
  }

  // MARK: - Fetch History (via RPC)

  /// Fetch audit history for a specific entity via public RPC
  ///
  /// Calls: `get_entity_history(p_entity_type, p_entity_id, p_limit)`
  func fetchHistory(for entityType: AuditableEntity, entityId: UUID, limit: Int = 50) async throws -> [AuditEntry] {
    let params = HistoryParams(
      pEntityType: entityType.rawValue,
      pEntityId: entityId,
      pLimit: limit
    )

    // RPC returns array of audit entries - uses public function, not direct table access
    let dtos: [AuditEntryDTO] = try await supabase
      .rpc("get_entity_history", params: params)
      .execute()
      .value

    return dtos.map { $0.toModel() }
  }

  // MARK: - Fetch Recently Deleted (via RPC)

  /// Fetch recently deleted items across all entity types via public RPC
  ///
  /// Calls: `get_recently_deleted(p_entity_type, p_limit)`
  func fetchRecentlyDeleted(entityType: AuditableEntity? = nil, limit: Int = 50) async throws -> [AuditEntry] {
    let params = RecentlyDeletedParams(
      pEntityType: entityType?.rawValue,
      pLimit: limit
    )

    let dtos: [AuditEntryDTO] = try await supabase
      .rpc("get_recently_deleted", params: params)
      .execute()
      .value

    return dtos.map { $0.toModel() }
  }

  // MARK: - Restore Entity (via RPC)

  /// Parameters for restore_entity RPC (unified function)
  struct UnifiedRestoreParams: Encodable {
    let pEntityType: String
    let pEntityId: UUID

    enum CodingKeys: String, CodingKey {
      case pEntityType = "p_entity_type"
      case pEntityId = "p_entity_id"
    }
  }

  /// Restore a deleted entity via unified RPC
  ///
  /// Calls: `restore_entity(p_entity_type, p_entity_id)`
  /// Returns: The restored entity's ID
  ///
  /// **FIX (Issue 1)**: Uses unified `restore_entity()` RPC, not per-entity functions.
  /// The SQL defines `public.restore_entity(p_entity_type TEXT, p_entity_id UUID)`.
  func restoreEntity(_ entityType: AuditableEntity, entityId: UUID) async throws -> UUID {
    let params = UnifiedRestoreParams(
      pEntityType: entityType.rawValue,
      pEntityId: entityId
    )

    do {
      let result: UUID = try await supabase
        .rpc("restore_entity", params: params)
        .execute()
        .value

      return result
    } catch let error as PostgrestError {
      throw RestoreError.from(error)
    }
  }
}

// MARK: - Restore Error Handling

enum RestoreError: LocalizedError {
  case noDeleteRecord
  case notAuthorized
  case alreadyExists
  case foreignKeyMissing(String)
  case uniqueConflict(String)
  case unknown(String)

  var errorDescription: String? {
    switch self {
    case .noDeleteRecord:
      "No deleted record found to restore"
    case .notAuthorized:
      "You are not authorized to restore this item"
    case .alreadyExists:
      "This item already exists and cannot be restored"
    case .foreignKeyMissing(let entity):
      "Cannot restore - the \(entity) this was linked to no longer exists"
    case .uniqueConflict(let field):
      "Cannot restore - a record with this \(field) already exists"
    case .unknown(let message):
      message
    }
  }

  // FIX 1A (v1.7): Updated to parse standardized SQL exception prefixes
  // SQL raises: RAISE EXCEPTION 'FK_MISSING:%', p_entity_type
  // Swift parses: "FK_MISSING:listing" -> .foreignKeyMissing("listing")
  static func from(_ postgrestError: PostgrestError) -> RestoreError {
    let message = postgrestError.message

    // Check for prefix-based errors first (most specific)
    if message.hasPrefix("FK_MISSING:") {
      let entity = String(message.dropFirst("FK_MISSING:".count))
      return .foreignKeyMissing(entity.isEmpty ? "related item" : entity)
    }
    if message.hasPrefix("UNIQUE_CONFLICT:") {
      let field = String(message.dropFirst("UNIQUE_CONFLICT:".count))
      return .uniqueConflict(field.isEmpty ? "field" : field)
    }

    // Fall back to contains-based checks for other error types
    if message.contains("NO_DELETE_RECORD") {
      return .noDeleteRecord
    } else if message.contains("NOT_AUTHORIZED") {
      return .notAuthorized
    } else if message.contains("ALREADY_EXISTS") || message.contains("already exists") {
      return .alreadyExists
    }

    return .unknown(message)
  }
}
```

### Delete Flow Migration

```swift
// BEFORE (soft delete) - in ListingDetailView.swift line ~453-461
private func deleteListing() {
  listing.status = .deleted
  listing.deletedAt = Date()
  listing.markPending()
  syncManager.requestSync()
  dismiss()
  appState.dispatch(.removeRoute(.listing(listing.id)))
}

// AFTER (hard delete) - triggers capture full row snapshot
private func deleteListing() {
  // SwiftData delete - will sync as DELETE to Supabase
  // Trigger captures full row to audit table before deletion
  modelContext.delete(listing)
  syncManager.requestSync()
  dismiss()
  appState.dispatch(.removeRoute(.listing(listing.id)))
}
```

### Sync Handler Updates

```swift
// In ListingSyncHandler.syncUp() - change upsert to include hard delete handling
// Delete rows where local model was deleted should issue DELETE to Supabase

// New method in ListingSyncHandler:
func syncDeletedListings(context: ModelContext) async throws {
  // Track locally deleted items via a separate pendingDeletions set
  // Issue DELETE to Supabase, which triggers audit logging
}
```

### Phase 5: Delete Sync with Tombstones (v1.7 - SHIP BLOCKER)

> **CRITICAL**: Without a tombstone queue, local deletes never reach Supabase.
> When a user deletes an entity offline, we need to track that intent and sync it when online.

#### Problem Statement

SwiftData's `modelContext.delete(entity)` removes the object from local storage immediately.
Without a separate tracking mechanism:
1. The entity is gone from SwiftData
2. We have no record that a delete needs to be synced
3. The server never receives the DELETE request
4. Audit log never captures the deletion

#### Solution: PendingDeletion Tombstone Model

```swift
// Dispatch/Features/Sync/Models/PendingDeletion.swift

import Foundation
import SwiftData

/// Tombstone record that tracks local deletes pending sync to Supabase.
/// When user deletes an entity, we:
/// 1. Delete from SwiftData (immediate local effect)
/// 2. Create a PendingDeletion tombstone (tracks sync intent)
/// 3. Process tombstones on sync (issues DELETE to Supabase)
/// 4. Remove tombstone on success (sync complete)
@Model
final class PendingDeletion {
  @Attribute(.unique) var id: UUID
  var entityType: String  // AuditableEntity.rawValue
  var entityId: UUID
  var deletedAt: Date
  var retryCount: Int
  var lastError: String?

  init(entityType: AuditableEntity, entityId: UUID) {
    self.id = UUID()
    self.entityType = entityType.rawValue
    self.entityId = entityId
    self.deletedAt = Date()
    self.retryCount = 0
    self.lastError = nil
  }

  var auditableEntityType: AuditableEntity? {
    AuditableEntity(rawValue: entityType)
  }
}
```

#### Delete Flow (Local)

```swift
// Dispatch/Features/Sync/Helpers/DeleteWithTombstone.swift

import SwiftData

/// Deletes an entity locally and creates a tombstone for sync.
/// This is the ONLY way to delete auditable entities.
///
/// Usage:
/// ```
/// deleteWithTombstone(listing, type: .listing, context: modelContext)
/// ```
func deleteWithTombstone<T: PersistentModel>(
  _ entity: T,
  type: AuditableEntity,
  context: ModelContext,
  syncManager: SyncManager
) {
  // Capture ID before delete (entity will be invalid after delete)
  guard let entityId = (entity as? any Identifiable)?.id as? UUID else {
    assertionFailure("Entity must have UUID id")
    return
  }

  // 1. Delete from SwiftData (immediate local effect)
  context.delete(entity)

  // 2. Create tombstone (tracks sync intent)
  let tombstone = PendingDeletion(entityType: type, entityId: entityId)
  context.insert(tombstone)

  // 3. Save both changes atomically
  do {
    try context.save()
  } catch {
    // If save fails, both delete and tombstone are rolled back
    // This is the correct behavior - we don't want orphaned tombstones
    assertionFailure("Failed to save delete + tombstone: \(error)")
    return
  }

  // 4. Trigger sync (fire-and-forget, will retry on failure)
  Task {
    await syncManager.processPendingDeletions()
  }
}
```

#### Updated Delete Calls in Detail Views

```swift
// BEFORE (soft delete) - in ListingDetailView.swift
private func deleteListing() {
  listing.status = .deleted
  listing.deletedAt = Date()
  listing.markPending()
  syncManager.requestSync()
  dismiss()
  appState.dispatch(.removeRoute(.listing(listing.id)))
}

// AFTER (hard delete with tombstone) - in ListingDetailView.swift
private func deleteListing() {
  deleteWithTombstone(listing, type: .listing, context: modelContext, syncManager: syncManager)
  dismiss()
  appState.dispatch(.removeRoute(.listing(listing.id)))
}
```

#### Sync Loop (Tombstone Processing)

```swift
// Dispatch/Features/Sync/SyncManager+Deletions.swift

extension SyncManager {

  /// Process all pending deletion tombstones.
  /// Called on:
  /// - App startup (drain any pending from previous session)
  /// - After creating a new tombstone
  /// - On network reconnection
  func processPendingDeletions() async {
    let context = ModelContext(container)
    let descriptor = FetchDescriptor<PendingDeletion>(
      sortBy: [SortDescriptor(\.deletedAt, order: .forward)]  // FIFO order
    )

    guard let tombstones = try? context.fetch(descriptor), !tombstones.isEmpty else {
      return
    }

    for tombstone in tombstones {
      await processSingleDeletion(tombstone, context: context)
    }
  }

  private func processSingleDeletion(_ tombstone: PendingDeletion, context: ModelContext) async {
    guard let entityType = tombstone.auditableEntityType else {
      // Invalid entity type - remove corrupted tombstone
      context.delete(tombstone)
      try? context.save()
      return
    }

    do {
      // Issue DELETE to Supabase (triggers audit log on server)
      try await supabase
        .from(entityType.tableName)
        .delete()
        .eq("id", value: tombstone.entityId.uuidString)
        .execute()

      // Success - remove tombstone
      context.delete(tombstone)
      try? context.save()

      logger.info("Delete synced: \(entityType.rawValue) \(tombstone.entityId)")

    } catch {
      // Retry logic
      tombstone.retryCount += 1
      tombstone.lastError = error.localizedDescription

      if tombstone.retryCount > 5 {
        // Permanent failure - log to crash reporting but keep tombstone for manual review
        logger.error("Delete sync failed permanently after 5 retries: \(entityType.rawValue) \(tombstone.entityId) - \(error)")
        // Consider: Send to error tracking service
        // Do NOT delete tombstone - keep for manual investigation
      } else {
        logger.warning("Delete sync failed (attempt \(tombstone.retryCount)): \(entityType.rawValue) \(tombstone.entityId) - \(error)")
      }

      try? context.save()
    }
  }
}
```

#### AuditableEntity Extension for Table Names

```swift
// Add to AuditableEntity enum
extension AuditableEntity {
  /// The Supabase table name for this entity type.
  var tableName: String {
    switch self {
    case .listing: "listings"
    case .property: "properties"
    case .task: "tasks"
    case .user: "users"
    case .activity: "activities"
    }
  }
}
```

#### Startup Hook

```swift
// In AppDelegate or App init
@main
struct DispatchApp: App {
  @StateObject private var syncManager = SyncManager()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .task {
          // Drain any pending deletions from previous session
          await syncManager.processPendingDeletions()
        }
    }
  }
}
```

#### Network Reconnection Hook

```swift
// In NetworkMonitor or similar
func networkDidBecomeAvailable() {
  Task {
    await syncManager.processPendingDeletions()
  }
}
```

#### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Separate @Model for tombstones | Survives app restart, SwiftData handles persistence |
| Atomic delete + tombstone save | Either both succeed or both fail - no orphaned state |
| FIFO processing order | Preserves delete order for related entities |
| Permanent failure keeps tombstone | Allows manual investigation, prevents data loss |
| Fire-and-forget trigger | Doesn't block UI, sync happens asynchronously |

---

## E) UI Plan

### E1: HistorySection Component

**Location**: Added to `ListingDetailView`, `PropertyDetailView`, `WorkItemDetailView`, `RealtorProfileView`, `ActivityDetailView`

> **Activity Support**: ActivityDetailView gets HistorySection using the same pattern as other entities.
> Pass `currentUserId`, `userLookup`, `entityType: .activity`, `entityId: activity.id`.

**Position**: After existing sections, before bottom padding

**Design**:
```
+------------------------------------------+
|  History                            (5)  |  <- SectionHeader with count
+------------------------------------------+
|  [plus.circle]                           |
|  Created                                 |  <- Action
|  Jan 15, 2026 at 2:30 PM                |  <- Timestamp
|  by Alice Smith                          |  <- Actor
+------------------------------------------+
|  [pencil.circle]                         |
|  Updated                                 |
|  Changed: stage, price                   |  <- Summary
|  Jan 18, 2026 at 10:15 AM               |
|  by Bob Jones                            |
+------------------------------------------+
|  [trash.circle]                          |
|  Deleted                                 |
|  Jan 20, 2026 at 4:45 PM                |
|  by Carol White                          |
|  [Restore]                               |  <- CTA button
+------------------------------------------+
```

**States** (per `empty-loading-error-states.md` skill):

| State | Visual |
|-------|--------|
| Loading | Spinner centered, "Loading history..." caption |
| Empty | Clock icon, "No history available" |
| Error | Alert icon, "Failed to load history", [Retry] button |
| Data | Timeline list as designed |

### E1.1: onRestore Integration Discipline (v1.7)

> **FIX 2B**: The `onRestore` parameter determines whether the Restore CTA is shown. Call sites must pass correctly.

**When to pass `onRestore: nil`:**
- In normal entity detail views (ListingDetailView, PropertyDetailView, etc.)
- The entity exists and is being viewed normally
- No restore capability needed (entity isn't deleted)

**When to pass `onRestore: { ... }`:**
- In RecentlyDeletedView when viewing deleted items
- In DeletedEntityView for deep links to deleted entities
- Any context where the entity is deleted and restorable

**Code examples:**

```swift
// NORMAL DETAIL VIEW - entity exists, no restore needed
HistorySection(
  entityType: .listing,
  entityId: listing.id,
  currentUserId: currentUserId,
  userLookup: userLookup,
  supabase: supabase,
  onRestore: nil  // No restore button shown
)

// RECENTLY DELETED CONTEXT - entity is deleted, restore is possible
HistorySection(
  entityType: entry.entityType,
  entityId: entry.entityId,
  currentUserId: currentUserId,
  userLookup: userLookup,
  supabase: supabase,
  onRestore: { entry in
    try await AuditSyncHandler(supabase: supabase).restoreEntity(entry.entityType, entityId: entry.entityId)
  }
)
```

**The gating logic in HistorySection:**
- `historyList` checks `onRestore != nil` before showing restore UI
- `restoreEntry()` guards on `onRestore` existence for defensive programming
- DELETE entries without `onRestore` closure display like other entries (no button)

**Components**:

```swift
// Dispatch/Features/Audit/Views/HistorySection.swift

struct HistorySection: View {
  let entityType: AuditableEntity
  let entityId: UUID
  let currentUserId: UUID  // Logged-in user's ID for "You" label
  let userLookup: (UUID) -> User?
  let supabase: SupabaseClient  // FIX Blocker 3: Add supabase parameter
  let onRestore: ((AuditEntry) async throws -> Void)?

  @State private var entries: [AuditEntry] = []
  @State private var isLoading = true
  @State private var error: Error?
  @State private var isExpanded = true
  // FIX (Swift/UI Issue 3): Default collapsed - show last 5 events
  @State private var showAllHistory = false
  // FIX Polish 6: Toast state (moved here for body access)
  @State private var restoreToastMessage: String?

  /// Show first 5 entries by default, all when expanded
  private var displayedEntries: [AuditEntry] {
    showAllHistory ? entries : Array(entries.prefix(5))
  }

  // FIX Polish 6: Add toast overlay to body
  var body: some View {
    DisclosureGroup(isExpanded: $isExpanded) {
      content
    } label: {
      sectionHeader
    }
    // FIX 2C (v1.7): Use .task(id:) to prevent re-firing on unrelated state changes
    // Without id:, the task re-fires whenever any parent view state changes
    // With id: entityId, it only re-fires when the entity being viewed changes
    .task(id: entityId) { await loadHistory() }
    .overlay(alignment: .bottom) {
      // FIX Polish 6: Render toast when restoreToastMessage is set
      if let message = restoreToastMessage {
        Text(message)
          .font(DS.Typography.caption)
          .padding(.horizontal, DS.Spacing.md)
          .padding(.vertical, DS.Spacing.sm)
          .background(DS.Colors.surfaceSecondary)
          .cornerRadius(DS.CornerRadius.md)
          .transition(.move(edge: .bottom).combined(with: .opacity))
          .animation(.easeInOut, value: restoreToastMessage)
      }
    }
  }

  private var sectionHeader: some View {
    HStack {
      Text("History")
        .font(DS.Typography.headline)
        .foregroundColor(DS.Colors.Text.primary)
      Text("(\(entries.count))")
        .font(DS.Typography.bodySecondary)
        .foregroundColor(DS.Colors.Text.secondary)
      Spacer()
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("History, \(entries.count)")
  }

  @ViewBuilder
  private var content: some View {
    if isLoading {
      loadingState
    } else if let error {
      errorState(error)
    } else if entries.isEmpty {
      emptyState
    } else {
      historyList
    }
  }

  private var loadingState: some View {
    VStack(spacing: DS.Spacing.sm) {
      ProgressView()
      Text("Loading history...")
        .font(DS.Typography.caption)
        .foregroundColor(DS.Colors.Text.secondary)
    }
    .padding(.vertical, DS.Spacing.lg)
  }

  private var emptyState: some View {
    VStack(spacing: DS.Spacing.sm) {
      Image(systemName: "clock")
        .font(.system(size: 32))
        .foregroundColor(DS.Colors.Text.tertiary)
      Text("No history available")
        .font(DS.Typography.body)
        .foregroundColor(DS.Colors.Text.secondary)
    }
    .padding(.vertical, DS.Spacing.lg)
  }

  private func errorState(_ error: Error) -> some View {
    VStack(spacing: DS.Spacing.sm) {
      Image(systemName: DS.Icons.Alert.error)
        .font(.system(size: 32))
        .foregroundColor(DS.Colors.destructive)
      Text("Failed to load history")
        .font(DS.Typography.body)
        .foregroundColor(DS.Colors.Text.secondary)
      Button("Retry") {
        Task { await loadHistory() }
      }
      .buttonStyle(.bordered)
    }
    .padding(.vertical, DS.Spacing.lg)
  }

  // FIX (Swift/UI Issue 3): Show 5 entries by default with "Show all" button
  // FIX Polish 8: Wrap UPDATE rows in NavigationLink to HistoryDetailView
  // FIX Issue E (v1.5): Use explicit id: \.id for AuditEntry arrays
  // FIX 3 (v1.6): Only show restore if onRestore exists
  private var historyList: some View {
    VStack(spacing: 0) {
      ForEach(displayedEntries, id: \.id) { entry in
        // FIX Polish 8: Wrap UPDATE rows in NavigationLink for diff view
        if entry.action == .update {
          NavigationLink(destination: HistoryDetailView(entry: entry, userLookup: userLookup)) {
            HistoryEntryRow(
              entry: entry,
              currentUserId: currentUserId,
              userLookup: userLookup,
              onRestore: nil  // No restore for UPDATE entries
            )
          }
          .buttonStyle(.plain)  // Keep row styling consistent
        } else if entry.action == .delete, onRestore != nil {
          // FIX 3 (v1.6): Only show restore CTA when onRestore closure exists
          HistoryEntryRow(
            entry: entry,
            currentUserId: currentUserId,
            userLookup: userLookup,
            onRestore: { await restoreEntry(entry) }
          )
        } else {
          // Non-delete entries or delete entries without restore capability
          HistoryEntryRow(
            entry: entry,
            currentUserId: currentUserId,
            userLookup: userLookup,
            onRestore: nil
          )
        }
        if entry.id != displayedEntries.last?.id {
          Divider()
        }
      }

      // "Show all X events" button when there are more than 5
      if entries.count > 5 && !showAllHistory {
        Button {
          withAnimation { showAllHistory = true }
        } label: {
          Text("Show all \(entries.count) events")
            .font(DS.Typography.caption)
            .foregroundColor(DS.Colors.accentColor)
        }
        .padding(.top, DS.Spacing.sm)
      }
    }
  }

  // FIX Blocker 3: Use supabase parameter instead of undefined variable
  private func loadHistory() async {
    isLoading = true
    error = nil
    do {
      entries = try await AuditSyncHandler(supabase: supabase).fetchHistory(
        for: entityType,
        entityId: entityId
      )
    } catch {
      self.error = error
    }
    isLoading = false
  }

  // FIX (Swift/UI Issue 3): Show toast + refresh after restore
  // Note: @State restoreToastMessage moved to top of struct for body access (Polish 6)
  // FIX 3 (v1.6): Guard on onRestore existence for safety

  private func restoreEntry(_ entry: AuditEntry) async {
    // FIX 3 (v1.6): Guard inside restoreEntry for defensive programming
    guard let onRestore else {
      restoreToastMessage = "Restore unavailable"
      return
    }

    do {
      try await onRestore(entry)
      // Show success toast
      restoreToastMessage = "\(entityType.displayName) restored successfully"
      // Refresh history to show RESTORE entry
      await loadHistory()
      // Auto-dismiss toast after 3 seconds
      Task {
        try? await Task.sleep(for: .seconds(3))
        restoreToastMessage = nil
      }
    } catch {
      // Error handling via toast/alert - show error message
      restoreToastMessage = error.localizedDescription
    }
  }
}
```

```swift
// Dispatch/Features/Audit/Views/HistoryEntryRow.swift

struct HistoryEntryRow: View {
  let entry: AuditEntry
  let currentUserId: UUID  // The logged-in user's ID
  let userLookup: (UUID) -> User?
  let onRestore: (() async -> Void)?

  @State private var isRestoring = false

  // FIX Issue A (v1.5): Compute actor name for AuditSummaryBuilder
  private var actorName: String {
    guard let userId = entry.changedBy else { return "System" }
    if userId == currentUserId { return "You" }
    if let user = userLookup(userId) { return user.name }
    return "Someone"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
      HStack {
        Image(systemName: entry.action.icon)
          .foregroundColor(entry.action.color)
          .accessibilityHidden(true)
        Text(entry.action.displayName)
          .font(DS.Typography.headline)
        Spacer()
        if entry.action == .delete, let onRestore {
          restoreButton(onRestore)
        }
      }

      // FIX Issue A (v1.5): Use AuditSummaryBuilder for human-readable summaries
      Text(AuditSummaryBuilder(entry: entry, actorName: actorName, entityType: entry.entityType).build())
        .font(DS.Typography.caption)
        .foregroundColor(DS.Colors.Text.secondary)

      HStack(spacing: DS.Spacing.xs) {
        Text(entry.changedAt.formatted(date: .abbreviated, time: .shortened))
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.Text.tertiary)

        actorLabel
      }
    }
    .padding(.vertical, DS.Spacing.sm)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
  }

  /// Displays "You", user name, "Someone" (for unknown users), or "System"
  ///
  /// Logic:
  /// - changedBy == nil → "System" (automated/scheduled job)
  /// - changedBy == currentUserId → "You"
  /// - changedBy in userLookup → user's name
  /// - changedBy exists but not in lookup → "Someone" (teammate not in cache)
  @ViewBuilder
  private var actorLabel: some View {
    if let userId = entry.changedBy {
      if userId == currentUserId {
        // Only show "You" if it's actually the current logged-in user
        Text("by You")
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.Text.tertiary)
      } else if let user = userLookup(userId) {
        // Known teammate
        Text("by \(user.name)")
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.Text.tertiary)
      } else {
        // User exists but not in our lookup (teammate we don't have cached)
        Text("by Someone")
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.Text.tertiary)
      }
    } else {
      // No user ID = system/automated change
      Text("by System")
        .font(DS.Typography.caption)
        .foregroundColor(DS.Colors.Text.tertiary)
    }
  }

  private func restoreButton(_ action: @escaping () async -> Void) -> some View {
    Button {
      Task {
        isRestoring = true
        await action()
        isRestoring = false
      }
    } label: {
      if isRestoring {
        ProgressView()
          .controlSize(.small)
      } else {
        Text("Restore")
      }
    }
    .buttonStyle(.bordered)
    .disabled(isRestoring)
  }

  // Accessibility label uses AuditSummaryBuilder for consistency
  private var accessibilityLabel: String {
    let summary = AuditSummaryBuilder(entry: entry, actorName: actorName, entityType: entry.entityType).build()
    let timestamp = entry.changedAt.formatted(date: .abbreviated, time: .shortened)
    return "\(summary), \(timestamp)"
  }
}
```

### E2: HistoryDetailView (Diff View)

**Triggered by**: Tapping a history entry row (for UPDATE actions)

```swift
// Dispatch/Features/Audit/Views/HistoryDetailView.swift

struct HistoryDetailView: View {
  let entry: AuditEntry
  let userLookup: (UUID) -> User?

  var body: some View {
    StandardScreen(title: entry.action.displayName) {
      VStack(alignment: .leading, spacing: DS.Spacing.lg) {
        metadata
        changesSection
      }
    }
  }

  private var metadata: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
      Text(entry.changedAt.formatted(date: .long, time: .shortened))
        .font(DS.Typography.body)
        .foregroundColor(DS.Colors.Text.secondary)

      if let userId = entry.changedBy, let user = userLookup(userId) {
        Text("by \(user.name)")
          .font(DS.Typography.body)
          .foregroundColor(DS.Colors.Text.secondary)
      }
    }
  }

  @ViewBuilder
  private var changesSection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      Text("Changes")
        .font(DS.Typography.headline)
      Divider()

      if let diffs = computeDiffs() {
        ForEach(diffs, id: \.field) { diff in
          DiffRow(diff: diff)
        }
      } else {
        Text("Unable to compute changes")
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.Text.tertiary)
      }
    }
  }

  // FIX Issue B (v1.5): Implement real diff computation
  // Improvement B (v1.6): Use stringify() helper to avoid "Optional(...)" in output
  private func computeDiffs() -> [FieldDiff]? {
    guard let oldRow = entry.oldRow, let newRow = entry.newRow else { return nil }

    let ignored = Set(["id", "sync_status", "pending_changes", "created_at", "updated_at"])
    let keys = Set(oldRow.keys).union(newRow.keys).subtracting(ignored)

    let diffs = keys.compactMap { key -> FieldDiff? in
      // Improvement B (v1.6): Use stringify() instead of String(describing:)
      let oldVal = stringify(oldRow[key]?.value)
      let newVal = stringify(newRow[key]?.value)
      guard oldVal != newVal else { return nil }

      let label = AuditEntryDTO.fieldLabels[key] ?? key.replacingOccurrences(of: "_", with: " ").capitalized
      return FieldDiff(field: label, oldValue: formatDiffValue(oldVal, for: key),
                       newValue: formatDiffValue(newVal, for: key))
    }

    return diffs.sorted { $0.field < $1.field }
  }

  // Improvement B (v1.6): Stringify normalizer for diff values
  // String(describing:) can produce "Optional(...)" style strings - this handles it cleanly
  private func stringify(_ any: Any?) -> String {
    guard let any else { return "" }
    if let s = any as? String { return s }
    if let n = any as? NSNumber { return n.stringValue }
    return String(describing: any)
  }

  private func formatDiffValue(_ value: String, for field: String) -> String {
    if value.isEmpty { return "none" }

    // Format prices
    if field == "price", let number = Double(value) {
      let formatter = NumberFormatter()
      formatter.numberStyle = .currency
      formatter.maximumFractionDigits = 0
      return formatter.string(from: NSNumber(value: number)) ?? value
    }

    // Format dates
    if field.contains("date") || field.contains("_at"), let date = ISO8601DateFormatter().date(from: value) {
      return date.formatted(date: .abbreviated, time: .shortened)
    }

    // Format booleans
    if value == "true" { return "Yes" }
    if value == "false" { return "No" }

    // Format UUIDs (show first 8 chars)
    if value.count == 36 && value.contains("-") {
      return String(value.prefix(8)) + "..."
    }

    return value
  }
}

struct FieldDiff {
  let field: String
  let oldValue: String
  let newValue: String
}

struct DiffRow: View {
  let diff: FieldDiff

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
      Text(diff.field.capitalized)
        .font(DS.Typography.headline)

      HStack {
        Text("- \(diff.oldValue)")
          .font(DS.Typography.body)
          .foregroundColor(DS.Colors.Status.deleted)
        Spacer()
        Text("OLD")
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.Text.tertiary)
      }

      HStack {
        Text("+ \(diff.newValue)")
          .font(DS.Typography.body)
          .foregroundColor(DS.Colors.Status.open)
        Spacer()
        Text("NEW")
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.Text.tertiary)
      }
    }
    .padding(.vertical, DS.Spacing.sm)
  }
}
```

### E3: RecentlyDeletedView

**Access Point**: Settings screen or dedicated navigation item

> **Activity Support**: Activities appear in the Recently Deleted list.
> - Filter picker includes "Activity" option (via `AuditableEntity.allCases`)
> - ActivityRow uses activity-specific icon (`DS.Icons.Entity.activity`) and display name

```swift
// Dispatch/Features/Audit/Views/RecentlyDeletedView.swift

// FIX 2 (v1.6): Replace tuple with Identifiable struct for navigation
// Tuples don't conform to Identifiable, so .navigationDestination(item:) won't compile
struct RestoredNavTarget: Identifiable, Hashable {
  let type: AuditableEntity
  let id: UUID
}

struct RecentlyDeletedView: View {
  // FIX Issue C (v1.5): Add supabase parameter
  let supabase: SupabaseClient

  @State private var entries: [AuditEntry] = []
  @State private var filter: AuditableEntity? = nil
  @State private var isLoading = true
  @State private var error: Error?
  // FIX 2 (v1.6): Use RestoredNavTarget struct instead of tuple
  @State private var restoredEntityNavigation: RestoredNavTarget?

  var body: some View {
    StandardScreen(title: "Recently Deleted", layout: .list) {
      content
    }
    .task { await loadDeletedItems() }
    // FIX 2 (v1.6): Navigation destination for restored entity
    .navigationDestination(item: $restoredEntityNavigation) { nav in
      destinationView(for: nav.type, id: nav.id)
    }
  }

  // FIX Issue 6 (v1.5): Route to appropriate detail view after restore
  @ViewBuilder
  private func destinationView(for entityType: AuditableEntity, id: UUID) -> some View {
    switch entityType {
    case .listing:
      ListingDetailView(listingId: id)
    case .property:
      PropertyDetailView(propertyId: id)
    case .task:
      WorkItemDetailView(taskId: id)
    case .user:
      RealtorProfileView(userId: id)
    case .activity:
      ActivityDetailView(activityId: id)
    }
  }

  // FIX 2A (v1.7): groupedList returns Section which must be inside List
  // Without List wrapper, Section doesn't render correctly
  @ViewBuilder
  private var content: some View {
    filterPicker

    if isLoading {
      loadingState
    } else if let error {
      errorState(error)
    } else if filteredEntries.isEmpty {
      emptyState
    } else {
      // FIX 2A: Wrap groupedList in List for proper Section rendering
      List {
        groupedList
      }
      .listStyle(.insetGrouped)
    }
  }

  private var filterPicker: some View {
    Picker("Filter", selection: $filter) {
      Text("All").tag(nil as AuditableEntity?)
      ForEach(AuditableEntity.allCases, id: \.self) { entity in
        Text(entity.displayName).tag(entity as AuditableEntity?)
      }
    }
    .pickerStyle(.segmented)
    .padding(.horizontal, DS.Spacing.md)
  }

  private var filteredEntries: [AuditEntry] {
    guard let filter else { return entries }
    return entries.filter { $0.entityType == filter }
  }

  private var loadingState: some View {
    VStack(spacing: DS.Spacing.md) {
      ProgressView()
      Text("Loading...")
        .font(DS.Typography.caption)
        .foregroundColor(DS.Colors.Text.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var emptyState: some View {
    VStack(spacing: DS.Spacing.md) {
      Image(systemName: "trash")
        .font(.system(size: 48))
        .foregroundColor(DS.Colors.Text.tertiary)
      Text("No deleted items")
        .font(DS.Typography.headline)
        .foregroundColor(DS.Colors.Text.secondary)
      Text("Items you delete will appear here")
        .font(DS.Typography.caption)
        .foregroundColor(DS.Colors.Text.tertiary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func errorState(_ error: Error) -> some View {
    VStack(spacing: DS.Spacing.md) {
      Image(systemName: DS.Icons.Alert.error)
        .font(.system(size: 48))
        .foregroundColor(DS.Colors.destructive)
      Text("Failed to load")
        .font(DS.Typography.headline)
        .foregroundColor(DS.Colors.Text.secondary)
      Button("Retry") {
        Task { await loadDeletedItems() }
      }
      .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // FIX Issue E (v1.5): Use explicit id: \.id for AuditEntry arrays
  private var groupedList: some View {
    // Group by date using Dictionary(grouping:)
    let grouped = Dictionary(grouping: filteredEntries) { entry in
      Calendar.current.startOfDay(for: entry.changedAt)
    }
    let sortedDates = grouped.keys.sorted(by: >)

    return ForEach(sortedDates, id: \.self) { date in
      Section(header: Text(date.formatted(date: .abbreviated, time: .omitted))) {
        ForEach(grouped[date] ?? [], id: \.id) { entry in
          RecentlyDeletedRow(entry: entry) {
            await restoreEntry(entry)
          }
        }
      }
    }
  }

  private func loadDeletedItems() async {
    isLoading = true
    error = nil
    do {
      entries = try await AuditSyncHandler(supabase: supabase).fetchRecentlyDeleted()
    } catch {
      self.error = error
    }
    isLoading = false
  }

  // FIX Issue 6 (v1.5): Navigate to restored entity after successful restore
  // FIX 2 (v1.6): Use RestoredNavTarget struct instead of tuple
  private func restoreEntry(_ entry: AuditEntry) async {
    do {
      let restoredId = try await AuditSyncHandler(supabase: supabase).restoreEntity(entry.entityType, entityId: entry.entityId)
      // Remove from list and navigate to restored entity
      entries.removeAll { $0.id == entry.id }
      restoredEntityNavigation = RestoredNavTarget(type: entry.entityType, id: restoredId)
    } catch {
      // Error handling - show alert or toast
      self.error = error
    }
  }
}
```

```swift
// Dispatch/Features/Audit/Views/RecentlyDeletedRow.swift

struct RecentlyDeletedRow: View {
  let entry: AuditEntry
  let onRestore: () async -> Void

  @State private var isRestoring = false

  var body: some View {
    HStack(spacing: DS.Spacing.md) {
      Image(systemName: entry.entityType.icon)
        .foregroundColor(entry.entityType.color)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
        // FIX Issue D (v1.5): Use displayTitle extension property
        Text(entry.displayTitle)
          .font(DS.Typography.body)
          .foregroundColor(DS.Colors.Text.primary)
        Text("\(entry.entityType.displayName) - Deleted \(entry.changedAt.relative)")
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.Text.secondary)
      }

      Spacer()

      Button {
        Task {
          isRestoring = true
          await onRestore()
          isRestoring = false
        }
      } label: {
        if isRestoring {
          ProgressView().controlSize(.small)
        } else {
          Text("Restore")
        }
      }
      .buttonStyle(.bordered)
      .disabled(isRestoring)
    }
    .padding(.vertical, DS.Spacing.xs)
  }
}
```

### E4: Copy Guidelines

| Context | Copy |
|---------|------|
| History section header | "History" |
| Empty history | "No history available" |
| Loading history | "Loading history..." |
| Created action | "Created" |
| Updated action | "Updated" |
| Deleted action | "Deleted" |
| Restored action | "Restored" |
| Restore button | "Restore" |
| Restore success toast | "[Entity] restored successfully" |
| Restore conflict error | "Cannot restore - a [entity] with this [field] already exists" |
| Restore FK error | "Cannot restore - the [related entity] no longer exists" |
| Recently Deleted title | "Recently Deleted" |
| Empty recently deleted | "No deleted items", "Items you delete will appear here" |
| Filter: All | "All" |
| Actor: self | "You" (only when `changedBy == currentUserId`) |
| Actor: unknown | "Someone" (user exists but not in cache) |
| Actor: system | "System" (when `changedBy` is null) |
| Actor: other | "[Name]" (from user lookup) |

#### Human-Readable Change Summaries

Instead of developer-speak like "Changed: stage, price", use human-friendly labels:

| Database Column | Display Label |
|-----------------|---------------|
| `stage` | "Status" |
| `price` | "Price" |
| `assigned_to` | "Assignment" |
| `due_date` | "Due date" |
| `mls_number` | "MLS number" |
| `owned_by` | "Owner" |
| `property_type` | "Property type" |

**Summary format examples**:
- Single field: "Status changed"
- Two fields: "Status, Price changed"
- Three fields: "Status, Price, Assignment changed"
- Many fields: "5 fields changed"

### E5: New Design System Components

These components support the History feature across all entity types (including Activities):

| Component | Purpose | Usage |
|-----------|---------|-------|
| `TimelineRow` | Single audit entry in a timeline list | Used in HistorySection for all entities |
| `DiffGrid` | Two-column before/after comparison | Used in HistoryDetailView for UPDATE diffs |
| `ChangeChip` | Small pill showing field name + change type | Optional enhancement for UPDATE summaries |
| `RestoreButton` | Standardized restore CTA with loading state | Used in HistorySection and RecentlyDeletedRow |

**Design principles**:
- Minimal and composable (no God components)
- Consistent spacing via `DS.Spacing.*`
- Consistent typography via `DS.Typography.*`
- Accessibility first (VoiceOver labels, Dynamic Type)
- Reusable across all 5 entity types

---

## F) Edge Cases + Failure Modes

### F1: Deep Link to Deleted Record

**Scenario**: User follows link to `/listing/abc-123` but listing was deleted.

**Handling**:
1. Primary fetch returns empty/404
2. Check audit table for DELETE record with matching `record_pk`
3. Show `DeletedEntityView`:
   - When deleted (relative time)
   - Who deleted it
   - [Restore] button (if authorized)
   - [Go Back] button

```swift
struct DeletedEntityView: View {
  let entityType: AuditableEntity
  let entityId: UUID
  let deleteEntry: AuditEntry?

  var body: some View {
    VStack(spacing: DS.Spacing.xl) {
      Image(systemName: "trash.circle")
        .font(.system(size: 64))
        .foregroundColor(DS.Colors.Text.tertiary)

      Text("This \(entityType.displayName.lowercased()) was deleted")
        .font(DS.Typography.title)
        .multilineTextAlignment(.center)

      if let entry = deleteEntry {
        Text("Deleted \(entry.changedAt.relative)")
          .font(DS.Typography.body)
          .foregroundColor(DS.Colors.Text.secondary)
      }

      Button("Restore") { /* restore logic */ }
        .buttonStyle(.borderedProminent)

      Button("Go Back") { dismiss() }
        .buttonStyle(.bordered)
    }
    .padding(DS.Spacing.xl)
  }
}
```

### F2: Unique Constraint Conflict on Restore

**Scenario**: Restore listing with MLS number that now exists on another listing.

**Handling**:
```sql
-- In restore function
EXCEPTION WHEN unique_violation THEN
  RAISE EXCEPTION 'UNIQUE_CONFLICT:%', (SELECT constraint_name FROM pg_constraint WHERE ...);
```

**App UI**:
- Alert: "Cannot restore - a listing with this MLS number already exists"
- Options: [Cancel] [View Existing]

### F3: Missing Foreign Key on Restore

**Scenario**: Restore task that referenced `listing_id` that no longer exists.

**Handling** (Strict mode):
```sql
-- In restore function
IF (v_old_row->>'listing_id')::UUID IS NOT NULL THEN
  IF NOT EXISTS (SELECT 1 FROM public.listings WHERE id = (v_old_row->>'listing_id')::UUID) THEN
    RAISE EXCEPTION 'FK_MISSING:listing';
  END IF;
END IF;
```

**App UI**:
- Alert: "Cannot restore - the listing this task was linked to no longer exists"
- Single option: [OK]

### F4: Multiple Delete/Restore Cycles

**Scenario**: Entity deleted, restored, deleted again.

**Handling**:
- Each delete creates new audit entry
- Restore always uses most recent DELETE
- History shows full lifecycle: Created -> Deleted -> Restored -> Deleted
- All snapshots preserved for forensics

### F5: System vs User Changes

**Scenario**: Changes made by scheduled jobs (no user context).

**Handling**:
- `changed_by` is NULL when `auth.uid()` is NULL
- UI shows "System" instead of user name
- Future: Filter option "Hide system changes"

### F6: Offline Behavior

**Scenario**: User deletes entity while offline, then views history.

**Handling**:
- Delete is queued locally (existing sync mechanism)
- History section shows: "Pending changes - will sync when online"
- Once synced, audit entry appears in history
- Recently Deleted only shows server-confirmed deletes
- Restore button disabled offline with tooltip "Requires connection"

### F7: Large History (Performance)

**Scenario**: Entity with 500+ history entries.

**Handling**:
- Initial fetch limited to 50 entries
- "Load more" pagination at bottom
- Index on `changed_at DESC` for fast recent queries
- Future: Consider auto-archive entries older than 1 year

### F8: Concurrent Restore Attempts

**Scenario**: Two users try to restore same entity simultaneously.

**Handling**:
- First restore succeeds
- Second gets `ALREADY_EXISTS` error
- UI shows: "This item was just restored by someone else"
- Auto-refresh list to show restored item

---

## G) Rollout Plan

### Phase 1: Database Only (PATCHSET 1.5)

**Owner**: data-integrity agent

| Step | Action | Rollback |
|------|--------|----------|
| 1 | Create audit schema | `DROP SCHEMA audit CASCADE;` |
| 2 | Create audit tables | `DROP TABLE audit.X_log;` |
| 3 | Create trigger function | `DROP FUNCTION audit.log_changes();` |
| 4 | Attach triggers | `DROP TRIGGER audit_X_changes ON public.X;` |
| 5 | Create restore functions | `DROP FUNCTION audit.restore_X(UUID);` |
| 6 | Add RLS policies | `DROP POLICY ON audit.X_log;` |

**Verification**:
- Manual INSERT/UPDATE/DELETE on each table creates audit entry
- Supabase dashboard shows audit tables populating
- No performance regression on entity operations

### Phase 2: App Read-Only (PATCHSET 2)

**Owner**: feature-owner

| Step | Action |
|------|--------|
| 1 | Add `AuditEntry` model + DTO |
| 2 | Add `AuditSyncHandler` (fetch only) |
| 3 | Add `HistorySection` component |
| 4 | Integrate into 4 detail views |
| 5 | Add loading/empty/error states |

**Verification**:
- History section loads on all entity detail views
- Shows correct entries with timestamps and actors
- Existing soft delete still works

### Phase 3: Restore + Hard Delete (PATCHSET 2.5)

**Owner**: feature-owner + jobs-critic

| Step | Action |
|------|--------|
| 1 | Enable Restore button in `HistorySection` |
| 2 | Switch delete flows to hard delete |
| 3 | Update sync handlers for DELETE operations |
| 4 | Add `RecentlyDeletedView` |
| 5 | Wire up navigation to Recently Deleted |

**Verification**:
- Delete -> Restore cycle works for all entity types
- Audit entries created on delete
- Restored entities fully functional
- Recently Deleted shows all types with filters

### Phase 4: Cleanup (Post-Rollout)

**Timing**: 2 weeks after Phase 3 stable

| Step | Action |
|------|--------|
| 1 | Monitor for issues |
| 2 | Remove `deleted_at` columns |
| 3 | Implement retention policy (optional) |

---

## H) Done Checklist

### Database (PATCHSET 1.5)

- [ ] audit schema created
- [ ] audit.listings_log table created with indexes
- [ ] audit.properties_log table created with indexes
- [ ] audit.tasks_log table created with indexes
- [ ] audit.users_log table created with indexes
- [ ] audit.activities_log table created with indexes
- [ ] audit.log_changes() trigger function deployed
- [ ] Triggers attached to all 5 tables (including activities)
- [ ] **public.get_entity_history() RPC function deployed (supports activity type)**
- [ ] **public.get_recently_deleted() RPC function deployed (supports activity type)**
- [ ] **v1.6 Improvement A: get_recently_deleted uses CTE pre-limit pattern for efficiency**
- [ ] **public.restore_entity() RPC function deployed (supports activity type)**
- [ ] RLS policies on audit tables
- [ ] Manual test: INSERT/UPDATE/DELETE creates audit entries
- [ ] **Manual test: RPC functions return correct data**

### App Models (PATCHSET 2)

- [ ] AuditEntry model created
- [ ] AuditAction enum created (includes RESTORE action)
- [ ] AuditableEntity enum created (includes .activity case)
- [ ] AuditEntryDTO created with CodingKeys
- [ ] **Human-readable field labels mapping implemented**
- [ ] **Activity field labels added (declared_by, activity_type, outcome, contact_method)**
- [ ] AuditSyncHandler.fetchHistory() works (via RPC only)
- [ ] AuditSyncHandler.fetchRecentlyDeleted() works (via RPC only)
- [ ] RestoreError enum with parsing
- [ ] Unit tests for DTOs
- [ ] **v1.3 FIX Blocker 2A: Single fieldLabels definition (internal access)**
- [ ] **v1.3 FIX Blocker 2B: AuditEntry has @Transient oldRow/newRow for summary building**
- [ ] **v1.3 FIX Blocker 2B: DTO.toModel() copies row data to model**
- [ ] **v1.5 FIX: AuditSummaryBuilder takes AuditEntry + actorName + entityType**
- [ ] **v1.5 FIX Issue 5: DTO.computeSummary() returns simple action names only ("Created", "Updated")**
- [ ] **v1.6 FIX 1: AuditableEntity has color property extension with SwiftUI import**
- [ ] **v1.6 FIX 4: AuditAction file has `import SwiftUI` for Color usage**
- [ ] **v1.7 FIX 2D: AuditEntry is struct (not @Model) - no SwiftData persistence**
- [ ] **v1.7 FIX 1A: RestoreError.from() parses FK_MISSING: and UNIQUE_CONFLICT: prefixes**

### UI - History (PATCHSET 2)

- [ ] HistorySection component created (with currentUserId param)
- [ ] HistoryEntryRow component created (with fixed actor label logic)
- [ ] HistoryDetailView (diff) created
- [ ] **"You" label only shows when changedBy == currentUserId**
- [ ] **"Someone" label for unknown users (not in cache)**
- [ ] **Human-readable change summaries (e.g., "Status changed" not "stage")**
- [ ] Added to ListingDetailView
- [ ] Added to PropertyDetailView
- [ ] Added to WorkItemDetailView (tasks)
- [ ] Added to RealtorProfileView
- [ ] Added to ActivityDetailView
- [ ] Loading state implemented
- [ ] Empty state implemented
- [ ] **v1.5 FIX Issue A: HistoryEntryRow uses AuditSummaryBuilder(entry:actorName:entityType:).build()**
- [ ] **v1.5 FIX Issue A: HistoryEntryRow has actorName computed property**
- [ ] **v1.5 FIX Issue B: HistoryDetailView.computeDiffs() fully implemented with formatDiffValue()**
- [ ] **v1.5 FIX Issue E: All ForEach on AuditEntry use explicit id: \.id**
- [ ] Error state with retry implemented
- [ ] Accessibility labels on all components
- [ ] **v1.3 FIX Blocker 3: HistorySection takes supabase parameter**
- [ ] **v1.3 FIX Polish 6: Toast overlay renders in HistorySection body**
- [ ] **v1.3 FIX Polish 7: RESTORE copy includes entity type ("restored this listing")**
- [ ] **v1.3 FIX Polish 8: UPDATE rows wrapped in NavigationLink to HistoryDetailView**
- [ ] **v1.6 FIX 3: HistorySection gates restore UI on `onRestore != nil`**
- [ ] **v1.6 FIX 3: HistorySection.restoreEntry() guards on onRestore existence**
- [ ] **v1.6 Improvement B: HistoryDetailView.computeDiffs() uses stringify() helper**
- [ ] **v1.7 FIX 2C: HistorySection uses .task(id: entityId) to prevent re-firing**

### UI - Recently Deleted (PATCHSET 2.5)

- [ ] RecentlyDeletedView created
- [ ] **v1.5 FIX Issue C: RecentlyDeletedView takes supabase parameter**
- [ ] RecentlyDeletedRow created
- [ ] **v1.5 FIX Issue D: AuditableEntity has color property**
- [ ] **v1.5 FIX Issue D: AuditEntry has displayTitle extension (not displayName)**
- [ ] **v1.5 FIX Issue 6: RecentlyDeletedView has restoredEntityNavigation state**
- [ ] **v1.5 FIX Issue 6: RecentlyDeletedView.restoreEntry() navigates to restored entity**
- [ ] **v1.6 FIX 2: RestoredNavTarget struct (Identifiable, Hashable) for navigation**
- [ ] **v1.6 FIX 2: RecentlyDeletedView uses RestoredNavTarget instead of tuple**
- [ ] **v1.7 FIX 2A: groupedList wrapped in List for proper Section rendering**
- [ ] Filter picker (by entity type, includes Activity option)
- [ ] Activities appear in Recently Deleted list with correct icon
- [ ] Date grouping
- [ ] Navigation wired up
- [ ] Loading/empty/error states

### Restore Flow (PATCHSET 2.5)

- [ ] AuditSyncHandler.restoreEntity() works
- [ ] Restore button in HistorySection
- [ ] Restore button in RecentlyDeletedRow
- [ ] Success toast on restore
- [ ] Error handling for all RestoreError cases
- [ ] Refresh after restore

### Hard Delete Migration (PATCHSET 2.5)

- [ ] ListingSyncHandler uses hard delete
- [ ] PropertySyncHandler uses hard delete
- [ ] TaskSyncHandler uses hard delete
- [ ] ActivitySyncHandler uses hard delete
- [ ] SwiftData deletion syncs correctly
- [ ] Triggers capture delete with full row
- [ ] No regressions in existing delete flows
- [ ] **v1.7 Phase 5: PendingDeletion @Model created for tombstone queue**
- [ ] **v1.7 Phase 5: deleteWithTombstone() helper function implemented**
- [ ] **v1.7 Phase 5: SyncManager.processPendingDeletions() implemented**
- [ ] **v1.7 Phase 5: AuditableEntity.tableName extension added**
- [ ] **v1.7 Phase 5: Startup hook drains pending deletions**
- [ ] **v1.7 Phase 5: Network reconnection triggers tombstone processing**

### Validation (PATCHSET 3)

- [ ] xcode-pilot: Delete -> Restore cycle
- [ ] xcode-pilot: Deep link to deleted entity
- [ ] xcode-pilot: Multiple delete/restore cycles
- [ ] xcode-pilot: History loads on all entity types (including Activity)
- [ ] xcode-pilot: Activity restore works correctly
- [ ] Performance: History loads in <500ms
- [ ] Offline: Pending delete shown correctly
- [ ] **v1.5 Test 1: Delete -> Restore -> Delete -> Restore cycle passes**
- [ ] **v1.5 Test 2: Restore with FK missing shows clear error**
- [ ] **v1.5 Test 3: Restore with unique conflict shows clear error**
- [ ] **v1.5 Test 4: Invalid UUID garbage in JSONB does not crash**
- [ ] **v1.5 Test 5: get_recently_deleted global ordering returns exactly limit items**
- [ ] **v1.6 Test 6: Diff view does not show "Optional(...)" in any values (stringify helper)**
- [ ] **v1.6 Test 7: HistorySection with nil onRestore hides restore button**
- [ ] **v1.7 Test 8: Schema migration - restore after column addition succeeds**
- [ ] **v1.7 Test 9: Tombstone delete sync - offline delete syncs on reconnect**

### Database Design Verification (v1.7)

- [ ] **v1.7 FIX 1A: restore_entity() EXCEPTION blocks use FK_MISSING: and UNIQUE_CONFLICT: prefixes**
- [ ] **v1.7 FIX 1B: Verified all audited tables have `id UUID` as primary key**
- [ ] **v1.7 FIX 1C: All new columns are NULL or have DEFAULT values**
- [ ] **v1.7 FIX 1D: Audit tables use ENABLE ROW LEVEL SECURITY (not FORCE)**
- [ ] **v1.7 FIX 1E: Ownership columns verified: listings->owned_by, properties->owner_id, tasks->created_by, activities->declared_by, users->id**

---

## I) Test Scenarios (Non-Negotiable)

> **v1.5 Addition**: These 5 brutal test scenarios MUST pass before shipping.

### Test 1: Delete -> Restore -> Delete -> Restore Cycle

**Setup:**
1. Create a listing (e.g., MLS 12345)
2. Delete it
3. Restore it
4. Delete it again
5. Restore it again

**Expected:**
- All 4 audit entries visible in history: INSERT -> DELETE -> RESTORE -> DELETE -> RESTORE
- Each restore operation succeeds
- Entity is fully functional after final restore
- No duplicate entries or orphaned records

**SQL Verification:**
```sql
SELECT action, changed_at FROM audit.listings_log
WHERE record_pk = '<entity_id>'
ORDER BY changed_at ASC;
-- Should show: INSERT, DELETE, RESTORE, DELETE, RESTORE
```

### Test 2: Restore with FK Missing

**Setup:**
1. Create a listing (L1)
2. Create a task (T1) that references L1 via `listing_id`
3. Delete T1
4. Delete L1
5. Attempt to restore T1

**Expected:**
- Restore fails with `FK_MISSING` error
- Error message: "Cannot restore - the listing this was linked to no longer exists"
- No partial restore state
- T1 remains in Recently Deleted list

**SQL Verification:**
```sql
-- Task restore should fail FK check
SELECT public.restore_entity('task', '<task_id>');
-- ERROR: FK_MISSING: Cannot restore - referenced entity no longer exists
```

### Test 3: Restore with Unique Conflict

**Setup:**
1. Create listing A with MLS number "12345"
2. Delete listing A
3. Create listing B with MLS number "12345" (same MLS)
4. Attempt to restore listing A

**Expected:**
- Restore fails with `UNIQUE_CONFLICT` error
- Error message: "Cannot restore - a record with this MLS number already exists"
- Listing A remains in Recently Deleted
- Listing B unaffected

**SQL Verification:**
```sql
-- Should fail unique constraint on mls_number
SELECT public.restore_entity('listing', '<listing_a_id>');
-- ERROR: UNIQUE_CONFLICT: Cannot restore - unique constraint violation
```

### Test 4: Invalid UUID Garbage in JSONB

**Setup:**
1. Manually insert an audit row with corrupted ownership data:
```sql
INSERT INTO audit.listings_log (audit_id, action, record_pk, old_row, table_schema, table_name)
VALUES (
  gen_random_uuid(),
  'DELETE',
  gen_random_uuid(),
  '{"owned_by": "null", "id": "garbage", "address": "123 Test St"}'::jsonb,
  'public',
  'listings'
);
```
2. Call `get_entity_history()` or `get_recently_deleted()`

**Expected:**
- Query does NOT crash or throw an exception
- Invalid UUID rows are gracefully skipped (regex guard returns NULL)
- Other valid entries are still returned
- No error messages visible to user

**SQL Verification:**
```sql
-- Should return results without crashing
SELECT * FROM public.get_recently_deleted(NULL, 50);
-- Corrupted row may be excluded but query completes successfully
```

### Test 5: get_recently_deleted Global Ordering Under Load

**Setup:**
1. Insert 100 DELETE entries across all 5 tables (20 per table):
```sql
DO $$
DECLARE
  i INT;
  tables TEXT[] := ARRAY['listings', 'properties', 'tasks', 'users', 'activities'];
  t TEXT;
BEGIN
  FOREACH t IN ARRAY tables LOOP
    FOR i IN 1..20 LOOP
      EXECUTE format(
        'INSERT INTO audit.%I_log (audit_id, action, changed_at, changed_by, record_pk, old_row, table_schema, table_name)
         VALUES (gen_random_uuid(), ''DELETE'', now() - (''%s minutes''::interval), auth.uid(), gen_random_uuid(),
                 ''{"owned_by": "'' || auth.uid()::text || ''"}''::jsonb, ''public'', %L)',
        t, i * 3, t
      );
    END LOOP;
  END LOOP;
END $$;
```
2. Call `get_recently_deleted(NULL, 20)`

**Expected:**
- Returns exactly 20 items (not 5x20 = 100)
- Results are globally sorted by `changed_at DESC` (not per-table)
- Items from different tables are interleaved based on timestamp
- Most recent 20 deletes regardless of entity type

**SQL Verification:**
```sql
SELECT table_name, changed_at FROM public.get_recently_deleted(NULL, 20);
-- Should show 20 rows
-- changed_at should be in descending order
-- table_name should be mixed (not grouped by table)
```

### Test 6: Diff View Does Not Show "Optional(...)" (v1.6)

**Setup:**
1. Create a listing with some nullable fields (e.g., notes = nil)
2. Update the listing to add notes
3. Navigate to the history and tap the UPDATE row to view diff

**Expected:**
- Old value for notes shows "none" (not "Optional(nil)" or "nil")
- New value shows the actual note text (not "Optional(\"the note\")")
- No "Optional(...)" wrapper strings appear anywhere in the diff view

**Code Verification:**
```swift
// stringify() helper should handle:
// - nil -> ""
// - String -> String
// - NSNumber -> NSNumber.stringValue
// - Any other type -> String(describing:) as fallback
```

### Test 7: HistorySection with nil onRestore Hides Restore Button (v1.6)

**Setup:**
1. Render HistorySection with `onRestore: nil`
2. Ensure there's a DELETE entry in the history

**Expected:**
- DELETE entries are shown in the history list
- Restore button is NOT displayed (even for DELETE actions)
- Tapping the row does nothing (no crash, no action)

**UI Verification:**
- Check HistoryEntryRow for DELETE entry does NOT contain "Restore" button
- No error when HistorySection mounted with `onRestore: nil`

### Test 8: Schema Migration - Restore After Column Addition (v1.7)

> **FIX 1C Verification**: Ensures old snapshots restore correctly after schema evolution.

**Setup:**
1. Create a listing with all current fields
2. Delete the listing (creates audit snapshot with current schema)
3. Add a new nullable column to listings table:
   ```sql
   ALTER TABLE public.listings ADD COLUMN new_feature_flag BOOLEAN DEFAULT NULL;
   ```
4. Attempt to restore the deleted listing

**Expected:**
- Restore succeeds without errors
- New column gets NULL value (not a constraint violation)
- All original values are preserved correctly
- Entity is fully functional after restore

**SQL Verification:**
```sql
-- After restore, check the new column is NULL
SELECT id, address, new_feature_flag FROM public.listings WHERE id = '<restored_id>';
-- new_feature_flag should be NULL

-- Verify audit RESTORE entry was created
SELECT action, changed_at FROM audit.listings_log
WHERE record_pk = '<restored_id>' AND action = 'RESTORE';
```

**Failure Mode (what we're preventing):**
If `new_feature_flag` was added as `NOT NULL` without a default:
```sql
-- WRONG: This would break restore
ALTER TABLE public.listings ADD COLUMN new_feature_flag BOOLEAN NOT NULL;
-- Restore would fail: "null value in column 'new_feature_flag' violates not-null constraint"
```

### Test 9: Tombstone Delete Sync (v1.7)

> **Risk Zone 3 Verification**: Ensures local deletes sync to Supabase via tombstone queue.

**Setup:**
1. Create a listing and sync it to Supabase
2. Go offline (disable network)
3. Delete the listing locally
4. Verify tombstone was created:
   ```swift
   // Check PendingDeletion exists
   let tombstones = try context.fetch(FetchDescriptor<PendingDeletion>())
   XCTAssertEqual(tombstones.count, 1)
   XCTAssertEqual(tombstones[0].entityType, "listing")
   ```
5. Go back online
6. Wait for sync to complete

**Expected:**
- Tombstone is created immediately on local delete
- Listing is gone from local SwiftData
- On reconnect, DELETE is issued to Supabase
- Audit log shows DELETE entry on server
- Tombstone is removed after successful sync

**Verification Steps:**
```sql
-- After sync, verify server-side delete and audit entry
SELECT * FROM public.listings WHERE id = '<deleted_id>';
-- Should return 0 rows

SELECT action, changed_at FROM audit.listings_log
WHERE record_pk = '<deleted_id>' AND action = 'DELETE';
-- Should return 1 row
```

**Offline Failure Mode:**
```swift
// If tombstone is NOT created, the delete is lost:
// 1. User deletes listing offline
// 2. App closes
// 3. App reopens online
// 4. No record of deletion - server still has the listing!
```

---

## File Structure

```
Dispatch/Features/Audit/
+-- Models/
|   +-- AuditEntry.swift            # v1.7: struct (not @Model)
|   +-- AuditAction.swift
|   +-- AuditableEntity.swift       # includes .activity case + tableName extension
+-- DTOs/
|   +-- AuditEntryDTO.swift         # includes Activity field labels
+-- Sync/
|   +-- AuditSyncHandler.swift
|   +-- RestoreError.swift          # v1.7: updated from() parsing
+-- Views/
|   +-- HistorySection.swift        # v1.7: .task(id:) + onRestore discipline
|   +-- HistoryEntryRow.swift
|   +-- HistoryDetailView.swift
|   +-- DiffRow.swift
|   +-- RecentlyDeletedView.swift   # v1.7: List wrapper for groupedList
|   +-- RecentlyDeletedRow.swift
|   +-- DeletedEntityView.swift
+-- Components/                      # Design System components
|   +-- TimelineRow.swift
|   +-- DiffGrid.swift

Dispatch/Features/Sync/             # v1.7: Tombstone delete sync
+-- Models/
|   +-- PendingDeletion.swift       # @Model for tombstone queue
+-- Helpers/
|   +-- DeleteWithTombstone.swift   # Helper function for atomic delete
+-- Extensions/
|   +-- SyncManager+Deletions.swift # processPendingDeletions()
|   +-- ChangeChip.swift
|   +-- RestoreButton.swift
```

> **Note**: ActivityDetailView (in `Dispatch/Features/Activity/Views/`) will integrate HistorySection
> the same way other entity detail views do.

---

## Agent Ownership

| Agent | Responsibility |
|-------|----------------|
| dispatch-explorer | Map current detail views, sync handlers, soft delete patterns |
| data-integrity | Database migration, triggers, RLS, restore functions |
| feature-owner | Swift models, DTOs, sync handlers, UI components |
| jobs-critic | Design bar review for History section and Recently Deleted |
| ui-polish | Refine History timeline, diff view, restore interactions |
| xcode-pilot | Validate restore flows, edge cases on simulator |
| integrator | Build verification, test runs, final sign-off |
