## Interface Lock

**Feature**: ClaimButton Simplification and Preview Enhancement
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
- State/actions added: ClaimState enum removed (simplified to stateless button)
- Migration required: N

### Background

The previous implementation (`claim-icon-replace.md`) created ClaimButton with three states:
- `.available` - shows claim icon (person.badge.plus)
- `.claimedBySelf` - shows claimed icon
- `.claimedByOther(name:)` - shows claimed by other icon

**User feedback**: "claimed by self and claimed by other shouldn't exist. we have user icons for that"

**Analysis of OverlappingAvatars.swift (line 42-44)**:
```swift
if userIds.isEmpty {
  ClaimButton(state: .available, onClaim: onClaim, onAssign: onAssign)
} else {
  avatarStack  // Shows user avatars
}
```

This confirms ClaimButton is ONLY shown when no users are assigned. The claimed states are dead code because:
- Claimed by self -> user's avatar shows (not ClaimButton)
- Claimed by other -> their avatar shows (not ClaimButton)

### Files to Modify

1. `Dispatch/SharedUI/Components/ClaimButton.swift`
   - Remove ClaimState enum entirely
   - Simplify ClaimButton to handle only the unclaimed case
   - Build comprehensive preview showing button in realistic contexts

### Acceptance Criteria (3 max)

1. ClaimState enum is removed - ClaimButton becomes stateless (only handles unclaimed case)
2. ClaimButton compiles and works with existing OverlappingAvatars integration (no changes needed to OverlappingAvatars)
3. Preview shows ClaimButton in multiple realistic contexts: standalone, in row context, light/dark mode, different sizes

### Non-goals (prevents scope creep)

- No changes to OverlappingAvatars.swift (it already correctly shows ClaimButton only when empty)
- No changes to claim/assignment logic or API calls
- No changes to design system tokens (DS.Icons.Claim, DS.Colors.Claim remain for potential future use)
- No removal of claimed-related design tokens (may be used elsewhere or in future)

### Compatibility Plan

- **Backward compatibility**: N/A - internal simplification only
- **Default when missing**: N/A
- **Rollback strategy**: Revert commit, restore ClaimState enum

---

### Design Specification

#### Simplified ClaimButton

| Property | Value | Notes |
|----------|-------|-------|
| Icon | `person.badge.plus` | `DS.Icons.Claim.unclaimed` |
| Color | Gray | `DS.Colors.Claim.unclaimed` |
| Size | 16pt font, 44pt touch target | Per `DS.Spacing.minTouchTarget` |

#### Interaction Patterns (unchanged)

| Platform | Quick Claim | Assignment Menu |
|----------|-------------|-----------------|
| iOS | Tap | Long-press (contextMenu) |
| macOS | Click | Right-click (contextMenu) |

#### Context Menu Options

- "Claim for Myself" with `person.fill.checkmark` icon
- "Assign to..." with `person.2` icon

#### Accessibility (simplified)

| Property | Value |
|----------|-------|
| Label | "Available to claim" |
| Hint | "Tap to claim, hold for options" |
| Traits | `.button` |

#### Preview Requirements

The preview should demonstrate:
1. **Standalone button** - ClaimButton alone with label
2. **In row context** - Simulating WorkItemRow layout (title + Spacer + ClaimButton)
3. **Different backgrounds** - Card background, plain background
4. **Light and dark mode** - Both color schemes
5. **Tap state feedback** - Button press behavior

---

### Ownership

- **feature-owner**: Remove ClaimState enum, simplify ClaimButton, build comprehensive preview
- **data-integrity**: Not needed

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: contextMenu modifier button SwiftUI how to add context menu to button
CONTEXT7_TAKEAWAYS:
- Use `.contextMenu { }` modifier to add context menus to any view
- Buttons in contextMenu automatically adapt their appearance
- Use `Label` for buttons with both text and system image icons
- Context menu triggers on long-press (iOS) or right-click (macOS)
CONTEXT7_APPLIED:
- Label pattern for context menu -> ClaimButton.swift contextMenuContent

CONTEXT7_QUERY: accessibility label hint button SwiftUI accessibilityLabel accessibilityHint
CONTEXT7_TAKEAWAYS:
- Use `.accessibilityLabel(Text("..."))` for views without visible text
- Keep labels concise - don't repeat "button" since it's already a trait
- Use `.accessibilityHint("...")` to describe what happens after action
- Hint should be brief phrase like "Purchases the item"
CONTEXT7_APPLIED:
- accessibilityLabel/Hint patterns -> ClaimButton.swift accessibility modifiers

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI

| Query | Pattern Used |
|-------|--------------|
| contextMenu modifier button SwiftUI | Label with systemImage in contextMenu buttons |
| accessibility label hint button SwiftUI | accessibilityLabel(Text()) and accessibilityHint(Text()) |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-18 14:30

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes

The ClaimButton redesign is an exemplary simplification:

1. **Ruthless simplicity achieved**: Removed entire ClaimState enum. Button went from 3 states to stateless. The insight that "claimed states are dead code because avatars show instead" is correct design thinking - why build UI for states that are never rendered?

2. **Clean interaction model**: Tap = claim (primary), long-press/right-click = contextMenu (secondary). No competing visual affordances.

3. **Design system compliance**: Uses DS tokens throughout - DS.Icons.Claim.unclaimed, DS.Colors.Claim.unclaimed, DS.Spacing.minTouchTarget (44pt). Preview demonstrates integration with DS.Typography and DS.Spacing constants.

4. **Accessibility complete**: Label, hint, and button trait. Hint appropriately describes dual interaction ("Tap to claim, hold for options").

5. **Preview is documentation**: Shows standalone, row context, and multiple rows - exactly what a future developer needs to understand usage patterns.

Would Apple ship this? Yes. It does one thing well.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
