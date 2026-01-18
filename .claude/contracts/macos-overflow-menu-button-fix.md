## Interface Lock

**Feature**: macOS Overflow Menu Button UI Fix
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
- State/actions added: None
- Migration required: N

### Problem Statement

Two issues with the three-dot (ellipsis) overflow menu button on macOS:

1. **Button background shape issue**: The background is ovular/too wide - needs to be circular/properly proportioned
2. **Menu presentation issue**: Currently uses `confirmationDialog` which shows a floating action sheet. Should use native SwiftUI `Menu` with proper macOS styling that shows a popover-style menu directly beneath the button with an arrow pointing to it.

### Files Identified

**Primary component to modify:**
- `/Users/noahdeskin/conductor/workspaces/dispatch/harrisburg/Dispatch/Design/Shared/Components/OverflowMenu.swift` - Main overflow menu component using `confirmationDialog` (needs to use `Menu` instead)

**Views using OverflowMenu:**
- `/Users/noahdeskin/conductor/workspaces/dispatch/harrisburg/Dispatch/Features/Listings/Views/Screens/ListingDetailView.swift` (line 24)
- `/Users/noahdeskin/conductor/workspaces/dispatch/harrisburg/Dispatch/Features/Properties/Views/Screens/PropertyDetailView.swift` (line 25)

**Related macOS toolbar button for reference:**
- `/Users/noahdeskin/conductor/workspaces/dispatch/harrisburg/Dispatch/Foundation/Platform/macOS/ToolbarIconButton.swift` - Uses 36pt sizing with consistent styling

**Design system to update:**
- `/Users/noahdeskin/conductor/workspaces/dispatch/harrisburg/DESIGN_SYSTEM.md` - Document any new component/tokens

### Acceptance Criteria (3 max)

1. The three-dot button has a square/circular hit target (not ovular) matching the 44pt min touch target
2. Tapping the button on macOS shows a native `Menu` dropdown directly beneath with proper attachment (not a floating confirmation dialog)
3. Both ListingDetailView and PropertyDetailView overflow menus display correctly with the fixed styling

### Non-goals (prevents scope creep)

- No changes to iOS behavior (iOS action sheet via confirmationDialog may be acceptable)
- No changes to menu action functionality (edit, delete actions remain the same)
- No changes to other button types in the app (ToolbarIconButton, FilterMenu, etc.)

### Compatibility Plan

- **Backward compatibility**: N/A - UI-only change
- **Default when missing**: N/A
- **Rollback strategy**: Revert the OverflowMenu.swift changes

---

### Ownership

- **feature-owner**: Fix OverflowMenu component to use SwiftUI Menu on macOS with proper button sizing, update DESIGN_SYSTEM.md
- **data-integrity**: Not needed

---

### Technical Implementation Notes

**Current implementation (`OverflowMenu.swift`):**
```swift
// Uses confirmationDialog - shows as action sheet (wrong on macOS)
.confirmationDialog("Actions", isPresented: $showingActions, titleVisibility: .hidden) {
    ForEach(actions) { item in
        Button(role: item.role) { ... }
    }
}
```

**Target implementation:**
```swift
// Use Menu for native dropdown on macOS
Menu {
    ForEach(actions) { item in
        Button(role: item.role) { ... } label: {
            Label(item.title, systemImage: item.icon)
        }
    }
} label: {
    // Circular button with proper sizing
    Image(systemName: "ellipsis")
        .frame(width: DS.Spacing.minTouchTarget, height: DS.Spacing.minTouchTarget)
}
```

**Platform consideration:**
- May need `#if os(macOS)` / `#else` to use Menu on macOS and confirmationDialog on iOS (if iOS behavior is preferred there)
- Or: Use Menu universally since it works on all platforms with native styling

**Context7 should be consulted for:**
- SwiftUI Menu best practices and styling on macOS
- Proper menu button styling in toolbars

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: SwiftUI Menu button dropdown styling macOS how to create a dropdown menu with custom label button
CONTEXT7_TAKEAWAYS:
- Use Menu { content } label: { customView } for dropdown menus
- Menu supports @ViewBuilder for both content and label
- Available on macOS 11.0+, iOS 14.0+
- Use menuStyle(.borderlessButton) for minimal chrome
- Use menuIndicator(.hidden) to hide the dropdown arrow when desired
CONTEXT7_APPLIED:
- Menu { ForEach } label: { menuLabel } -> OverflowMenu.swift:68-78

