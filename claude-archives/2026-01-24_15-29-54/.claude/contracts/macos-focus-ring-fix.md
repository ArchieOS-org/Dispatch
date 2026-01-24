# Interface Lock: macOS Focus Ring Fix

**Feature**: Fix blue line between sidebar and content on macOS
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES

## Problem

A blue line appears between the sidebar and main content area on macOS. This is the system focus ring being drawn around the focusable content area.

## Root Cause

In `ContentView.swift` lines 311-312:
```swift
.focusable()
.focused($contentAreaFocused)
```

The content area uses `.focusable()` for type-to-search keyboard handling, but doesn't disable the visual focus effect. On macOS, SwiftUI draws the standard blue focus ring around focusable views.

## Contract

- **Files to modify**: `Dispatch/App/ContentView.swift`
- **Change type**: Add `.focusEffectDisabled()` modifier
- **No DTO/API changes**: ✓
- **No schema changes**: ✓
- **No new state/actions**: ✓

## Fix

Add `.focusEffectDisabled()` after the `.focused()` modifier:

```swift
.focusable()
.focused($contentAreaFocused)
.focusEffectDisabled()  // Disable blue focus ring while keeping keyboard focus
```

## Acceptance Criteria

1. Blue line no longer appears between sidebar and content on macOS
2. Type-to-search (alphanumeric key press opens search) still works
3. Builds successfully on iOS and macOS

## Non-goals

- Changing focus behavior
- Modifying keyboard handling logic
- Affecting iOS/iPadOS behavior

## Ownership

- **feature-owner**: Implement the fix in ContentView.swift
- **integrator**: Verify macOS + iOS builds

## Patchset Protocol

- PATCHSET 1: Add `.focusEffectDisabled()` modifier
- PATCHSET 4: Verify builds (single-line fix, skip intermediate patchsets)

## Jobs Critique

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-16

#### Checklist
- [x] Ruthless simplicity - Single modifier, removes visual noise
- [x] One clear primary action - No change to interaction model
- [x] Strong hierarchy - Removes false emphasis on container boundary
- [x] No clutter - Eliminates spurious focus ring
- [x] Native feel - Matches macOS split-view conventions (Finder, Mail, Notes)

#### Verdict Notes
Clean bug fix. The blue focus ring between sidebar and content was an implementation artifact, not a design decision. The fix:
1. Removes accidental visual noise
2. Preserves keyboard functionality (type-to-search still works)
3. Aligns with macOS platform conventions

A11y verified: `.focusable()` and `.focused()` remain intact. Only the visual ring is suppressed.
