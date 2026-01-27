## Interface Lock

**Feature**: Audit History + Restore
**Created**: 2026-01-23
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

Based on checked indicators (all four apply - maximum complexity):

| Patchset | Gate | Agents | Notes |
|----------|------|--------|-------|
| 0 | Exploration | dispatch-explorer | Understand existing entity views, sync patterns |
| 1 | Schema ready (LOCAL ONLY) | data-integrity | Create audit schema, tables, triggers, RPC on local Docker Supabase |
| 1.5 | Schema verified + Swift models | data-integrity, feature-owner | Verify migrations, create AuditEntry, DTOs, handlers |
| 2 | UI components + handlers complete | feature-owner | HistorySection, HistoryDetailView, RecentlyDeletedView |
| 2.5 | Design bar | jobs-critic, ui-polish | Jobs Critique for customer-facing UI |
| 3 | Validation | xcode-pilot | Navigation flows, restore interactions |
| 3.5 | Full verification | integrator | Builds iOS+macOS, tests pass, lint clean |
| FINAL | Production migration | data-integrity | ONLY after all verification passes |

---

### Contract

**Implementation Plan**: `.context/audit-history-restore-plan.md` (v1.7)

#### Database Changes (data-integrity owns - LOCAL DOCKER ONLY until FINAL)

- **New schema**: `audit` (private, not exposed via PostgREST)
- **New tables**:
  - `audit.listings_log`
  - `audit.properties_log`
  - `audit.tasks_log`
  - `audit.users_log`
  - `audit.activities_log`
- **New function**: `audit.get_table_names()` - entity type to table name mapping
- **New trigger function**: `audit.log_changes()` - BEFORE trigger with RESTORE action support
- **New triggers** (per table, split design):
  - `audit_X_insert_delete` - INSERT/DELETE (no guard)
  - `audit_X_update` - UPDATE with `WHEN (OLD.* IS DISTINCT FROM NEW.*)` guard
- **New indexes**:
  - Standard: `record_pk`, `changed_at DESC`, `changed_by`, `action`
  - Partial: `changed_at DESC WHERE action = 'DELETE'` (delete hot path)
  - Composite: `(record_pk, changed_at DESC)` (entity history hot path)
- **New RPC functions**:
  - `public.get_entity_history(p_entity_type, p_entity_id, p_limit)` - fetch history for entity
  - `public.get_recently_deleted(p_limit)` - fetch recently deleted across all tables
  - `public.restore_entity(p_entity_type, p_entity_id)` - restore deleted entity
- **RLS policies**: Authorize from `old_row`/`new_row` JSONB ownership fields

#### Swift Changes (feature-owner owns)

- **New model fields**: None (new models only)
- **DTO/API changes**:
  - `AuditEntryDTO` - decodes RPC responses
  - `RestoreEntityParams` - encodes restore RPC parameters
  - `EntityHistoryParams` - encodes history RPC parameters
- **State/actions added**: None (view-local state only)
- **Migration required**: NO (SwiftData schema unchanged)

#### New Swift Types

| Type | Location | Purpose |
|------|----------|---------|
| `AuditEntry` | `Dispatch/Foundation/Audit/AuditEntry.swift` | Plain struct (NOT @Model per Fix 2D) |
| `AuditAction` | `Dispatch/Foundation/Audit/AuditAction.swift` | Enum: insert, update, delete, restore |
| `AuditableEntity` | `Dispatch/Foundation/Audit/AuditableEntity.swift` | Enum with color extension |
| `AuditEntryDTO` | `Dispatch/Foundation/Audit/AuditEntryDTO.swift` | Decodable DTO for RPC responses |
| `AuditSummaryBuilder` | `Dispatch/Foundation/Audit/AuditSummaryBuilder.swift` | Human-readable summary generation |
| `AuditSyncHandler` | `Dispatch/Foundation/Persistence/Sync/Handlers/AuditSyncHandler.swift` | RPC calls for audit operations |
| `RestoreError` | `Dispatch/Foundation/Audit/RestoreError.swift` | Error type for restore failures |
| `PendingDeletion` | `Dispatch/Foundation/Persistence/PendingDeletion.swift` | SwiftData model for tombstone delete sync |

#### New UI Components

