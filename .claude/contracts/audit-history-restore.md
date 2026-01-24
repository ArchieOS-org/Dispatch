## Interface Lock

**Feature**: Instant Audit History + Restore
**Created**: 2026-01-22
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [x] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [x] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [x] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [x] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators (ALL apply - this is a major feature):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 1.5 | Schema ready (audit tables, triggers, RLS) | data-integrity |
| 2 | Tests pass, Swift models + sync handlers | feature-owner, integrator |
| 2.5 | Design bar (History UI, Recently Deleted) | jobs-critic, ui-polish |
| 3 | Validation (restore flows, edge cases) | xcode-pilot |

---

### Contract

- New/changed model fields:
  - `AuditEntry` model (Swift): id, action, changedAt, changedBy, entityType, entityId, oldRow, newRow, summary
  - `AuditAction` enum: insert, update, delete
  - `AuditableEntity` enum: realtor, listing, property, task
  - Remove `deleted_at` from: listings, properties, tasks (realtors already has no soft delete)

- DTO/API changes:
  - `AuditEntryDTO` for fetching audit logs
  - Restore functions called via RPC: `audit.restore_listing()`, `audit.restore_property()`, `audit.restore_task()`, `audit.restore_realtor()`
  - New sync handlers for audit data (read-only, no push)

- State/actions added:
  - `AppState.Action.showHistory(entityType, entityId)`
  - `AppState.Action.restoreEntity(entityType, entityId)`
  - `AppState.Action.showRecentlyDeleted`

- Migration required: **YES** (major - audit schema, triggers, soft delete removal)

### Acceptance Criteria (3 max)

1. All INSERT/UPDATE/DELETE on realtors, listings, properties, tasks are logged to audit schema with full row snapshots
2. Users can view history timeline on any entity detail screen and restore deleted items with one tap
3. "Recently Deleted" global view shows all deleted entities across types with restore capability

### Non-goals (prevents scope creep)

- No audit logging for Activities (explicitly excluded per requirements)
- No audit logging for Notes, Subtasks, or other child entities
- No "revert to version X" (only restore from delete is MVP)
- No bulk restore operations
- No audit log export or search
- No retention policy or automatic cleanup (future work)

### Compatibility Plan

- **Backward compatibility**: Soft delete columns remain during transition; old clients continue to work. Migration is additive (new audit schema). Triggers are transparent to app.
- **Default when missing**: If audit log entry has null changed_by, display as "System"
- **Rollback strategy**: Drop audit triggers (data remains), re-add deleted_at columns if needed. Audit tables can be retained for forensics.

---

## A) Architecture Overview

### System Design Philosophy

**"Nothing is ever truly lost. Mistakes are reversible. History is transparent. Everything stays fast."**

```
                                    WRITE PATH
                                        |
                                        v
+------------------+    TRIGGER    +------------------+
|   public.X       | ------------> |   audit.X_log    |
|   (entity table) |   BEFORE      |   (audit table)  |
|                  |   I/U/D       |                  |
+------------------+               +------------------+
        |                                   |
        | Hard Delete                       | Preserved Forever
        v                                   v
    [Row Gone]                      [Full Snapshot]

                                    READ PATH
                                        |
                                        v
+------------------+    SELECT     +------------------+
|   Swift App      | <------------ |   audit.X_log    |
|   (AuditEntry)   |   via RLS     |   (filtered)     |
+------------------+               +------------------+
        |
        v
+------------------+
|   History UI     |
|   per entity     |
+------------------+

                                   RESTORE PATH
                                        |
                                        v
+------------------+    RPC        +------------------+
|   Swift App      | ------------> | audit.restore_X()|
|   (Restore CTA)  |               | SECURITY DEFINER |
+------------------+               +------------------+
        |                                   |
        v                                   v
+------------------+               +------------------+
|   New entity     | <------------ |   old_row JSONB  |
|   in public.X    |   INSERT      |   from DELETE    |
+------------------+               +------------------+
```

### Key Architectural Decisions

1. **Hard Delete + Audit Trail** (not soft delete)
   - Rows are truly deleted from main tables
   - Full row snapshots preserved in audit tables
   - Cleaner queries, no WHERE deleted_at IS NULL everywhere
   - Audit table is source of truth for history

2. **BEFORE Trigger with SECURITY DEFINER**
   - Captures OLD and NEW before mutation
   - Runs as table owner, bypasses RLS for logging
   - Cannot be bypassed by any client

