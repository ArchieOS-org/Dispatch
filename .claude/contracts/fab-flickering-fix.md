## Interface Lock

**Feature**: FAB and Filter Button Flickering Fix
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

### Problem Analysis

The current architecture has THREE critical flaws causing flickering:

1. **Duplicate Button Rendering**: `GlobalFloatingButtons.swift` (iPhone) and `iPadContentView.swift` (iPad) both render:
   - SwiftUI visual buttons (`fabVisual` Circle, `FloatingFilterButton`) in `floatingButtonsContent` / `iPadFABOverlay`
   - UIKit buttons (`FABMenuButton`/`FilterMenuButton` via `UIViewRepresentable`) in `FABMenuOverlay`/`FilterMenuOverlay`
   - BOTH are positioned at the SAME screen location via identical padding values

2. **Animation Timing Conflict**: Two animation systems fighting:
   - SwiftUI: `.animation(.easeInOut(duration: 0.2), value: shouldHideFAB)` (lines 122-123, 134-135)
   - UIKit: `UIView.animate(withDuration: 0.35, usingSpringWithDamping: 0.78, ...)` (lines 108-116 in FABMenuOverlay)

3. **Glass Effect Instability**: When `UIViewRepresentable` recreates on SwiftUI state changes, the `CABackdropLayer` for `.glassEffect()` resets, causing visible flicker

### Solution

Migrate to **pure SwiftUI Menu approach**:
- Use SwiftUI `Menu` view with `menuStyle(.button)` for system-native presentation
- Single button visual per button (no duplicate rendering)
- Unified animation timing (SwiftUI only, no UIKit conflicts)
- Stable glass effect (applied to non-recreating SwiftUI view)
- macOS support via same code path (already exists in FABMenuOverlay for `#else`)

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None (reusing existing `showFABMenu`/`showFilterMenu` state)
- Migration required: N

### Files to Modify

| File | Action | Reason |
|------|--------|--------|
| `Dispatch/SharedUI/Components/FABMenuOverlay.swift` | DELETE | UIViewRepresentable causing flicker |
| `Dispatch/SharedUI/Components/FilterMenuOverlay.swift` | DELETE | UIViewRepresentable causing flicker |
| `Dispatch/SharedUI/Components/GlobalFloatingButtons.swift` | REFACTOR | Use SwiftUI Menu inline, single button visual |
| `Dispatch/App/Platform/iPadContentView.swift` | REFACTOR | Same pattern - pure SwiftUI Menu approach |

**Note**: FloatingFilterButton.swift and FloatingActionButton.swift were NOT modified. Instead, Menu logic was integrated directly into GlobalFloatingButtons.swift and iPadContentView.swift to avoid adding optional parameters to reusable components. FABMenuItem struct was moved to GlobalFloatingButtons.swift.

### Acceptance Criteria (3 max)

1. Zero visible flicker when tapping FAB or filter buttons to open menus
2. Single button visual per button at runtime (verify via View Hierarchy debugger)
3. Builds on iOS + macOS with identical behavior

### Non-goals (prevents scope creep)

- No changes to menu item content or actions
- No changes to FABContext logic or routing
- No new animations beyond system Menu defaults
- No iPad-specific layout changes beyond removing duplicates

### Compatibility Plan

- **Backward compatibility**: N/A (internal UI only)
- **Default when missing**: N/A
- **Rollback strategy**: Revert to previous commit if validation fails

### Technical Approach

**Phase 1: Create Menu-integrated button variants**

```swift
// In FloatingActionButton.swift - add menu variant
struct FloatingActionButton: View {
  // Existing properties...

  /// For multi-option contexts: items to show in menu
  var menuItems: [FABMenuItem]?

  var body: some View {
    if let items = menuItems, !items.isEmpty {
      Menu {
        ForEach(items) { item in
          Button {
            item.action()
          } label: {
            Label(item.title, systemImage: item.icon)
          }
        }
      } label: {
        fabCircle
      }
      .menuStyle(.button)
    } else {
      // Existing single-action button
      Button { ... } label: { fabCircle }
    }
  }
}
```

