## Interface Lock

**Feature**: Fix Over-Scoped macOS Prohibition
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

Simplified plan (documentation-only changes):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | All files updated | feature-owner |
| 2 | Build verification | integrator |

---

### Problem Statement

The previous change incorrectly prohibited `build_macos` and `test_macos` which are safe headless operations. These need to be restored while keeping the UI control tools blocked.

### Correct Scope

**ALLOWED (safe headless operations):**
- `mcp__xcodebuildmcp__build_macos` - compile only, no launch
- `mcp__xcodebuildmcp__test_macos` - unit tests, no UI control

**BLOCKED (takes over Mac):**
- `mcp__xcodebuildmcp__build_run_macos` - builds AND launches app
- `mcp__xcodebuildmcp__launch_mac_app` - launches macOS app
- `mcp__xcodebuildmcp__stop_mac_app` - stops macOS app

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

### Files to Modify

| File | Change |
|------|--------|
| `.claude/rules/no-macos-control.md` | Remove `build_macos` and `test_macos` from prohibited list; add to allowed list; clarify distinction |
| `.claude/agents/integrator.md` | Add `mcp__xcodebuildmcp__build_macos` and `mcp__xcodebuildmcp__test_macos` to tools list |
| `.claude/agents/feature-owner.md` | Add `mcp__xcodebuildmcp__build_macos` to tools list |
| `.claude/agents/ui-polish.md` | Add `mcp__xcodebuildmcp__build_macos` to tools list |
| `CLAUDE.md` | Restore line 310 from "Builds on iOS" back to "Builds on iOS + macOS" |

### Acceptance Criteria (3 max)

1. `build_macos` and `test_macos` are NOT in prohibited tools list
2. `build_macos` is in integrator, feature-owner, and ui-polish agent tool lists; `test_macos` is in integrator tool list
3. CLAUDE.md "Done" Definition says "Builds on iOS + macOS"

### Non-goals (prevents scope creep)

- No changes to which tools are actually BLOCKED (build_run_macos, launch_mac_app, stop_mac_app remain blocked)
- No new functionality or behavior changes
- No changes to iOS/simulator tool access

### Compatibility Plan

- **Backward compatibility**: N/A (documentation only)
- **Default when missing**: N/A
- **Rollback strategy**: Git revert

---

### Ownership

- **feature-owner**: Update all 5 files per spec
- **data-integrity**: Not needed

---

### Context7 Queries

N/A - Documentation/configuration changes only, no framework code.

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: N/A
**Libraries Queried**: N/A

| Query | Pattern Used |
|-------|--------------|
| N/A - no framework code | N/A |

**N/A**: Valid for pure documentation/configuration changes with no framework/library usage.

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A
**Reviewed**: N/A

Jobs Critique not required (UI Review Required: NO).

---

**IMPORTANT**:
- `UI Review Required: NO` → Jobs Critique section is not required; integrator skips this check
- Context7 Attestation: N/A is valid for documentation-only changes
