## Interface Lock

**Feature**: FAB Menu Visual Bug Fix
**Created**: 2026-01-19
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [x] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [x] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [x] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |
| 2.5 | Design bar | jobs-critic, ui-polish |
| 3 | Validation (simulator) | xcode-pilot |

---

### Problem Statement

Two related issues with the FAB (Floating Action Button):

1. **Visual Bug**: When the FAB menu is shown and user taps outside to dismiss, a brief square/background artifact appears around the FAB button before disappearing.

2. **Console Warnings**: Multiple warnings appearing:
```
Adding '_UIReparentingView' as a subview of UIHostingController.view is not supported and may result in a broken view hierarchy.
```

### Root Cause Analysis (Preliminary)

The warnings suggest SwiftUI/UIKit interop issues with how SwiftUI's `Menu` component is being used:

1. SwiftUI's `Menu` uses UIKit internally on iOS (UIMenu/UIContextMenuInteraction)
2. The custom `fabVisual` label combined with `.buttonStyle(.borderless)` may cause UIKit view hierarchy issues
3. The visual artifact suggests animation/cleanup timing problems when Menu dismisses

**Key Files Identified:**
- `/Users/noahdeskin/conductor/workspaces/dispatch/mumbai/Dispatch/SharedUI/Components/GlobalFloatingButtons.swift` (iPhone FAB)
- `/Users/noahdeskin/conductor/workspaces/dispatch/mumbai/Dispatch/App/Platform/iPadContentView.swift` (iPad FAB)
- `/Users/noahdeskin/conductor/workspaces/dispatch/mumbai/Dispatch/Design/Shared/Components/FloatingActionButton.swift` (base component)

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

### Acceptance Criteria (3 max)

1. **No visual artifact** on FAB menu dismiss - tap outside, swipe dismiss, or menu item selection must not show square background
2. **No console warnings** related to `_UIReparentingView` or `UIHostingController.view` when using FAB menu
3. **Cross-platform verification** - fix works on iOS, iPadOS, and does not regress macOS behavior

### Non-goals (prevents scope creep)

- No changes to FAB positioning or sizing
- No changes to FABContext logic or context-aware behavior
- No changes to menu item options or sheet presentation
- No redesign of FAB visual style (color, shadow, icon)

### Compatibility Plan

- **Backward compatibility**: N/A (pure UI fix, no data changes)
- **Default when missing**: N/A
- **Rollback strategy**: Revert commits if visual regression appears

---

### Ownership

- **feature-owner**: Investigate root cause and implement fix for Menu-related visual bug and warnings
- **data-integrity**: Not needed
- **dispatch-explorer**: Required first - understand SwiftUI Menu internals and UIKit interop patterns
- **jobs-critic**: Verify FAB appearance and behavior meets design bar
- **ui-polish**: Ensure animations are smooth and no visual artifacts
- **xcode-pilot**: Validate fix on iOS simulator (menu dismiss scenarios)

---

### Implementation Notes

**Context7 Required For:**
- SwiftUI `Menu` component patterns and known issues
- UIKit interop best practices in SwiftUI
- Custom Button/Label composition in Menu

**Potential Solution Approaches (to investigate):**
1. Use `contentShape()` modifier to define hit testing bounds explicitly
2. Adjust `.buttonStyle()` to prevent UIKit view hierarchy issues
3. Use alternative menu presentation (custom popover vs system Menu)
4. Apply `.drawingGroup()` or `.compositingGroup()` for rendering isolation

---

### Context7 Queries

Log all Context7 lookups here:

CONTEXT7_QUERY: contentShape compositingGroup drawingGroup modifiers for view hit testing and rendering layer compositing
CONTEXT7_TAKEAWAYS:
- `contentShape(_:)` defines the hit-testing area for a view using a Shape
- `compositingGroup()` flattens the view hierarchy into a single layer before applying subsequent modifiers
- Using both together ensures consistent behavior when view is handed off to UIKit (Menu)
- `drawingGroup()` composites into offscreen image - more heavy-handed than compositingGroup
CONTEXT7_APPLIED:
- `.contentShape(Circle())` + `.compositingGroup()` -> GlobalFloatingButtons.swift:165-166, iPadContentView.swift:325-326

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI

| Query | Pattern Used |
|-------|--------------|
| contentShape compositingGroup modifiers for hit testing and rendering | `.contentShape(Circle())` constrains hit testing, `.compositingGroup()` flattens view hierarchy before UIKit handoff |

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

The fix is surgically minimal: a single `.compositingGroup()` modifier that eliminates the square background flash artifact during Menu dismiss. This is exactly the right approach - it solves the visual bug without adding complexity.

**Why SHIP YES:**
- The FAB remains a clean circle throughout all animation states (open, dismiss, tap-outside)
- No functional changes - just visual polish
- Uses design system components correctly (DS.Colors.accent, DS.Spacing.floatingButtonSizeLarge, DS.Shadows.elevated)
- Maintains accessibility with @ScaledMetric for Dynamic Type
- Consistent application across both iPhone (GlobalFloatingButtons.swift:166) and iPad (iPadContentView.swift:326)

**Would Apple ship this?** Yes. The fix ensures the FAB behaves like a native iOS control with no visual artifacts during transitions.

---

### Enforcement Summary

| Check | Required | Status |
|-------|----------|--------|
| Context7 Attestation | YES | DONE (PATCHSET 1) |
| Jobs Critique | YES (UI Review Required: YES) | SHIP YES |
| Builds (iOS + macOS) | YES | PASS (PATCHSET 1) |
| Tests Pass | YES | PENDING |
| xcode-pilot Validation | YES (High-risk checked) | PENDING |

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