**Phase 2: Simplify GlobalFloatingButtons**

```swift
// Remove overlay imports and ZStack layering
// Replace fabVisual + FABMenuOverlay with single FloatingActionButton(menuItems:)
@ViewBuilder
private var fabButton: some View {
  switch fabContext {
  case .listingList:
    FloatingActionButton { appState.sheetState = .addListing() }
  case .workspace, .listingDetail, .realtor:
    FloatingActionButton(menuItems: fabMenuItems) { }
  // ...
  }
}
```

**Phase 3: Apply same pattern to iPadContentView**

Remove separate `FABMenuOverlay` and `FilterMenuOverlay` components. Integrate Menu directly into button views.

---

### Ownership

- **feature-owner**: End-to-end implementation of pure SwiftUI Menu approach across iPhone and iPad
- **data-integrity**: Not needed

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: Menu view with custom label Button label and presenting options using system context menu style
CONTEXT7_TAKEAWAYS:
- SwiftUI Menu accepts a custom `label:` view builder for the trigger button
- Menu items use Button with Label for icons and titles
- Menu handles its own presentation/dismissal automatically
- System styling is applied by default
CONTEXT7_APPLIED:
- Menu with custom label -> GlobalFloatingButtons.swift:fabMenu, iPadContentView.swift:iPadFABMenu

CONTEXT7_QUERY: Menu primaryAction parameter tap action versus menu presentation
CONTEXT7_TAKEAWAYS:
- Menu supports `primaryAction:` parameter for tap behavior
- Primary action fires on tap; menu opens on long-press or secondary gesture
- Perfect for filter button: tap cycles, long-press opens menu
- Available iOS 15.0+
CONTEXT7_APPLIED:
- primaryAction for filter button -> GlobalFloatingButtons.swift:filterButton, iPadContentView.swift:iPadFilterButton

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (/websites/developer_apple_swiftui)

| Query | Pattern Used |
|-------|--------------|
| Menu view with custom label | Menu { items } label: { fabVisual } for FAB buttons |
| Menu primaryAction parameter | Menu { items } label: { ... } primaryAction: { cycle } for filter buttons |

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

**Architecture**: The refactor eliminates the dual-layer problem entirely. Previous implementation had SwiftUI visuals overlapping UIKit UIViewRepresentable buttons at identical screen positions. The new pure SwiftUI Menu approach renders a single button per control.

**Code Quality**:
- Menu with `primaryAction:` parameter correctly implements tap-to-cycle, long-press-for-menu pattern (lines 104-122 in GlobalFloatingButtons.swift)
- Context-aware FAB uses direct `FloatingActionButton` for single-action contexts (listing list, properties) and SwiftUI Menu for multi-option contexts (workspace, listing detail, realtor)
- Unified animation timing: single `.easeInOut(duration: 0.2)` - no UIKit/SwiftUI conflict
- Design system tokens used consistently: DS.Spacing, DS.Shadows, DS.Colors

**Touch Targets**: 56pt total frame (floatingButtonSizeLarge), 44pt visual circle for filter button - exceeds HIG minimum of 44pt

**Accessibility**: Present and correct - accessibilityLabel, accessibilityHint, accessibilityIdentifier on both buttons. @ScaledMetric used for Dynamic Type support on icon sizes.

**Native Feel**: SwiftUI Menu provides system-native menu presentation with proper animations, haptics, and dismiss behavior. No custom overlay management required.

**Consistency**: iPhone (GlobalFloatingButtons.swift) and iPad (iPadContentView.swift) implementations are structurally identical - same patterns, same visual treatment.

This is how Apple would implement floating action buttons with contextual menus. Ship it.

---

### Implementation Notes

**Context7 Recommended For:**
- SwiftUI `Menu` view with custom button style
- iOS 26 `.glassEffect()` modifier behavior and lifecycle
- System menu animations and presentation

**Risk Mitigation:**
- FABMenuItem struct already exists and can be reused
- macOS code path in FABMenuOverlay already uses SwiftUI Menu (lines 189-213)
- No state management changes needed

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