3. **Per-Table Audit Tables** (not single shared table)
   - `audit.realtors_log`, `audit.listings_log`, `audit.properties_log`, `audit.tasks_log`
   - Allows table-specific indexes
   - Easier to query and partition
   - Type-safe JSONB (old_row/new_row match table schema)

4. **Read-Only from App**
   - App fetches audit logs via SELECT with RLS
   - App calls restore functions via RPC
   - App NEVER writes to audit tables directly

---

## B) Database Migration Plan

### Phase 1: Create Audit Schema and Tables

```sql
-- Create audit schema (separate from public)
CREATE SCHEMA IF NOT EXISTS audit;

-- Generic audit log structure (repeated per entity)
-- Example: audit.listings_log

CREATE TABLE audit.listings_log (
  audit_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action        TEXT NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
  changed_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  changed_by    UUID REFERENCES public.users(id),
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

-- Repeat for: audit.properties_log, audit.tasks_log, audit.realtors_log
```

### Phase 2: Create Generic Trigger Function

```sql
-- Generic audit trigger function
-- Works for any table, stores row as JSONB

CREATE OR REPLACE FUNCTION audit.log_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER  -- Runs as function owner, bypasses RLS
SET search_path = audit, public
AS $$
DECLARE
  audit_table TEXT;
  changed_by_id UUID;
BEGIN
  -- Determine audit table name
  audit_table := TG_TABLE_NAME || '_log';

  -- Get current user ID from auth context (Supabase)
  changed_by_id := auth.uid();

  -- Log based on operation type
  IF TG_OP = 'INSERT' THEN
    EXECUTE format(
      'INSERT INTO audit.%I (action, changed_by, record_pk, old_row, new_row, table_schema, table_name)
       VALUES ($1, $2, $3, $4, $5, $6, $7)',
      audit_table
    ) USING 'INSERT', changed_by_id, NEW.id, NULL, to_jsonb(NEW), TG_TABLE_SCHEMA, TG_TABLE_NAME;
    RETURN NEW;

  ELSIF TG_OP = 'UPDATE' THEN
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

### Phase 3: Attach Triggers to Tables

```sql
-- Listings trigger
CREATE TRIGGER audit_listings_changes
  BEFORE INSERT OR UPDATE OR DELETE ON public.listings
  FOR EACH ROW EXECUTE FUNCTION audit.log_changes();

-- Properties trigger
CREATE TRIGGER audit_properties_changes
  BEFORE INSERT OR UPDATE OR DELETE ON public.properties
  FOR EACH ROW EXECUTE FUNCTION audit.log_changes();

-- Tasks trigger
CREATE TRIGGER audit_tasks_changes
  BEFORE INSERT OR UPDATE OR DELETE ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION audit.log_changes();

-- Realtors trigger (users table, filtered by user_type)
-- Note: We audit all users but UI only shows realtors
CREATE TRIGGER audit_users_changes
  BEFORE INSERT OR UPDATE OR DELETE ON public.users
  FOR EACH ROW EXECUTE FUNCTION audit.log_changes();
