## Interface Lock

**Feature**: Remove Dead NativeSplitView Code
**Created**: 2026-01-19
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

**Note**: All indicators unchecked. This is a dead code deletion task.

### Patchset Plan

Minimal patchset (dead code removal):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles on iOS + macOS | feature-owner |
| 2 | Tests pass, file deleted | feature-owner, integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

### Background

The user identified 6 issues with `NativeSplitView`:
1. Environment propagation broken (NSHostingController barrier)
2. Toolbar modifiers do not work (trapped inside NSHostingController)
3. Safe area violations (manual frame = view.bounds)
4. Conflicts with NavigationSplitView (both exist for macOS)
5. BottomToolbar clipping (safeAreaInset local to hosting controller)
6. Lifecycle issues (viewDidLayout called many times)

**Discovery**: Codebase exploration revealed `NativeSplitView` is **not used anywhere**. `MacContentView.swift` already uses `NavigationSplitView` exclusively. The `NativeSplitView.swift` file is dead code from a previous refactor.

### Files to Delete

1. `/Users/noahdeskin/conductor/workspaces/dispatch/san-jose-v1/Dispatch/Foundation/Platform/macOS/NativeSplitView.swift`
   - Contains `NativeSplitView` struct
   - Contains `DispatchSplitViewController` class
   - Contains preview code
   - **Not referenced anywhere** except its own definition

### Acceptance Criteria (3 max)

1. `NativeSplitView.swift` is deleted from the codebase
2. Build succeeds on iOS and macOS (confirms no hidden dependencies)
3. No references to `NativeSplitView` or `DispatchSplitViewController` remain

### Non-goals (prevents scope creep)

- No changes to `MacContentView.swift` (already uses NavigationSplitView correctly)
- No changes to BottomToolbar positioning (already working)
- No changes to toolbar commands or sidebar behavior
- No verification of environment propagation (out of scope - separate contract if needed)

### Compatibility Plan

- **Backward compatibility**: N/A - removing unused code
- **Default when missing**: N/A
- **Rollback strategy**: Restore file from git history if needed

---

### Ownership

- **feature-owner**: Delete NativeSplitView.swift, verify builds
- **data-integrity**: Not needed

---

### Context7 Queries

N/A - Pure deletion of dead code, no framework patterns involved.

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: N/A
**Libraries Queried**: N/A

| Query | Pattern Used |
|-------|--------------|
| N/A - pure refactor/deletion | N/A |

**N/A**: Valid for pure refactors with no framework/library usage.

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A
**Reviewed**: N/A

Not required - `UI Review Required: NO` (no customer-facing changes, no UI changes at all).

---

### Enforcement Summary

- [x] Contract created and locked
- [ ] File deleted (PATCHSET 1)
- [ ] iOS build verified (PATCHSET 2)
- [ ] macOS build verified (PATCHSET 2)
- [ ] Integrator reports DONE

---

**IMPORTANT**:
- `UI Review Required: NO` - Jobs Critique check skipped
- `Context7 Attestation: N/A` - Valid for pure deletion with no framework usage
- This qualifies for Small Change Bypass (1 file, no schema, no UI, no sync)
