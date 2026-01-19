## Interface Lock

**Feature**: FAB Square Background Fix
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

### Patchset Plan

**Minimal plan** - single patchset for styling-only fix:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles + criteria met | feature-owner, integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

### Problem

When user taps FAB to open Menu, then dismisses it, a square background briefly appears around the circular FAB. SwiftUI's default Menu styling applies a rectangular highlight to custom labels.

### Fix

Add `.buttonStyle(.borderless)` to suppress the rectangular highlight on Menu components:

```swift
Menu { ... } label: { fabVisual }
  .menuIndicator(.hidden)
  .buttonStyle(.borderless)  // Suppresses rectangular highlight
```

### Files to Modify

1. `/Users/noahdeskin/conductor/workspaces/dispatch/mumbai/Dispatch/SharedUI/Components/GlobalFloatingButtons.swift` - iPhone FAB Menu
2. `/Users/noahdeskin/conductor/workspaces/dispatch/mumbai/Dispatch/App/Platform/iPadContentView.swift` - iPad FAB Menu

### Acceptance Criteria (3 max)

1. FAB dismissal no longer shows square background artifact on iPhone
2. FAB dismissal no longer shows square background artifact on iPad
3. Menu still opens correctly on tap (no functional regression)

### Non-goals (prevents scope creep)

- No visual redesign of FAB
- No changes to menu items or actions
- No macOS changes (FAB is mobile-only)

### Compatibility Plan

- **Backward compatibility**: N/A - styling only
- **Default when missing**: N/A
- **Rollback strategy**: Remove `.buttonStyle(.borderless)` modifier

---

### Ownership

- **feature-owner**: Add `.buttonStyle(.borderless)` to FAB Menus in both files
- **data-integrity**: Not needed

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: buttonStyle borderless Menu suppress highlight remove background
CONTEXT7_TAKEAWAYS:
- `MenuStyle.borderlessButton` is deprecated (iOS 14.0-26.2)
- Modern replacement: use `menuStyle(.button)` + `buttonStyle(.borderless)`
- `.buttonStyle(_:)` can extend styling to Menu controls when configured appropriately
- `.menuIndicator(.hidden)` is still the correct way to hide the menu indicator arrow
- `BorderlessButtonStyle` provides a button style with no border decoration
CONTEXT7_APPLIED:
- `.buttonStyle(.borderless)` -> GlobalFloatingButtons.swift (3 Menu usages) and iPadContentView.swift (3 Menu usages)

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (/websites/developer_apple_swiftui)

| Query | Pattern Used |
|-------|--------------|
| buttonStyle borderless Menu suppress highlight | `.buttonStyle(.borderless)` on Menu |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A
**Reason**: UI Review Required: NO - this is a bug fix that restores expected visual behavior, not a UI change.

---

### Enforcement Summary

| Check | Required | Status |
|-------|----------|--------|
| Builds (iOS + macOS) | YES | PASS |
| Tests pass | YES | N/A (styling-only, no test coverage) |
| Context7 Attestation | YES | PASS |
| Jobs Critique | NO | N/A |