```

### Phase 4: Create Restore Functions

```sql
-- Restore a deleted listing
CREATE OR REPLACE FUNCTION audit.restore_listing(p_record_pk UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = audit, public
AS $$
DECLARE
  v_old_row JSONB;
  v_new_id UUID;
BEGIN
  -- Find the most recent DELETE record
  SELECT old_row INTO v_old_row
  FROM audit.listings_log
  WHERE record_pk = p_record_pk
    AND action = 'DELETE'
  ORDER BY changed_at DESC
  LIMIT 1;

  IF v_old_row IS NULL THEN
    RAISE EXCEPTION 'No deleted record found for listing %', p_record_pk;
  END IF;

  -- Restore with same ID (may fail on unique constraint)
  INSERT INTO public.listings
  SELECT * FROM jsonb_populate_record(NULL::public.listings, v_old_row)
  ON CONFLICT (id) DO NOTHING
  RETURNING id INTO v_new_id;

  IF v_new_id IS NULL THEN
    RAISE EXCEPTION 'Failed to restore listing % - record may already exist', p_record_pk;
  END IF;

  RETURN v_new_id;
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION audit.restore_listing(UUID) TO authenticated;

-- Repeat for: audit.restore_property(), audit.restore_task(), audit.restore_realtor()
```

### Phase 5: Remove Soft Delete Columns (Staged)

**Stage 5a: Stop using deleted_at in app** (PATCHSET 2)
- Update sync handlers to hard delete
- Update queries to not filter on deleted_at
- App now does hard delete, triggers capture it

**Stage 5b: Migration to drop columns** (Future - after rollout verified)
```sql
-- Only after confirming audit system works
ALTER TABLE public.listings DROP COLUMN IF EXISTS deleted_at;
ALTER TABLE public.properties DROP COLUMN IF EXISTS deleted_at;
ALTER TABLE public.tasks DROP COLUMN IF EXISTS deleted_at;
```

---

## C) RLS/Security Plan

### Audit Table RLS Policies

```sql
-- Enable RLS on audit tables
ALTER TABLE audit.listings_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit.properties_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit.tasks_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit.realtors_log ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view audit logs for entities they can see
-- (Mirrors the RLS policy on the main table)

CREATE POLICY "Users can view listing audit logs"
ON audit.listings_log FOR SELECT
TO authenticated
USING (
  -- Can view if listing is visible OR if it was their listing
  record_pk IN (
    SELECT id FROM public.listings WHERE TRUE  -- Current RLS passes
  )
  OR changed_by = auth.uid()  -- User made the change
);

-- Similar policies for properties, tasks, realtors
```

### Restore Function Security

- Functions are `SECURITY DEFINER` (run as owner)
- But wrapped with authorization check:

```sql
CREATE OR REPLACE FUNCTION audit.restore_listing(p_record_pk UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = audit, public
AS $$
DECLARE
  v_old_row JSONB;
  v_original_owner UUID;
BEGIN
  -- Authorization: Only allow restore if user could have seen the original
  SELECT (old_row->>'owned_by')::UUID INTO v_original_owner
  FROM audit.listings_log
  WHERE record_pk = p_record_pk AND action = 'DELETE'
  ORDER BY changed_at DESC LIMIT 1;

  IF v_original_owner IS NULL THEN
    RAISE EXCEPTION 'No deleted record found';
  END IF;

  -- For now: only owner can restore
  -- Future: expand to admins
  IF v_original_owner != auth.uid() THEN
    RAISE EXCEPTION 'Not authorized to restore this listing';
  END IF;

  -- ... rest of restore logic
END;
$$;
```

---

## D) App Integration Plan

### Swift Models

```swift
// AuditEntry.swift
@Model
final class AuditEntry {
  @Attribute(.unique) var id: UUID
  var action: AuditAction
  var changedAt: Date
  var changedBy: UUID?
  var entityType: AuditableEntity
  var entityId: UUID
  var summary: String  // Human-readable summary, computed from diff

  // Transient - not persisted, computed from JSONB
  var oldRowJSON: String?
  var newRowJSON: String?
}

enum AuditAction: String, Codable {
  case insert = "INSERT"
  case update = "UPDATE"
  case delete = "DELETE"
}

enum AuditableEntity: String, Codable {
  case realtor
  case listing
  case property
  case task
}
```

### DTO Layer

```swift
// AuditEntryDTO.swift
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

  func toModel() -> AuditEntry {
    // Compute summary from diff
    let summary = computeSummary()
    return AuditEntry(
      id: auditId,
      action: AuditAction(rawValue: action) ?? .update,
      changedAt: changedAt,
      changedBy: changedBy,
      entityType: entityTypeFromTable(),
      entityId: recordPk,
      summary: summary
    )
  }

  private func computeSummary() -> String {
    switch action {
    case "INSERT": return "Created"
    case "DELETE": return "Deleted"
    case "UPDATE": return computeFieldChanges()
    default: return "Modified"
    }
  }

  private func computeFieldChanges() -> String {
    // Compare oldRow vs newRow, return "Changed: stage, price"
  }
}
```

### Sync Handler

```swift
// AuditSyncHandler.swift
@MainActor
final class AuditSyncHandler {

  /// Fetch audit history for a specific entity
  func fetchHistory(for entityType: AuditableEntity, entityId: UUID) async throws -> [AuditEntry] {
    let tableName = "\(entityType.rawValue)s_log"  // e.g., "listings_log"

    let dtos: [AuditEntryDTO] = try await supabase
      .from("audit.\(tableName)")
      .select()
      .eq("record_pk", value: entityId.uuidString)
      .order("changed_at", ascending: false)
      .limit(50)
      .execute()
      .value

    return dtos.map { $0.toModel() }
  }

  /// Fetch recently deleted items (all types)
  func fetchRecentlyDeleted() async throws -> [AuditEntry] {
    // Query each audit table for DELETE actions, union results
    var allDeleted: [AuditEntry] = []

    for entityType in AuditableEntity.allCases {
      let tableName = "\(entityType.rawValue)s_log"
      let dtos: [AuditEntryDTO] = try await supabase
        .from("audit.\(tableName)")
        .select()
        .eq("action", value: "DELETE")
        .order("changed_at", ascending: false)
        .limit(20)
        .execute()
        .value

      allDeleted.append(contentsOf: dtos.map { $0.toModel() })
    }

    return allDeleted.sorted { $0.changedAt > $1.changedAt }
  }

  /// Restore a deleted entity via RPC
  func restoreEntity(_ entityType: AuditableEntity, entityId: UUID) async throws {
    let functionName = "restore_\(entityType.rawValue)"

    try await supabase.rpc(functionName, params: ["p_record_pk": entityId.uuidString])
      .execute()
  }
}
```

### Delete Flow Change

```swift
// Before (soft delete):
func deleteListing() {
  listing.status = .deleted
  listing.deletedAt = Date()
  listing.markPending()
  syncManager.requestSync()
}

// After (hard delete):
func deleteListing() {
  // SwiftData delete - will sync as DELETE to Supabase
  // Trigger captures full row to audit table
  modelContext.delete(listing)
  syncManager.requestSync()
}
```

---

## E) UI Plan

### E1: History Section on Entity Detail Views

**Location**: Added to `ListingDetailView`, `PropertyDetailView`, `WorkItemDetailView` (tasks), `RealtorProfileView`

**Position**: After existing sections, before bottom padding

**Visual Design**:
```
+------------------------------------------+
|  History                            (5)  |  <- Section header with count
+------------------------------------------+
|  [clock.arrow.circlepath]                |
|  Created                                 |  <- Action
|  Jan 15, 2026 at 2:30 PM                |  <- Timestamp
|  by Alice Smith                          |  <- Actor (with avatar)
|  [chevron.right]                         |  <- Disclosure
+------------------------------------------+
|  [pencil.circle]                         |
|  Updated                                 |
|  Changed: stage (pending -> live),       |
|           price ($500,000 -> $525,000)   |  <- Summary
|  Jan 18, 2026 at 10:15 AM               |
|  by Bob Jones                            |
|  [chevron.right]                         |
+------------------------------------------+
|  [trash.circle]                          |
|  Deleted                                 |
|  Jan 20, 2026 at 4:45 PM                |
|  by Carol White                          |
|  [Restore]                               |  <- CTA button
+------------------------------------------+
```

**States**:
- **Loading**: Spinner centered, "Loading history..."
- **Empty**: "No history available" with clock icon
- **Error**: "Failed to load history" with retry button
- **Data**: Timeline list as shown above

**Components**:
```swift
// HistorySection.swift
struct HistorySection: View {
  let entityType: AuditableEntity
  let entityId: UUID

  @State private var entries: [AuditEntry] = []
  @State private var isLoading = true
  @State private var error: Error?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      sectionHeader("History", count: entries.count)
      Divider()

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
    .task { await loadHistory() }
  }
}

