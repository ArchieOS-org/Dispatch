## Interface Lock

**Feature**: Fix activity_type Schema Mismatch Error
**Created**: 2026-01-18
**Status**: PATCHSET 2 COMPLETE (all migrations applied)
**Lock Version**: v1
**UI Review Required**: NO

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [x] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [x] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Investigation complete, root cause identified | dispatch-explorer |
| 1.5 | Schema fix applied and verified | data-integrity |
| 2 | Tests pass, sync works | feature-owner, integrator |

---

### Investigation Summary (Pre-Contract Analysis)

**Error**: `column "activity_type" of relation "activities" does not exist`

**Findings**:

1. **Database State (Supabase)**: The `activities` table does NOT have an `activity_type` column (verified via `mcp__supabase__list_tables`)

2. **Schema File Mismatch**: `supabase_schema.sql` line 131 defines:
   ```sql
   activity_type TEXT DEFAULT 'other',
   ```
   This column was never created in production OR was dropped without updating the schema file.

3. **Migration Evidence**: `supabase_multi_assignee_migration.sql` line 188 has:
   ```sql
   --   DROP COLUMN activity_type;
   ```
   This suggests `activity_type` was intended to be removed but the DROP is commented out, indicating either:
   - The column never existed in production
   - The column was dropped but schema file not updated

4. **Swift Code Status**: `ActivityDTO.swift` does NOT reference `activity_type` - correctly aligned with database.

5. **Root Cause Hypothesis**: A database trigger, function, RLS policy, or view references `activity_type` that no longer exists. The `broadcast_table_changes()` trigger uses `to_jsonb(NEW)` which shouldn't cause this. The most likely culprit is an RLS policy or computed column reference.

### What Needs Investigation (PATCHSET 1)

1. Query Supabase for any database objects referencing `activity_type`:
   - RLS policies on `activities` table
   - Triggers on `activities` table
   - Functions that select from `activities`
   - Views that reference `activities`

2. Determine if the column should be:
   - **Added**: If referenced by existing database logic
   - **Removed from references**: If the column was intentionally dropped

### Contract

- New/changed model fields: None (Swift code is correct)
- DTO/API changes: None
- State/actions added: None
- Migration required: YES - either add column or remove stale references

### Acceptance Criteria (3 max)

1. `syncUpActivities()` completes without "activity_type does not exist" error
2. `syncDownActivities()` completes without error
3. Full sync cycle (syncDown + syncUp) succeeds

### Non-goals (prevents scope creep)

- No changes to ActivityDTO structure
- No changes to Activity model
- No new features or columns beyond fixing the mismatch

### Compatibility Plan

- **Backward compatibility**: N/A - fixing broken state
- **Default when missing**: N/A
- **Rollback strategy**: If column added, can DROP it; if reference removed, restore from SQL backup

---

### Ownership

- **dispatch-explorer**: Identify exact database object(s) referencing activity_type
- **data-integrity**: Write and execute migration to fix schema mismatch
- **feature-owner**: Verify sync operations work after fix
- **integrator**: Verify builds pass and sync tests pass

---

### Context7 Queries

- N/A for this fix (database schema investigation, not framework patterns)

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: N/A
**Libraries Queried**: N/A

This is a database schema fix requiring SQL investigation, not framework/library patterns.

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A (UI Review Required: NO)
**Reviewed**: N/A

---

### Investigation Tasks for dispatch-explorer

**COMPLETED** - Root cause identified as `fn_generate_activities_for_listing` function.

Queries executed to identify the culprit:

```sql
-- 3. Find functions referencing activity_type
SELECT proname, prosrc
FROM pg_proc
WHERE prosrc LIKE '%activity_type%'
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
```

**Result**: Found `fn_generate_activities_for_listing` function inserting into non-existent `activity_type` column.

---

### Migrations Applied (PATCHSET 1.5 + PATCHSET 2 - COMPLETE)

**Migration 1**: `fix_activity_type_reference`
**Applied**: 2026-01-18
**Status**: SUCCESS
**Change**: Removed `activity_type` column and `'other'` value from function

**Migration 2**: `fix_activity_priority_reference`
**Applied**: 2026-01-18
**Status**: SUCCESS
**Change**: Removed `priority` column and `'medium'` value from function

**Final SQL**:
```sql
CREATE OR REPLACE FUNCTION public.fn_generate_activities_for_listing(
    p_listing_id uuid,
    p_listing_type_id uuid,
    p_declared_by uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.activities (
        id,
        title,
        description,
        status,
        declared_by,
        listing,
        audiences,
        source_template_id,
        created_via,
        created_at,
        updated_at
    )
    SELECT
        gen_random_uuid(),
        at.title,
        at.description,
        'open',
        p_declared_by,
        p_listing_id,
        at.audiences,
        at.id,
        'dispatch',
        now(),
        now()
    FROM public.activity_templates at
    WHERE at.listing_type_id = p_listing_type_id
      AND NOT at.is_archived
    ON CONFLICT DO NOTHING;
END;
$$;
```

**Change Summary**:
- Removed `activity_type` column (doesn't exist in activities table)
- Removed `priority` column (doesn't exist in activities table)
- Function now correctly inserts only into columns that exist in the `activities` table

---

### Risk Assessment

- **Lane**: Guarded (schema change, but additive/fixing broken state)
- **Dangerous Ops**: None anticipated (no destructive changes to existing data)
- **Sync Impact**: HIGH - this blocks all activity sync operations

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- **Context7 Attestation**: N/A for pure database schema fixes