| Component | Location | Purpose |
|-----------|----------|---------|
| `HistorySection` | `Dispatch/Features/History/HistorySection.swift` | Collapsible history in entity detail views |
| `HistoryDetailView` | `Dispatch/Features/History/HistoryDetailView.swift` | Diff view for UPDATE entries |
| `HistoryEntryRow` | `Dispatch/Features/History/HistoryEntryRow.swift` | Individual history entry with navigation |
| `RecentlyDeletedView` | `Dispatch/Features/History/RecentlyDeletedView.swift` | Shows deleted items with restore |
| `RecentlyDeletedRow` | `Dispatch/Features/History/RecentlyDeletedRow.swift` | Individual deleted item row |
| `RestoredNavTarget` | `Dispatch/Features/History/RestoredNavTarget.swift` | Navigation target after restore |

---

### Acceptance Criteria (3 max)

1. **History visible**: Entity detail views show collapsible history section with last 5 entries (expandable to all); UPDATE entries navigate to diff view
2. **Restore works**: RecentlyDeletedView shows deleted items from last 30 days; restore button re-creates entity and navigates to it
3. **Audit trail complete**: All INSERT/UPDATE/DELETE/RESTORE actions logged with actor, timestamp, old/new snapshots; no audit spam from no-op sync updates

---

### Non-goals (prevents scope creep)

- No audit history for notes (notes not in scope)
- No bulk restore (single entity at a time)
- No audit log export/download
- No admin view of all users' audit history (user sees only their authorized entities)
- No retention policy or auto-cleanup of old audit entries
- No real-time audit updates via Supabase Realtime (fetch on demand only)

---

### Compatibility Plan

- **Backward compatibility**: N/A (new feature, no existing audit data)
- **Default when missing**: History section shows "No history available" for entities created before audit triggers
- **Rollback strategy**:
  1. Remove UI components (no navigation to history)
  2. Drop triggers (stops new logging)
  3. Drop RPC functions
  4. Keep audit tables (preserves historical data for potential re-enable)

---

### Ownership

- **dispatch-explorer**: Investigate existing entity detail views, sync handler patterns, SwiftData models
- **data-integrity**: All database work (schema, tables, triggers, RPC, RLS, indexes) - LOCAL DOCKER ONLY until FINAL patchset
- **feature-owner**: Swift models, DTOs, handlers, UI components, integration into existing views
- **jobs-critic**: Design review for RecentlyDeletedView, HistorySection, HistoryDetailView
- **ui-polish**: Refinement after SHIP YES
- **xcode-pilot**: Navigation flow validation (restore -> navigate to entity)
- **integrator**: Build verification, test suite, lint, FINAL approval

---

### Critical Constraints

#### LOCAL DEVELOPMENT ONLY (ENFORCED)

**CRITICAL**: All database development happens on LOCAL Docker Supabase only.

```bash
# Start local Supabase
supabase start

# Pull production schema (to initialize local with current prod schema)
supabase db pull

# Apply audit migrations to LOCAL only
# ... develop and test ...

# ONLY at FINAL patchset (after all verification):
supabase db push  # Production migration
```

Production migration (`supabase db push`) is BLOCKED until:
- [ ] All UI components complete
- [ ] All tests pass
- [ ] Lint clean
- [ ] Jobs Critique: SHIP YES
- [ ] integrator reports DONE

#### Database Design Constraints (from Plan v1.7)

| Constraint | Requirement |
|------------|-------------|
| **Fix 1B** | All audited tables MUST have `id UUID` as primary key |
| **Fix 1C** | New columns MUST be NULL or have DEFAULT values (for restore compatibility) |
| **Fix 1D** | Do NOT use `FORCE ROW LEVEL SECURITY` on audit tables (breaks trigger bypass) |
| **Fix 1E** | Verify ownership columns: listings->owned_by, properties->owned_by, tasks->declared_by, activities->declared_by, users->id (CORRECTED: properties uses owned_by not owner_id, tasks uses declared_by not created_by) |

#### Swift Design Constraints (from Plan v1.7)

| Constraint | Requirement |
|------------|-------------|
| **Fix 2A** | Wrap `groupedList` in `List` in RecentlyDeletedView |
| **Fix 2B** | Use `onRestore: nil` in normal detail views, non-nil only in deleted entity contexts |
| **Fix 2C** | Use `.task(id: entityId)` in HistorySection to prevent re-fire on unrelated state changes |
| **Fix 2D** | `AuditEntry` is plain struct, NOT @Model (prevents SwiftData accumulation) |

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: DisclosureGroup task modifier id NavigationStack programmatic navigation
CONTEXT7_TAKEAWAYS:
- Use .navigationDestination(item:) with Binding<Identifiable?> for programmatic navigation
- NavigationStack path-based navigation uses .navigationDestination(for:) with value types
- Task modifier with id: parameter (.task(id:)) re-fires only when the id changes
CONTEXT7_APPLIED:
- .task(id: entityId) -> HistorySection.swift:38
- .navigationDestination(item:) -> RecentlyDeletedView.swift:24