// HistoryEntryRow.swift
struct HistoryEntryRow: View {
  let entry: AuditEntry
  let userLookup: (UUID) -> User?
  let onRestore: (() -> Void)?

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
      HStack {
        Image(systemName: entry.action.icon)
          .foregroundColor(entry.action.color)
        Text(entry.action.displayName)
          .font(DS.Typography.body)
        Spacer()
        if entry.action == .delete, let onRestore {
          Button("Restore", action: onRestore)
            .buttonStyle(.bordered)
        }
      }

      Text(entry.summary)
        .font(DS.Typography.caption)
        .foregroundColor(DS.Colors.Text.secondary)

      HStack {
        Text(entry.changedAt.formatted())
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.Text.tertiary)

        if let userId = entry.changedBy, let user = userLookup(userId) {
          Text("by \(user.name)")
            .font(DS.Typography.caption)
            .foregroundColor(DS.Colors.Text.tertiary)
        }
      }
    }
    .padding(.vertical, DS.Spacing.sm)
  }
}
```

### E2: History Detail View (Diff View)

**Triggered by**: Tapping a history entry row

**Visual Design**:
```
+------------------------------------------+
|  < Back          Updated         [Share] |
+------------------------------------------+
|  Jan 18, 2026 at 10:15 AM               |
|  by Bob Jones                            |
+------------------------------------------+
|                                          |
|  Changes                                 |
+------------------------------------------+
|  stage                                   |
|  - pending                          OLD  |
|  + live                             NEW  |
+------------------------------------------+
|  price                                   |
|  - $500,000                         OLD  |
|  + $525,000                         NEW  |
+------------------------------------------+
```

**Components**:
```swift
// HistoryDetailView.swift
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

  private var changesSection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      sectionHeader("Changes")
      Divider()

      ForEach(computeDiffs(), id: \.field) { diff in
        DiffRow(diff: diff)
      }
    }
  }
}

