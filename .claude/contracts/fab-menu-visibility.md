## Interface Lock

**Feature**: FAB/Button Hide When Menu Open
**Created**: 2026-01-19
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [x] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [ ] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |
| 2.5 | Design bar | jobs-critic, ui-polish |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added:
  - `AppOverlayState.HideReason.fabMenuOpen` - new reason for FAB menu visibility
  - `AppOverlayState.HideReason.filterMenuOpen` - new reason for filter button menu visibility
- Migration required: N

### Problem Statement

Bottom buttons (FAB and filter) should disappear when their menu opens and reappear when the menu closes. Current implementation has:
1. **No menu-open tracking** - buttons don't know when their menu is open
2. **Two different visibility systems** - iPhone uses `AppOverlayState` (ref-counted), iPad uses conditional render
3. **No animation on iPad FAB hide** - iPad FAB disappears without transition
4. **Messy "invisible Menu overlay" pattern** - triggers menus but doesn't coordinate visibility

### Solution Design

**Approach**: Extend `AppOverlayState` with menu-specific hide reasons, using `onAppear`/`onDisappear` on Menu content to track menu presentation state.

```swift
// AppOverlayState.swift - add new hide reasons
enum HideReason: Hashable {
  case textInput
  case keyboard
  case modal
  case searchOverlay
  case settingsScreen
  case fabMenuOpen      // NEW: FAB menu is presenting
  case filterMenuOpen   // NEW: Filter menu is presenting
}
```

**Menu Content Tracking Pattern**:
```swift
// Track menu open state via content lifecycle
Menu {
  VStack {  // Wrapper to attach lifecycle
    // menu items...
  }
  .onAppear { overlayState.hide(reason: .fabMenuOpen) }
  .onDisappear { overlayState.show(reason: .fabMenuOpen) }
} label: {
  // button visual
}
```

**iPad Unification**:
- iPad FAB overlay should also use `AppOverlayState` for visibility
- Add same opacity/offset animation that iPhone uses

### Files to Modify

| File | Changes |
|------|---------|
| `Dispatch/App/State/AppOverlayState.swift` | Add `.fabMenuOpen` and `.filterMenuOpen` hide reasons |
| `Dispatch/SharedUI/Components/GlobalFloatingButtons.swift` | Add `onAppear`/`onDisappear` to Menu content for FAB |
| `Dispatch/Design/Shared/Components/FloatingFilterButton.swift` | Add `onAppear`/`onDisappear` to Menu content |
| `Dispatch/App/Platform/iPadContentView.swift` | Use `AppOverlayState` for FAB visibility, add animation |

### Acceptance Criteria (3 max)

1. When FAB menu opens, FAB button hides with animated transition (both iPhone and iPad)
2. When filter menu opens, filter button hides with animated transition (iPhone)
3. Both buttons reappear with animation when their respective menus close

### Non-goals (prevents scope creep)

- No changes to menu content or actions
- No changes to other hide reasons behavior
- No new UI components or navigation flows
- No iPad filter button (iPad uses toolbar FilterMenu)

### Compatibility Plan

- **Backward compatibility**: N/A - no DTOs or API changes
- **Default when missing**: N/A
- **Rollback strategy**: Remove new hide reasons, revert visibility logic

---

### Ownership

- **feature-owner**: Implement menu tracking via onAppear/onDisappear, unify iPad visibility system
- **data-integrity**: Not needed

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

- [To be filled by feature-owner at PATCHSET 1]

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: PENDING
**Libraries Queried**: PENDING

| Query | Pattern Used |
|-------|--------------|
| PENDING | PENDING |

**N/A**: Only valid for pure refactors with no framework/library usage.

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: PENDING
**Reviewed**: PENDING

#### Checklist

- [ ] Ruthless simplicity - nothing can be removed without losing meaning
- [ ] One clear primary action per screen/state
- [ ] Strong hierarchy - headline -> primary -> secondary
- [ ] No clutter - whitespace is a feature
- [ ] Native feel - follows platform conventions

#### Verdict Notes

[jobs-critic writes specific feedback here]

---

### Implementation Notes

**Context7 Research Recommended**:
- SwiftUI Menu presentation state tracking patterns
- Best practices for coordinating view visibility with Menu lifecycle
- Apple HIG guidance on floating button behavior during overlays

**Technical Considerations**:
1. SwiftUI `Menu` does not expose `isPresented` binding natively
2. `onAppear`/`onDisappear` on menu content is the idiomatic workaround
3. The wrapper `VStack` or `Group` is needed to attach lifecycle modifiers to menu content
4. Animation should match existing iPhone FAB animation (`.easeInOut(duration: 0.2)`)

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
