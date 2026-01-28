## Interface Lock

**Feature**: DIS-73 Settings Screen Wrapper for Overlay Hiding
**Created**: 2026-01-21
**Status**: locked
**Lock Version**: v1
**UI Review Required**: NO

---

### Problem Statement

The previous implementation added `.onAppear/.onDisappear` to each individual settings screen to hide/show floating buttons. This caused:

1. **Race conditions**: `onDisappear` fires before `onAppear` of the next screen during navigation
2. **NavigationAuthority warnings**: "Update NavigationAuthority bound path tried to update multiple times per frame"
3. **Inconsistent button visibility**: Buttons would flash or appear at wrong times

### Proposed Solution

Create a `SettingsScreen` wrapper (similar to `StandardScreen`) that:
- Wraps all settings sub-screens uniformly
- Manages overlay visibility at the **wrapper level**, not individual screen level
- Uses a pattern that survives navigation transitions

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
| 2.5 | Design bar | jobs-critic (skipped - UI Review: NO) |
| 3 | Validation | xcode-pilot |

**Note**: UI Review Required: NO because this is a behavioral fix with no visual changes. Jobs-critic is skipped.

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None (uses existing `AppOverlayState.settingsScreen` reason)
- Migration required: N

### Acceptance Criteria (3 max)

1. Floating buttons are hidden on ALL settings sub-screens (SettingsView, ProfilePageView, ListingTypeListView, ListingTypeDetailView)
2. No "NavigationAuthority bound path" warnings in console during settings navigation
3. Buttons reappear cleanly when navigating OUT of settings (back to main app)

### Non-goals (prevents scope creep)

- No changes to the button appearance or animation
- No new overlay hiding reasons
- No changes to non-settings screens

### Compatibility Plan

- **Backward compatibility**: N/A (internal refactor)
- **Default when missing**: N/A
- **Rollback strategy**: Revert to individual onAppear/onDisappear (known-broken fallback)

---

### Exploration Requirements

**dispatch-explorer MUST investigate these areas BEFORE feature-owner begins:**

#### 1. StandardScreen Pattern Analysis
- File: `/Users/noahdeskin/conductor/workspaces/dispatch/dar-es-salaam/Dispatch/App/Shell/StandardScreen.swift`
- Questions:
  - How does StandardScreen manage environment values?
  - How does it compose with child content?
  - Can SettingsScreen wrap StandardScreen, or should it be a separate wrapper?

#### 2. AppOverlayState and Visibility Mechanism
- File: `/Users/noahdeskin/conductor/workspaces/dispatch/dar-es-salaam/Dispatch/App/State/AppOverlayState.swift`
- File: `/Users/noahdeskin/conductor/workspaces/dispatch/dar-es-salaam/Dispatch/SharedUI/Components/GlobalFloatingButtons.swift`
- Questions:
  - How does the reference-counting work (hide/show reasons)?
  - Where is `isOverlayHidden` consumed?
  - Is `.settingsScreen` reason already defined and suitable?

#### 3. Navigation Timing and Lifecycle
- File: `/Users/noahdeskin/conductor/workspaces/dispatch/dar-es-salaam/Dispatch/App/State/AppDestinations.swift`
- Questions:
  - What is the exact timing of `onAppear`/`onDisappear` during `NavigationStack` push/pop?
  - Why does the race condition occur?
  - What SwiftUI patterns avoid this (e.g., `task`, `onChange(of: path)`, preference keys)?

#### 4. Existing Settings Screens
- Files:
  - `/Users/noahdeskin/conductor/workspaces/dispatch/dar-es-salaam/Dispatch/Features/Settings/Views/SettingsView.swift`
  - `/Users/noahdeskin/conductor/workspaces/dispatch/dar-es-salaam/Dispatch/Features/Settings/Views/ProfilePageView.swift`
  - `/Users/noahdeskin/conductor/workspaces/dispatch/dar-es-salaam/Dispatch/Features/Settings/Views/ListingTypeListView.swift`
  - `/Users/noahdeskin/conductor/workspaces/dispatch/dar-es-salaam/Dispatch/Features/Settings/Views/ListingTypeDetailView.swift`
- Questions:
  - How are these screens structured?
  - What parameters do they accept?
  - Can they be uniformly wrapped?

---

### Implementation Approach (for feature-owner after exploration)

**Recommended pattern**: Create `SettingsScreen` as a thin wrapper that:

```swift
struct SettingsScreen<Content: View>: View {
  @EnvironmentObject private var overlayState: AppOverlayState
  let content: () -> Content

  var body: some View {
    content()
      .onAppear { overlayState.hide(reason: .settingsScreen) }
      .onDisappear { overlayState.show(reason: .settingsScreen) }
  }
}
```

**BUT** this naive approach has the same race condition problem. Explorer must find a better pattern, such as:

1. **Navigation path observation**: Watch the navigation path and hide when any settings route is present
2. **Environment-based context**: Set a "settings context" environment value that GlobalFloatingButtons reads
3. **Preference key propagation**: Use a preference key that bubbles up from settings screens
4. **Task-based approach**: Use `task(id:)` to debounce state changes

---

### Ownership

- **feature-owner**: Create SettingsScreen wrapper, migrate all settings views, verify button behavior
- **data-integrity**: Not needed
- **dispatch-explorer**: Investigate patterns before feature-owner begins
- **xcode-pilot**: Validate navigation behavior on iOS simulator

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: How to create custom environment key and EnvironmentValues extension for passing boolean values through view hierarchy
CONTEXT7_TAKEAWAYS:
- Use @Entry macro on property declarations in EnvironmentValues extension
- Provide a default value (e.g., `@Entry var globalButtonsHidden = false`)
- Create a view modifier extension for convenient access
- Read with `@Environment(\.globalButtonsHidden) var hidden`
- Set with `.environment(\.globalButtonsHidden, true)`
CONTEXT7_APPLIED:
- EnvironmentKey pattern -> GlobalButtonsHiddenKey in AppOverlayState.swift

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (/websites/developer_apple_swiftui)

| Query | Pattern Used |
|-------|--------------|
| Custom environment key for boolean propagation | EnvironmentKey protocol with EnvironmentValues extension (matching existing PullToSearchDisabledKey pattern) |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A (UI Review Required: NO)
**Reviewed**: N/A

#### Checklist

N/A - No customer-facing UI changes

#### Verdict Notes

Skipped per contract: `UI Review Required: NO` because this is a behavioral fix with no visual changes to the UI.

---

### Enforcement Summary

| Check | Required | Rationale |
|-------|----------|-----------|
| Context7 Attestation | YES | Uses SwiftUI navigation patterns |
| Jobs Critique | NO | No visual UI changes |
| Builds on iOS + macOS | YES | Standard |
| Tests pass | YES | Standard |
| xcode-pilot validation | YES | High-risk navigation flow |

---

**IMPORTANT**:
- dispatch-explorer MUST complete exploration before feature-owner begins
- If `UI Review Required: YES` → integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` → Jobs Critique section is not required; integrator skips this check
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