// DiffRow.swift
struct DiffRow: View {
  let diff: FieldDiff

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
      Text(diff.field)
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

### E3: Recently Deleted Global View

**Access Point**: Settings or dedicated nav item (TBD based on IA)

**Visual Design**:
```
+------------------------------------------+
|  Recently Deleted                        |
+------------------------------------------+
|  [filter: All | Listings | Properties |  |
|           Tasks | Realtors]              |
+------------------------------------------+
|                                          |
|  Today                                   |
+------------------------------------------+
|  [house.fill]  123 Main Street           |
|                Listing - Deleted 2h ago  |
|                by Carol White            |
|                              [Restore]   |
+------------------------------------------+
|  [checkmark.square]  Update lockbox      |
|                Task - Deleted 4h ago     |
|                by Alice Smith            |
|                              [Restore]   |
+------------------------------------------+
|                                          |
|  Yesterday                               |
+------------------------------------------+
|  ...                                     |
+------------------------------------------+
```

**States**:
- **Loading**: Full-screen spinner
- **Empty**: "No deleted items" with trash icon, "Items you delete will appear here for 30 days"
- **Error**: "Failed to load" with retry
- **Data**: Grouped by date, filterable by entity type

**Components**:
```swift
// RecentlyDeletedView.swift
struct RecentlyDeletedView: View {
  @State private var entries: [AuditEntry] = []
  @State private var filter: AuditableEntity? = nil
  @State private var isLoading = true

  var body: some View {
    StandardScreen(title: "Recently Deleted", layout: .list) {
      filterPicker

      if isLoading {
        loadingState
      } else if filteredEntries.isEmpty {
        emptyState
      } else {
        groupedList
      }
    }
    .task { await loadDeletedItems() }
  }

  private var filteredEntries: [AuditEntry] {
    guard let filter else { return entries }
    return entries.filter { $0.entityType == filter }
  }

  private var groupedList: some View {
    // Group by date, display with section headers
  }
}

// RecentlyDeletedRow.swift
struct RecentlyDeletedRow: View {
  let entry: AuditEntry
  let onRestore: () -> Void

  var body: some View {
    HStack {
      Image(systemName: entry.entityType.icon)
        .foregroundColor(entry.entityType.color)

      VStack(alignment: .leading) {
        Text(entry.displayName)
          .font(DS.Typography.body)
        Text("\(entry.entityType.displayName) - Deleted \(entry.changedAt.relative)")
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.Text.secondary)
      }

      Spacer()

      Button("Restore", action: onRestore)
        .buttonStyle(.bordered)
    }
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
| Restore button | "Restore" |
| Restore success toast | "[Entity] restored successfully" |
| Restore conflict error | "Cannot restore - [field] already exists" |
| Restore FK error | "Cannot restore - [related entity] no longer exists" |
| Recently Deleted title | "Recently Deleted" |
| Empty recently deleted | "No deleted items", "Items you delete will appear here" |
| Filter: All | "All" |

---

## F) Edge Cases + Failure Modes

### F1: Deep Link to Deleted Record

**Scenario**: User follows link to `/listing/abc-123` but listing was deleted.

**Handling**:
1. Primary fetch returns 404/empty
2. Check audit table for DELETE record
3. Show "This listing was deleted" banner with:
   - When deleted
   - Who deleted it
   - [Restore] button (if authorized)
   - [Go Back] button

```swift
// DeletedEntityView.swift
struct DeletedEntityView: View {
  let entityType: AuditableEntity
  let entityId: UUID
  let deleteEntry: AuditEntry

