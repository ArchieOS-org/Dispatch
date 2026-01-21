## Interface Lock

**Feature**: FAB Menu iOS 26 Redesign
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
- [x] **Unfamiliar area** (adds dispatch-explorer) - iOS 26 liquid glass and spring animations

### Patchset Plan

Based on checked indicators:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles - Independent visibility logic | feature-owner |
| 2 | Complete - Custom menu overlays with iOS 26 effects | feature-owner, integrator |
| 2.5 | Design bar | jobs-critic, ui-polish |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None (existing `AppOverlayState` reasons already exist)
- Migration required: N

### Problem Statement

Current implementation has two bugs:
1. **Both buttons disappear when either menu opens** - `shouldHideButtons` checks `overlayState.isOverlayHidden` which returns true if ANY reason is active, causing both FAB and filter button to hide when only one menu is open
2. **Menus appear as bottom action sheets** - Using `confirmationDialog` which presents as iOS action sheet at bottom of screen, not as floating popup over the button

### Solution Approach

1. **Independent visibility per button** - Each button checks only its own menu's reason:
   - FAB: `overlayState.isReasonActive(.fabMenuOpen)`
   - Filter: `overlayState.isReasonActive(.filterMenuOpen)`

2. **Custom menu overlay instead of confirmationDialog** - Build custom floating menu that:
   - Positions directly over the button location
   - Uses iOS 26 liquid glass material background
   - Animates with iOS 26 bounce-out spring effect
   - Dismisses on tap outside or option selection

### Files to Modify

| File | Changes |
|------|---------|
| `Dispatch/SharedUI/Components/GlobalFloatingButtons.swift` | Separate FAB visibility check, replace confirmationDialog with custom menu overlay |
| `Dispatch/Design/Shared/Components/FloatingFilterButton.swift` | Separate filter visibility check, replace confirmationDialog with custom menu overlay |
| `Dispatch/App/Platform/iPadContentView.swift` | Same changes for iPad FAB |
| `Dispatch/App/State/AppOverlayState.swift` | No changes needed - already has `.fabMenuOpen` and `.filterMenuOpen` reasons |

### Acceptance Criteria (7 total for this feature)

1. FAB menu opens -> only FAB hides, filter button stays visible
2. Filter menu opens -> only filter button hides, FAB stays visible
3. Menu appears as floating popup positioned over button location (not at screen bottom)
4. Menu background uses iOS 26 liquid glass material effect (glassBackgroundEffect)
5. Menu animates in with iOS 26 bounce-out spring animation (interpolatingSpring)
6. Dismiss works correctly (tap outside or select option closes menu, button reappears)
7. Works on iPhone, iPad, and macOS (macOS uses native styling)

### Non-goals (prevents scope creep)

- No changes to menu content/options (keep existing New Task/Activity/Listing etc.)
- No changes to FAB visual design beyond menu presentation
- No changes to filter button tap-to-cycle behavior
- No new features or capabilities beyond fixing the two bugs

### Compatibility Plan

- **Backward compatibility**: N/A - UI-only changes
- **Default when missing**: N/A
- **Rollback strategy**: Revert to confirmationDialog if iOS 26 APIs unavailable (version check)

---

### Ownership

- **feature-owner**: Full vertical slice - visibility logic + custom menu overlay implementation
- **data-integrity**: Not needed

---

### Implementation Notes

**CRITICAL: Context7 is REQUIRED for iOS 26 APIs**

feature-owner MUST query Context7 for:
1. **iOS 26 liquid glass material** - `glassBackgroundEffect` or equivalent glass material modifier
2. **iOS 26 spring animation** - `interpolatingSpring` with bounce parameters
3. **Custom popover positioning** - Positioning overlay relative to source view

DO NOT guess at iOS 26 API names or parameters. Context7 attestation is mandatory.

**Suggested Queries:**
- SwiftUI: "iOS 26 glass background effect liquid glass material"
- SwiftUI: "interpolatingSpring bounce animation iOS 26"
- SwiftUI: "custom popover positioning anchor preference"

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: iOS 26 liquid glass material glassBackgroundEffect background material effect
CONTEXT7_TAKEAWAYS:
- `glassBackgroundEffect(in: Shape, displayMode:)` applies glass effect to custom shapes
- Available primarily on visionOS, use `.ultraThinMaterial` as fallback for iOS
- Shape must conform to `InsettableShape`
CONTEXT7_APPLIED:
- `.ultraThinMaterial` for iOS compatibility -> Menu overlay background

CONTEXT7_QUERY: interpolatingSpring bounce animation iOS 26
CONTEXT7_TAKEAWAYS:
- `.interpolatingSpring(duration: TimeInterval, bounce: Double, initialVelocity: Double)` creates bouncy spring
- `bounce` parameter: 0 = critically damped, positive = bouncy (up to 1.0)
- Preserves velocity across overlapping animations
CONTEXT7_APPLIED:
- `.interpolatingSpring(duration: 0.35, bounce: 0.3)` -> Menu appear/disappear animation

CONTEXT7_QUERY: custom popover overlay positioned relative to source view anchor preference GeometryReader
CONTEXT7_TAKEAWAYS:
- Use `overlay(alignment:)` modifier to position content relative to base view
- ZStack with alignment for layered positioning
- PopoverAttachmentAnchor for standard popovers
CONTEXT7_APPLIED:
- Custom overlay with `.top` alignment -> Menu positioned above FAB

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (/websites/developer_apple_swiftui)

| Query | Pattern Used |
|-------|--------------|
| iOS 26 liquid glass material glassBackgroundEffect | `.ultraThinMaterial` (glassBackgroundEffect is visionOS-only) |
| interpolatingSpring bounce animation iOS 26 | `.interpolatingSpring(duration: 0.35, bounce: 0.3)` |
| custom popover overlay positioned relative to source view | `overlay(alignment: .top)` with custom ZStack positioning |

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

**DESIGN BAR: PASS**

The implementation is clean, consistent with the design system, and feels native to iOS:

1. **Floating glass menu** is a significant improvement over bottom action sheet - provides spatial context (menu appears where you tapped) and visual polish (spring animation, material background)

2. **Independent button visibility** works correctly - FAB and filter button hide only when their respective menus are open

3. **Design system compliance**:
   - Uses DS.Spacing, DS.Colors, DS.Typography, DS.Icons, DS.Shadows consistently
   - `.ultraThinMaterial` is correct fallback (glassBackgroundEffect is visionOS-only)
   - `.interpolatingSpring(duration: 0.35, bounce: 0.3)` provides native spring feel

4. **Touch targets**: Menu buttons have adequate vertical padding (~44pt+ per row)

5. **Accessibility**: Dynamic Type support via @ScaledMetric, VoiceOver labels on filter button

**Minor observations (not blocking)**:
- DispatchQueue.main.asyncAfter for action delay is common pattern but could use animation completion in future
- sensoryFeedback trigger on item.id could be refined (triggers on UUID changes during redraws)

Would Apple ship this? Yes.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
