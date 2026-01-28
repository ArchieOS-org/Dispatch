## Interface Lock

**Feature**: DIS-77 FAB Add Menu with Listing/Task/Activity Options
**Created**: 2026-01-22
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES (customer-facing UI, new interaction pattern, animation)

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [x] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [x] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [ ] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |
| 2.5 | Design bar | jobs-critic, ui-polish |
| 3 | Validation | xcode-pilot |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added:
  - New `FABMenuState` enum or similar for tracking menu open/closed state
  - Possible extension to `AppState.SheetState` if needed (likely reuses existing `.quickEntry`, `.addListing`)
- Migration required: N

### Acceptance Criteria (3 max)

1. **FAB menu appears on tap**: When FAB is pressed, menu springs out with three options (Listing, Task, Activity) and FAB button hides
2. **Each option opens correct sheet**: Tapping "Listing" opens AddListingSheet, "Task" opens QuickEntrySheet(type: .task), "Activity" opens QuickEntrySheet(type: .activity)
3. **Works on iPhone and iPad**: Menu behavior consistent across both platforms using appropriate existing FAB locations

### Non-goals (prevents scope creep)

- No changes to the actual sheet content (AddListingSheet, QuickEntrySheet)
- No new data models or schema changes
- No macOS support (FAB is iOS/iPadOS only)
- No changes to existing filter button behavior
- No persistence of menu state

### Compatibility Plan

- **Backward compatibility**: N/A - no API/DTO changes
- **Default when missing**: N/A
- **Rollback strategy**: Revert to single FAB that opens quickEntry(type: nil)

---

### Implementation Notes

#### Existing Code Locations

| Component | File | Notes |
|-----------|------|-------|
| FloatingActionButton | `Dispatch/Design/Shared/Components/FloatingActionButton.swift` | Base FAB component |
| GlobalFloatingButtons | `Dispatch/SharedUI/Components/GlobalFloatingButtons.swift` | iPhone FAB container |
| iPadContentView | `Dispatch/App/Platform/iPadContentView.swift` | iPad FAB overlay (line 64-70) |
| iPhoneContentView | `Dispatch/App/Platform/iPhoneContentView.swift` | iPhone sheet handling |
| AppState.SheetState | `Dispatch/App/State/AppState.swift` | Sheet state management |
| QuickEntrySheet | `Dispatch/Features/WorkItems/Views/Sheets/QuickEntrySheet.swift` | Task/Activity creation |
| AddListingSheet | `Dispatch/Features/Listings/Views/Sheets/AddListingSheet.swift` | Listing creation |

#### Design System Usage

- Use `DS.Spacing.floatingButtonSizeLarge` (56pt) for menu items
- Use `DS.Colors.accent` for primary action
- Use `DS.Shadows.elevated` for menu shadow
- Use `DS.Icons.Entity.listing`, `DS.Icons.Entity.task`, `DS.Icons.Entity.activity` for menu icons
- Follow GlassButton patterns for glass effect if desired

#### Animation Guidance

- Spring animation for menu appearance (recommended: `.spring(response: 0.35, dampingFraction: 0.7)`)
- FAB should scale down/fade while menu items scale up/fade in
- Staggered animation for menu items (slight delay between each)
- Dismiss on tap outside or tap on menu item

#### Context7 Recommendations

Agents should query Context7 for:
- SwiftUI animation patterns (spring animations, matched geometry)
- SwiftUI gesture handling (tap outside to dismiss)
- iOS HIG for contextual menus and FAB patterns

---

### Ownership

- **feature-owner**: Implement FABMenu component, integrate into GlobalFloatingButtons and iPadContentView, connect to sheet state
- **data-integrity**: Not needed

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: spring animation parameters staggered delay transition animation modifier
CONTEXT7_TAKEAWAYS:
- Use `.spring(response: 0.5, dampingFraction: 0.825)` for smooth spring animations
- Use `.delay(_:)` modifier to create staggered animations between elements
- Spring animations preserve velocity across chained animations
- `.interpolatingSpring(duration:bounce:)` provides alternative spring control
CONTEXT7_APPLIED:
- Spring animation pattern -> FABMenu.swift (menu item animations)

CONTEXT7_QUERY: tap outside dismiss overlay gesture background fullScreenCover contentShape
CONTEXT7_TAKEAWAYS:
- Use `.contentShape(Rectangle())` to make entire view area tappable for hit testing
- Use `.onTapGesture` on the background to dismiss overlays
- ZStack with transparent background allows tap-outside-to-dismiss pattern
CONTEXT7_APPLIED:
- contentShape for tap-outside-dismiss -> FABMenu.swift (scrim layer)

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (/websites/developer_apple_swiftui)

| Query | Pattern Used |
|-------|--------------|
| spring animation parameters staggered delay transition | `.spring(response:dampingFraction:)` with `.delay(_:)` for staggered menu items |
| tap outside dismiss overlay gesture contentShape | `.contentShape(Rectangle())` + `.onTapGesture` on scrim layer |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-22

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes

Clean, focused implementation of an expanding FAB menu pattern.

**Strengths:**
- Three options only (Listing, Task, Activity) - minimal and complete
- Spring animations (response: 0.35, dampingFraction: 0.7) feel iOS-native
- Staggered reveal (0.05s delay per item) adds polish without excess
- FAB rotation to X is established iOS affordance for "close"
- Uses DS tokens throughout - no hardcoded values
- Touch targets are 44pt minimum (Apple HIG compliant)
- Dynamic Type support via @ScaledMetric
- VoiceOver labels on all interactive elements
- Haptic feedback on interactions
- Asymmetric transitions (scale 0.5 insert, 0.8 remove) feel natural
- Smart delay before sheet presentation lets animation complete

**Platform consistency:**
- Same FABMenu component used on both iPhone (GlobalFloatingButtons) and iPad (iPadContentView overlay)

**Would Apple ship this?** Yes. Standard pattern, clean execution.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