  var body: some View {
    VStack(spacing: DS.Spacing.xl) {
      Image(systemName: "trash.circle")
        .font(.system(size: 64))
        .foregroundColor(DS.Colors.Text.tertiary)

      Text("This \(entityType.displayName.lowercased()) was deleted")
        .font(DS.Typography.title)

      Text("Deleted \(deleteEntry.changedAt.relative)")
        .font(DS.Typography.body)
        .foregroundColor(DS.Colors.Text.secondary)

      Button("Restore") { restoreEntity() }
        .buttonStyle(.borderedProminent)

      Button("Go Back") { dismiss() }
        .buttonStyle(.bordered)
    }
  }
}
```

### F2: Unique Constraint Conflict on Restore

**Scenario**: Restore listing with address "123 Main St" but another listing with same address now exists.

**Handling**:
1. Restore function catches unique violation
2. Returns specific error: `UNIQUE_CONFLICT:address`
3. App shows: "Cannot restore - a listing at this address already exists"
4. Options: [Cancel] [View Existing]

```sql
-- In restore function
EXCEPTION WHEN unique_violation THEN
  RAISE EXCEPTION 'UNIQUE_CONFLICT:%', SQLERRM;
```

### F3: Missing Foreign Key on Restore

**Scenario**: Restore task that referenced listing_id that no longer exists.

**Handling**:
1. Restore function detects missing FK
2. Two strategies:
   - **Strict**: Fail with "Cannot restore - referenced listing no longer exists"
   - **Lenient**: Restore with NULL FK, warn user

**Current choice**: Strict (fail fast)

```sql
-- Check FK before restore
IF (v_old_row->>'listing')::UUID IS NOT NULL THEN
  IF NOT EXISTS (SELECT 1 FROM public.listings WHERE id = (v_old_row->>'listing')::UUID) THEN
    RAISE EXCEPTION 'FK_MISSING:listing';
  END IF;
END IF;
```

### F4: Multiple Delete/Restore Cycles

**Scenario**: Entity deleted, restored, deleted again.

**Handling**:
- Each delete creates new audit entry
- Restore always uses most recent DELETE
- History shows full lifecycle: Created -> Deleted -> Restored -> Deleted
- All snapshots preserved

### F5: System vs User Changes

**Scenario**: Some changes made by scheduled jobs, not users.

**Handling**:
- `changed_by` is NULL for system/anonymous changes
- UI shows "System" or "Automated" instead of user name
- Filter option in Recently Deleted: "Hide system changes"

### F6: Offline Behavior

**Scenario**: User deletes entity while offline, then views history.

**Handling**:
- Delete is queued locally (existing sync mechanism)
- History section shows: "Pending deletion - will sync when online"
- Once synced, audit entry appears in history
- Recently Deleted only shows server-confirmed deletes

### F7: Large History (Performance)

**Scenario**: Entity with 500+ history entries.

**Handling**:
- Initial fetch limited to 50 entries
- "Load more" pagination
- Index on `changed_at DESC` for fast recent queries
- Consider: auto-archive entries older than 1 year (future)

---

## G) Rollout Plan

### Phase 1: Database Only (PATCHSET 1.5)
- Deploy audit schema and tables
- Deploy triggers (start collecting data)
- No app changes yet
- Verify triggers working via Supabase dashboard
- **Rollback**: DROP TRIGGERs (tables can remain)

### Phase 2: App Read-Only (PATCHSET 2)
- Add History sections to entity details
- Fetch-only, no restore yet
- Existing soft delete continues
- **Rollback**: Remove History sections

### Phase 3: Restore + Hard Delete (PATCHSET 2.5)
- Enable Restore buttons
- Switch to hard delete in sync handlers
- Add Recently Deleted view
- Keep deleted_at columns (compatibility)
- **Rollback**: Disable Restore, revert to soft delete

### Phase 4: Cleanup (Future)
- Monitor for 2 weeks
- Remove deleted_at columns
- Implement retention policy

### Feature Flags (Optional)

```swift
enum FeatureFlag {
  case auditHistoryEnabled  // Show History sections
  case restoreEnabled       // Show Restore buttons
  case hardDeleteEnabled    // Use hard delete vs soft delete
}
```

---

## H) Done Checklist

### Database (PATCHSET 1.5)
- [ ] audit schema created
- [ ] audit.listings_log table created with indexes
- [ ] audit.properties_log table created with indexes
- [ ] audit.tasks_log table created with indexes
- [ ] audit.realtors_log (users) table created with indexes
- [ ] audit.log_changes() trigger function deployed
- [ ] Triggers attached to all 4 tables
- [ ] audit.restore_listing() function deployed
- [ ] audit.restore_property() function deployed
- [ ] audit.restore_task() function deployed
- [ ] audit.restore_realtor() function deployed
- [ ] RLS policies on audit tables
- [ ] Manual test: INSERT/UPDATE/DELETE creates audit entries

### App Models (PATCHSET 2)
- [ ] AuditEntry model created
- [ ] AuditEntryDTO created
- [ ] AuditSyncHandler created
- [ ] fetchHistory() works
- [ ] fetchRecentlyDeleted() works
- [ ] Unit tests for DTOs

### UI - History (PATCHSET 2)
- [ ] HistorySection component created
- [ ] HistoryEntryRow component created
- [ ] HistoryDetailView (diff) created
- [ ] Added to ListingDetailView
- [ ] Added to PropertyDetailView
- [ ] Added to WorkItemDetailView (tasks)
- [ ] Added to RealtorProfileView
- [ ] Loading/empty/error states
- [ ] Accessibility labels

### UI - Recently Deleted (PATCHSET 2.5)
- [ ] RecentlyDeletedView created
- [ ] RecentlyDeletedRow created
- [ ] Filter picker (by entity type)
- [ ] Date grouping
- [ ] Navigation wired up
- [ ] Loading/empty/error states

### Restore Flow (PATCHSET 2.5)
- [ ] restoreEntity() RPC call works
- [ ] Restore button in history section
- [ ] Restore button in Recently Deleted
- [ ] Success toast
- [ ] Error handling (conflict, missing FK)
- [ ] Refresh after restore

### Hard Delete Migration (PATCHSET 2.5)
- [ ] Sync handlers use hard delete
- [ ] SwiftData deletion syncs correctly
- [ ] Triggers capture delete
- [ ] No regressions in existing delete flows

### Validation (PATCHSET 3)
- [ ] xcode-pilot: Delete -> Restore cycle
- [ ] xcode-pilot: Deep link to deleted entity
- [ ] xcode-pilot: Multiple delete/restore cycles
- [ ] xcode-pilot: History loads on all entity types
- [ ] Performance: History loads in <500ms
- [ ] Offline: Pending delete shown correctly

---

### Ownership

- **dispatch-explorer**: Map current entity detail views, sync handlers, soft delete patterns
- **data-integrity**: Database migration, triggers, RLS, restore functions
- **feature-owner**: Swift models, DTOs, sync handlers, UI components
- **jobs-critic**: Design bar review for History section and Recently Deleted
- **ui-polish**: Refine History timeline, diff view, restore interactions
- **xcode-pilot**: Validate restore flows, edge cases on simulator
- **integrator**: Build verification, test runs, final sign-off

---

### Context7 Queries

Log all Context7 lookups here:

CONTEXT7_QUERY: Supabase PostgreSQL triggers audit logging INSERT UPDATE DELETE SECURITY DEFINER functions
CONTEXT7_TAKEAWAYS:
- Use BEFORE trigger to capture OLD and NEW values
- SECURITY DEFINER allows trigger to bypass RLS for audit writes
- audit.enable_tracking() pattern for attaching triggers
- Store full row as JSONB for flexibility
CONTEXT7_APPLIED:
- SECURITY DEFINER trigger pattern -> audit.log_changes() function design

CONTEXT7_QUERY: Supabase RLS row level security policies for audit tables SECURITY DEFINER bypass RLS
CONTEXT7_TAKEAWAYS:
- Security definer functions run with creator privileges
- Put helper functions in private schema to prevent API access
- RLS on audit tables should mirror main table access
- Use subqueries to check main table visibility
CONTEXT7_APPLIED:
- RLS policy design -> audit table policies mirror main table access

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: [Pending - to be filled by feature-owner]
**Libraries Queried**: [Pending]

| Query | Pattern Used |
|-------|--------------|
| [Pending] | [Pending] |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: PENDING
**Reviewed**: [Pending]

#### Checklist

- [ ] Ruthless simplicity - nothing can be removed without losing meaning
- [ ] One clear primary action per screen/state
- [ ] Strong hierarchy - headline -> primary -> secondary
- [ ] No clutter - whitespace is a feature
- [ ] Native feel - follows platform conventions

#### Verdict Notes

[Pending jobs-critic review after PATCHSET 2.5]

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
