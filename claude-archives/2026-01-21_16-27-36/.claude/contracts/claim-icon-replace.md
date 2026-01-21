## Interface Lock

**Feature**: Replace Unassigned UI with Claim Icon System
**Created**: 2026-01-18
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [x] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [x] **Unfamiliar area** (adds dispatch-explorer) - Already explored

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
- State/actions added: None (claim action already exists)
- Migration required: N

### Files to Modify

1. `Dispatch/SharedUI/Components/UnassignedBadge.swift` - Replace with ClaimButton component
2. `Dispatch/SharedUI/Components/OverlappingAvatars.swift` - Use ClaimButton instead of UnassignedBadge
3. `Dispatch/Features/WorkItems/Utilities/ClaimFilter.swift` - Update displayName
4. `Dispatch/Features/WorkItems/Views/Components/WorkItem/WorkItemRow.swift` - Accessibility label
5. `Dispatch/Features/WorkItems/Views/Containers/WorkItemListContainer.swift` - Empty state copy
6. `Dispatch/Features/Search/Views/Components/SearchResult.swift` - Subtitle text
7. `Dispatch/Features/Workspace/Views/Screens/MyWorkspaceView.swift` - Section header
8. `Packages/DesignSystem/Sources/DesignSystem/Tokens/DSIcon.swift` - Add Claim icons
9. `DispatchTests/UtilityTests.swift` - Update test expectations

### Acceptance Criteria (3 max)

1. No "unassigned" text appears anywhere in the app UI (verified via grep)
2. ClaimButton responds to tap (claim) and long-press/right-click (assignment menu) on both iOS and macOS
3. VoiceOver announces "Available to claim. Tap to claim, hold for options" for unclaimed items

### Non-goals (prevents scope creep)

- No changes to the actual claim/assignment logic or API calls
- No new animations beyond icon state transitions
- No changes to filter behavior (only display names)

### Compatibility Plan

- **Backward compatibility**: N/A (UI-only change)
- **Default when missing**: N/A
- **Rollback strategy**: Revert commit, "Unassigned" text restoration

---

### Design Specification

#### Claim Icon States

Using design system tokens (already documented but not yet implemented in DSIcon.swift):

| State | Icon | Color | Usage |
|-------|------|-------|-------|
| Unclaimed | `person.badge.plus` | `DS.Colors.Claim.unclaimed` (Gray) | Available to claim |
| Claimed by me | `person.fill.checkmark` | `DS.Colors.Claim.claimedByMe` (Green) | Current user owns |
| Claimed by other | `person.fill` | `DS.Colors.Claim.claimedByOther` (Orange) | Someone else owns |
| Release | `person.badge.minus` | (contextual) | Menu action |

#### Interaction Patterns

| Platform | Quick Claim | Assignment Menu |
|----------|-------------|-----------------|
| iOS | Tap | Long-press (0.4s per `DS.Spacing.longPressDuration`) |
| macOS | Click | Right-click (contextMenu) |

#### Accessibility

- VoiceOver label: "Available to claim. Tap to claim, hold for options"
- Trait: `.button`
- Minimum touch target: 44pt (per `DS.Spacing.minTouchTarget`)

#### Text Replacements

| Location | Before | After |
|----------|--------|-------|
| ClaimFilter displayName | "Unassigned" | "Available" |
| Empty state copy | "No unassigned items" | "No available items" |
| Search subtitle | "Unassigned" | "Available" |
| Section headers | "Unassigned" | "Available" |

---

### Ownership

- **feature-owner**: End-to-end implementation of ClaimButton, icon tokens, text replacements, accessibility
- **data-integrity**: Not needed

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: LongPressGesture and contextMenu modifier for right-click tap and hold gesture handling cross-platform iOS macOS
CONTEXT7_TAKEAWAYS:
- contextMenu modifier handles both touch-and-hold (iOS) and right-click (macOS) automatically
- LongPressGesture requires explicit @GestureState for state tracking
- onLongPressGesture(minimumDuration:perform:) is simpler for basic long-press detection
- contextMenu is the idiomatic cross-platform solution for secondary actions
CONTEXT7_APPLIED:
- contextMenu modifier -> ClaimButton.swift (line ~60)

CONTEXT7_QUERY: combining multiple gestures TapGesture simultaneously sequenced gesture composition
CONTEXT7_TAKEAWAYS:
- simultaneously(with:) combines gestures to recognize both at once
- sequenced(before:) chains gestures so second only fires after first succeeds
- exclusively(before:) ensures only one gesture succeeds with priority to first
- For tap + context menu, use Button with contextMenu (no gesture composition needed)
CONTEXT7_APPLIED:
- Button with contextMenu (no complex gesture composition needed) -> ClaimButton.swift

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (/websites/developer_apple_swiftui)

| Query | Pattern Used |
|-------|--------------|
| LongPressGesture contextMenu cross-platform | contextMenu modifier for automatic iOS long-press / macOS right-click |
| Gesture composition patterns | Button + contextMenu (avoided complex gesture composition) |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-18 14:30

#### Checklist

- [x] Ruthless simplicity - Icon-only replaces verbose "Unassigned" pill badge. 16pt icon vs ~80pt wide text label.
- [x] One clear primary action per screen/state - Tap claims. Long-press/right-click for secondary actions.
- [x] Strong hierarchy - Icon integrates at avatar position without competing with task title.
- [x] No clutter - person.badge.plus is minimal. Color coding provides state without labels.
- [x] Native feel - contextMenu handles iOS long-press and macOS right-click automatically. 44pt touch target.

#### Verdict Notes

**Design System Compliance:**
- Uses DS.Colors.Claim.*, DS.Icons.Claim.*, DS.Spacing.minTouchTarget (44pt)
- OverlappingAvatars properly shows ClaimButton when userIds.isEmpty
- UnassignedBadge correctly marked deprecated with migration message

**Accessibility:**
- accessibilityLabel: "Available to claim" / "Claimed by you" / "Claimed by [name]"
- accessibilityHint: "Tap to claim, hold for options"
- .isButton trait added

**States Handled:**
- available (gray person.badge.plus)
- claimedBySelf (green person.fill.checkmark)
- claimedByOther (orange person.fill)
- Context menu adapts per state with appropriate actions

**Minor observations (non-blocking):**
- Unused @State isPressed property can be cleaned up later
- Internal enum rawValue "Unassigned" is fine; user-facing displayName returns "Available"

---

### Implementation Notes

**Context7 recommended for:**
- SwiftUI long-press gesture patterns (LongPressGesture vs onLongPressGesture)
- macOS contextMenu patterns for right-click behavior
- VoiceOver accessibilityLabel best practices
- Cross-platform gesture handling (iOS vs macOS)

---

**IMPORTANT**:
- If `UI Review Required: YES` → integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` → Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO → integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` → integrator MUST reject DONE