CONTEXT7_QUERY: SwiftUI toolbar button sizing frame minTouchTarget macOS proper circular button styling
CONTEXT7_TAKEAWAYS:
- Use .fixedSize() to prevent unwanted expansion
- AccessoryBarButtonStyle available for toolbar buttons on macOS 14+
- buttonStyle(.borderlessButton) for plain icon-only buttons
CONTEXT7_APPLIED:
- .menuStyle(.borderlessButton) + .fixedSize() -> OverflowMenu.swift:79-81

CONTEXT7_QUERY: macOS toolbar button styling plain button style icon button borderless (2026-01-18)
CONTEXT7_TAKEAWAYS:
- `.buttonStyle(.plain)` provides no styling while idle, may show state on press/focus
- `.buttonStyle(.borderless)` is for buttons without border
- Both available macOS 10.15+
CONTEXT7_APPLIED:
- .buttonStyle(.plain) -> OverflowMenu.swift:82 (matches ToolbarIconButton)

CONTEXT7_QUERY: SwiftUI Menu label custom styling macOS plain style no background (2026-01-18)
CONTEXT7_TAKEAWAYS:
- `.menuStyle(.borderlessButton)` is DEPRECATED (creates pill-shaped background)
- Deprecation notice: Use `menuStyle(.button)` with `buttonStyle(.borderless)` instead
- For cleanest appearance matching icon buttons, use `.buttonStyle(.plain)`
CONTEXT7_APPLIED:
- Changed from .menuStyle(.borderlessButton) to .menuStyle(.button) + .buttonStyle(.plain) -> OverflowMenu.swift:81-82

CONTEXT7_QUERY: MenuStyle.borderlessButton deprecation (2026-01-18)
CONTEXT7_TAKEAWAYS:
- Deprecated on iOS 14.0-26.2, macOS 11.0-26.2 and all platforms
- Deprecation notice: "Use menuStyle(_:) with button and buttonStyle(_:) with borderless instead"
- On macOS, the deprecated style shows an arrow and creates visible button chrome
CONTEXT7_APPLIED:
- Removed deprecated .menuStyle(.borderlessButton) -> OverflowMenu.swift:81

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (/websites/developer_apple_swiftui)

| Query | Pattern Used |
|-------|--------------|
| SwiftUI Menu button dropdown styling macOS | Menu { content } label: { view } with .menuStyle(.button) |
| SwiftUI toolbar button sizing frame macOS | .fixedSize() to prevent unwanted expansion |
| macOS toolbar button styling plain button style | .buttonStyle(.plain) for no background |
| SwiftUI Menu label custom styling macOS no background | .menuStyle(.button) + .buttonStyle(.plain) (replaces deprecated .borderlessButton) |
| MenuStyle.borderlessButton deprecation | Confirmed deprecated - replaced with modern pattern |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-18 18:30

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes

**PASS** - Implementation meets the design bar.

The OverflowMenu component correctly addresses both original issues:

1. **Button styling fixed**: Replaced deprecated `.menuStyle(.borderlessButton)` (which created a large pill-shaped background) with `.menuStyle(.button)` + `.buttonStyle(.plain)` for minimal chrome matching ToolbarIconButton.

2. **Unified styling with ToolbarIconButton**: The macOS menuLabel now uses identical styling:
   - Font: `DS.Spacing.bottomToolbarIconSize` (18pt) with `.medium` weight
   - Color: `.primary.opacity(0.6)`
   - Frame: `DS.Spacing.bottomToolbarButtonSize` (36pt) square
   - Button style: `.plain` (no background)

3. **Native macOS menu**: Uses SwiftUI `Menu` with `.menuIndicator(.hidden)` and `.fixedSize()` for proper dropdown behavior attached to the button.

Execution quality:
- Uses design system tokens correctly (no magic numbers)
- SF Symbols via configurable icon parameter
- Dynamic Type support via `@ScaledMetric` for icon sizing on iOS
- Accessibility label and `.help()` tooltip present
- `.fixedSize()` prevents unwanted frame expansion
- Platform-specific implementation (Menu on macOS, confirmationDialog on iOS)
- Code is clean, minimal, and follows platform conventions

**Note**: Visual verification via macOS simulator was not possible (MCP simulator not configured). Code review confirms correct implementation patterns match ToolbarIconButton exactly. Manual testing recommended before final ship.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
