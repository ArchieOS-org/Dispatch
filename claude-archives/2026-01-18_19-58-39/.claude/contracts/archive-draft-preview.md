## Interface Lock

**Feature**: Archive Draft Preview
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

### Patchset Plan

Based on checked indicators (none checked - simple archive operation):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, builds verified (iOS + macOS) | feature-owner, integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

### Acceptance Criteria (3 max)

1. All Draft Preview files moved to `Dispatch/Archive/DraftPreview/` directory
2. All references removed from `SettingsView.swift` and `AppDestinations.swift`
3. Builds successfully on iOS and macOS

### Non-goals (prevents scope creep)

- No changes to archived file contents (preserve as-is for reference)
- No removal of the Archive directory or other archived features
- No refactoring of Settings or navigation beyond removing Draft Preview references

### Compatibility Plan

- **Backward compatibility**: N/A (demo feature, no backend or user data)
- **Default when missing**: N/A
- **Rollback strategy**: Git revert; archived files remain in Archive folder

---

### Files to Archive

Move to `Dispatch/Archive/DraftPreview/`:

1. `Dispatch/Features/Demo/Models/DemoListingDraft.swift`
2. `Dispatch/Features/Demo/Views/Screens/ListingDraftDemoView.swift`
3. `Dispatch/Features/Demo/Views/Components/DraftPhotoGallery.swift`
4. `Dispatch/Features/Demo/Views/Components/DraftPhotoThumbnail.swift`

After archiving, remove empty `Dispatch/Features/Demo/` directory.

### Files to Modify

1. **SettingsView.swift**: Remove `case listingDraftDemo` from `SettingsSection` enum and all switch cases
2. **AppDestinations.swift**: Remove `.listingDraftDemo` case from `settingsDestination(for:)` switch

### Reference Pattern

Existing archive at: `Dispatch/Archive/ListingGenerator/`

---

### Ownership

- **feature-owner**: Archive files, remove navigation references, verify builds
- **data-integrity**: Not needed

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

- N/A - Pure file archival operation with no framework/library usage

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: N/A
**Libraries Queried**: N/A

| Query | Pattern Used |
|-------|--------------|
| N/A | Pure refactor/archive - no framework code written |

**N/A**: Valid for pure refactors with no framework/library usage.

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A
**Reviewed**: N/A

#### Checklist

N/A - UI Review not required (feature removal, not addition/change)

#### Verdict Notes

Jobs Critique skipped - `UI Review Required: NO` (archiving/removing feature, no customer-facing UI changes)

---

### Enforcement Summary

- [x] Contract created and locked
- [x] PATCHSET 1: Files archived, references removed, compiles
- [x] PATCHSET 2: Builds verified on iOS + macOS
- [x] Context7 Attestation: N/A (pure archive operation)
- [x] Jobs Critique: N/A (UI Review Required: NO)
- [ ] Integrator: DONE

---

**IMPORTANT**:
- `UI Review Required: NO` - Jobs Critique section skipped; integrator skips this check
- `CONTEXT7 CONSULTED: N/A` - Valid for pure archive/refactor operations
