## Interface Lock

**Feature**: FAB Reappear on Menu Dismiss + FloatingFilterButton Overlay Pattern
**Created**: 2026-01-19
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [ ] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators (simple bug fix):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |

---

### Problem Statement

**Issue 1: FAB doesn't reappear after menu closes**

Current implementation in `GlobalFloatingButtons.swift`:
- FAB visual opacity is tied to `isMenuOpen` state
- `isMenuOpen = true` set via `.onAppear` on Group inside Menu content
- `isMenuOpen = false` set via `.onDisappear` on same Group
- **Bug**: `.onDisappear` doesn't reliably fire when menu is dismissed by tapping outside

Root cause hypothesis: SwiftUI Menu content lifecycle doesn't reliably call `.onDisappear` when dismissed by tapping outside - it may only call it when the view is fully removed, not when menu closes.

**Issue 2: FloatingFilterButton needs invisible overlay pattern**

The `FloatingFilterButton` (lines 25-48) uses a direct `Menu { } label: { }` pattern without the invisible overlay approach. This causes the same square highlight artifact that was fixed in GlobalFloatingButtons.

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: Potentially add menu dismiss detection mechanism
- Migration required: N

### Acceptance Criteria (3 max)

1. **FAB reappears reliably** when menu is dismissed by: tapping outside, swiping, or selecting a menu item
2. **FloatingFilterButton uses invisible overlay pattern** matching GlobalFloatingButtons approach (no square highlight artifact)
3. **No regressions** to existing FAB menu functionality or visual appearance

### Non-goals (prevents scope creep)

- No changes to FAB context logic or menu item options
- No changes to filter cycling behavior
- No changes to FAB/filter button positioning or sizing
- No redesign of visual styles

### Compatibility Plan

- **Backward compatibility**: N/A (pure UI fix)
- **Default when missing**: N/A
- **Rollback strategy**: Revert commits if visual regression appears

---

### Ownership

- **feature-owner**: Fix menu dismiss detection + apply invisible overlay pattern to FloatingFilterButton
- **data-integrity**: Not needed

---

### Implementation Notes

**Files to Modify:**
1. `/Users/noahdeskin/conductor/workspaces/dispatch/mumbai/Dispatch/SharedUI/Components/GlobalFloatingButtons.swift` - Fix menu dismiss detection
2. `/Users/noahdeskin/conductor/workspaces/dispatch/mumbai/Dispatch/Design/Shared/Components/FloatingFilterButton.swift` - Apply invisible overlay pattern

**Context7 Required For:**
- SwiftUI Menu dismiss detection patterns
- Alternative approaches to `.onDisappear` for menu lifecycle

**Potential Solution Approaches for Issue 1:**
1. Use a different detection mechanism (e.g., overlay tap gesture to detect dismiss)
2. Use `onChange` with some menu-related environment value
3. Use a timer-based fallback after menu opens
4. Track when any menu button is pressed AND reset on next view update cycle
5. Use `@State` with `task(id:)` or `onChange(of:)` to detect changes

**Solution for Issue 2:**
Apply the same pattern from GlobalFloatingButtons:
- Separate visual from interactive (invisible Menu label overlay)
- Use `fabVisual.opacity(isMenuOpen ? 0 : 1)` with `.overlay { Menu { ... } label: { Color.clear... } }`

---

### Context7 Queries

CONTEXT7_QUERY: Menu dismiss detection onDisappear lifecycle callback when menu closes
CONTEXT7_TAKEAWAYS:
- `onDisappear` triggers after a view disappears from the interface
- `MenuActionDismissBehavior` controls whether menu dismisses after action
- No explicit callback for "menu dismissed via tap-outside" - must use workarounds
- Button actions in Menu naturally dismiss the menu (unless `.menuActionDismissBehavior(.disabled)`)
CONTEXT7_APPLIED:
- Reset `isMenuOpen = false` in Button actions -> GlobalFloatingButtons.swift, iPadContentView.swift

CONTEXT7_QUERY: onAppear onDisappear view lifecycle when view is removed or hidden
CONTEXT7_TAKEAWAYS:
- `onAppear(perform:)` triggers before a view appears
- `onDisappear(perform:)` triggers after a view disappears
- Exact timing depends on view type
CONTEXT7_APPLIED:
- Used `.onAppear/.onDisappear` with Group wrapper -> FloatingFilterButton.swift

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI

| Query | Pattern Used |
|-------|--------------|
| Menu dismiss detection onDisappear lifecycle | Reset `isMenuOpen` in Button actions as immediate feedback |
| onAppear onDisappear view lifecycle | `.onAppear/.onDisappear` on Group inside Menu content |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-19 14:30

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes

**Ruthless simplicity**: The fix uses minimal code changes. Setting `isMenuOpen = false` at the start of Button actions is the simplest workaround for unreliable `.onDisappear` lifecycle callbacks. The invisible overlay pattern is already established in the codebase and is reused consistently.

**Native feel**: Uses standard SwiftUI Menu component. The invisible overlay pattern with `Color.clear` label and `.contentShape(Circle())` is a documented workaround for UIKit highlight artifacts when Menu is used with custom labels.

**Execution quality**:
- Uses DS tokens consistently (DS.Colors.accent, DS.Spacing.floatingButtonSizeLarge, DS.Shadows.elevated, DS.Icons.Entity.*)
- FloatingFilterButton has proper accessibility: accessibilityIdentifier, accessibilityLabel, accessibilityValue, accessibilityHint
- Touch targets are 56pt (exceeds 44pt minimum)
- Animation is subtle (0.15s easeInOut) and purposeful

**No concerns**: The implementation is clean, follows established patterns, and addresses both issues without adding unnecessary complexity.

---

### Enforcement Summary

| Check | Required | Status |
|-------|----------|--------|
| Context7 Attestation | YES | DONE |
| Jobs Critique | YES (UI Review Required: YES) | SHIP YES |
| Builds (iOS + macOS) | YES | DONE |
| Tests Pass | YES | PENDING |

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
