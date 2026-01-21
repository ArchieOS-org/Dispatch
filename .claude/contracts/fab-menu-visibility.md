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

**Approach**: Replace unreliable `Menu` with `confirmationDialog` which has proper `isPresented: Binding<Bool>` tracking for dismiss detection.

**Note**: The original approach using `onAppear`/`onDisappear` on Menu content did NOT work reliably - `onDisappear` does not fire when Menu is dismissed. This was discovered during testing.

```swift
// AppOverlayState.swift - existing hide reasons (already added)
enum HideReason: Hashable {
  case textInput
  case keyboard
  case modal
  case searchOverlay
  case settingsScreen
  case fabMenuOpen      // FAB menu is presenting
  case filterMenuOpen   // Filter menu is presenting
}
```

**confirmationDialog Pattern (ACTUAL SOLUTION)**:
```swift
@State private var showFABMenu = false

// Visual FAB tapped to show menu
fabVisual
  .onTapGesture { showFABMenu = true }

// Attached to parent view
.confirmationDialog("New", isPresented: $showFABMenu, titleVisibility: .hidden) {
  // menu actions...
}
.onChange(of: showFABMenu) { _, isPresented in
  if isPresented {
    overlayState.hide(reason: .fabMenuOpen)
  } else {
    overlayState.show(reason: .fabMenuOpen)
  }
}
```

**iPad Unification**:
- iPad FAB overlay uses `AppOverlayState` for visibility (already implemented)
- Same opacity/offset animation as iPhone (already implemented)

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

CONTEXT7_QUERY: Menu view onAppear onDisappear lifecycle tracking content presentation state
CONTEXT7_TAKEAWAYS:
- `onAppear(perform:)` triggers before a view appears
- `onDisappear(perform:)` triggers after a view disappears
- Attach these modifiers to Menu content to track when menu opens/closes
- The action closure completes before the first rendered frame appears
CONTEXT7_APPLIED:
- onAppear/onDisappear on Group wrapper -> GlobalFloatingButtons.swift, FloatingFilterButton.swift, iPadContentView.swift

CONTEXT7_QUERY: Menu dismiss detection isPresented binding confirmationDialog presentation tracking state
CONTEXT7_TAKEAWAYS:
- `Menu` does not expose `isPresented` binding natively
- `confirmationDialog` has proper `isPresented: Binding<Bool>` for tracking dismissal
- Use `onChange(of: isPresented)` to react when dialog is dismissed
- Dialog dismisses automatically when user selects an action or taps outside
CONTEXT7_APPLIED:
- confirmationDialog with isPresented binding -> GlobalFloatingButtons.swift:40, FloatingFilterButton.swift:28, iPadContentView.swift:75

CONTEXT7_QUERY: Menu menuStyle button action label popover dismissal
CONTEXT7_TAKEAWAYS:
- `menuActionDismissBehavior` controls dismiss after action, not dismiss tracking
- SwiftUI Menu does not support reliable dismiss callbacks
- `confirmationDialog` is the correct pattern for tracking presentation state
CONTEXT7_APPLIED:
- Replaced Menu with confirmationDialog for reliable dismiss detection

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI

| Query | Pattern Used |
|-------|--------------|
| Menu view onAppear onDisappear lifecycle tracking content presentation state | onAppear/onDisappear on Group wrapper inside Menu content |
| Menu dismiss detection isPresented binding confirmationDialog presentation tracking state | confirmationDialog with isPresented: Binding<Bool> and onChange |
| Menu menuStyle button action label popover dismissal | Replaced Menu with confirmationDialog for reliable dismiss detection |

**N/A**: Only valid for pure refactors with no framework/library usage.

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-19 17:20

#### Checklist

- [x] Ruthless simplicity - hiding trigger button when menu open is simpler than showing both
- [x] One clear primary action per screen/state - menu becomes the sole focus during presentation
- [x] Strong hierarchy - clear temporal sequence: button -> fade -> menu -> dismiss -> button returns
- [x] No clutter - eliminates competing visual element during menu presentation
- [x] Native feel - matches iOS modal focus pattern, confirmationDialog draws attention to bottom sheet

#### Verdict Notes

This is a clean design improvement. Key observations:

1. **Design Decision is Correct**: Hiding the FAB when its menu is open removes visual redundancy. The button served its purpose (initiating the action) and should step aside for the menu.

2. **Animation is Purposeful**: The 0.2s easeInOut with 12pt offset creates a subtle "sink and fade" effect that feels natural. Both platforms use identical timing for consistency.

3. **Technical Pattern is Sound**: Using `confirmationDialog` with `isPresented` binding provides reliable dismiss detection, unlike the unreliable `onAppear`/`onDisappear` on Menu content.

4. **Accessibility Preserved**: Filter button maintains full a11y attributes. Touch targets exceed HIG minimum. Hit testing disabled when hidden prevents phantom interactions.

5. **Platform Consistency**: iPhone GlobalFloatingButtons, iPad iPadContentView, and FloatingFilterButton all use the same AppOverlayState ref-counted hide reason pattern.

No fixes required. Would Apple ship this? Yes.

---

### Implementation Notes

**Key Findings**:
- SwiftUI `Menu` does NOT expose `isPresented` binding
- `onAppear`/`onDisappear` on Menu content is UNRELIABLE - `onDisappear` does not fire on dismiss
- `confirmationDialog` is the correct pattern - has proper `isPresented: Binding<Bool>` tracking

**Technical Considerations**:
1. `confirmationDialog` with `titleVisibility: .hidden` provides clean action sheet UI
2. `onChange(of: isPresented)` reliably fires on both open AND dismiss (tap outside or action selection)
3. Filter button uses `onTapGesture` (cycle) + `onLongPressGesture` (show menu)
4. Animation matches existing pattern: `.easeInOut(duration: 0.2)`

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