CONTEXT7_QUERY: RPC function call with parameters Encodable struct
CONTEXT7_TAKEAWAYS:
- Use dictionary [String: String] or [String: Any] for simple params
- Struct params require Encodable conformance
- Params with custom keys use CodingKeys enum
CONTEXT7_APPLIED:
- Dictionary params instead of struct -> AuditSyncHandler.swift (all RPC calls)

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (/websites/developer_apple_swiftui), Supabase Swift (/supabase/supabase-swift)

| Query | Pattern Used |
|-------|--------------|
| SwiftUI DisclosureGroup, task(id:), NavigationStack | .task(id: entityId), .navigationDestination(item:) |
| Supabase Swift RPC function call patterns | Dictionary params with .rpc("name", params: [...]) |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-23 14:45

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes

**Overall Assessment**: This is clean, purposeful UI that follows platform conventions without unnecessary embellishment.

**Strengths**:

1. **HistorySection** - Elegant collapsible section using native DisclosureGroup. Shows last 5 entries with progressive disclosure ("Show all X events"). Loading/empty/error states handled cleanly. The toast overlay for restore feedback is subtle and auto-dismisses.

2. **HistoryEntryRow** - Clear hierarchy: action icon + name at top, human-readable summary below, timestamp + actor at bottom. Restore button appears only when contextually relevant (delete entries with onRestore handler). Uses DS tokens consistently.

3. **HistoryDetailView** - Minimal diff view with before/after rows. Uses minus/plus convention with appropriate semantic colors (deleted=red, added=green). Field formatting is thoughtful (prices, dates, booleans, UUIDs truncated).

4. **RecentlyDeletedView** - Clean filter picker using segmented control. Date-grouped sections (standard iOS pattern). Empty state is helpful ("Items you delete will appear here"). Restore triggers navigation to restored entity.

5. **RecentlyDeletedRow** - Simple HStack with entity icon, title, delete timestamp, and restore button. Touch target is adequate via .contentShape(Rectangle()).

**Design System Compliance**:
- All typography uses DS.Typography tokens (headline, body, caption, captionSecondary)
- All spacing uses DS.Spacing tokens (xs, sm, md, lg)
- All colors use DS.Colors semantic tokens (Text.primary/secondary/tertiary, Status.*, destructive, accent)
- Icons use DS.Icons or action-specific icons with consistent styling
- Platform-adaptive list styles (#if os(iOS) for .insetGrouped)

**Accessibility**:
- VoiceOver labels implemented (.accessibilityElement, .accessibilityLabel)
- Dynamic Type supported via system fonts
- Loading states have descriptive text
- Button states (disabled during restore) properly communicated

**State Handling**:
- Loading: ProgressView with descriptive text
- Empty: Icon + headline + supporting text
- Error: Error icon + retry button (bordered prominent)
- Success: Toast feedback with auto-dismiss

**Minor Observations** (not blocking):
- The destinationView placeholder in RecentlyDeletedView (line 135) shows a text placeholder. This is noted in comments as awaiting integration. Acceptable for PATCHSET 2.
- The relative date extension on Date could be extracted to a shared utility, but it is fine as a file-level extension.

**Would Apple ship this?** Yes. The UI is calm, confident, and purposeful. Information hierarchy is clear. No visual clutter. Native patterns throughout.

---

### Implementation Notes

#### Context7 Usage Required

Agents MUST use Context7 for:
- SwiftUI patterns for DisclosureGroup, NavigationStack, .task modifier
- Supabase Swift client RPC call patterns
- SwiftData model patterns (for PendingDeletion tombstone model)
- Error handling patterns for async/await

#### Test Scenarios (from Plan v1.7 Section I)

These 5 non-negotiable test scenarios must pass:

1. **Restore FK violation**: Restore listing whose property was also deleted -> graceful FK_MISSING error
2. **Restore unique conflict**: Restore entity, delete it again, restore again -> graceful UNIQUE_CONFLICT error
3. **History pagination**: Entity with 100+ history entries -> loads first 50, "Show all" loads rest
4. **Empty states**: New entity with no history -> "No history available" message
5. **Offline restore**: Attempt restore while offline -> queued for retry when online

#### Supabase MCP Tools

Use `mcp__supabase__*` tools for:
- `list_tables` to verify schema structure
- Query verification on local Supabase

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
- **Production migration is BLOCKED** until integrator reports DONE
