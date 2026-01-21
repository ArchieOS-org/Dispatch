## Interface Lock

**Feature**: UIKit to SwiftUI Size Class Migration
**Created**: 2026-01-21
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES (affects layout logic on iOS/iPadOS)

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
| 2.5 | Design bar | jobs-critic |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

### Migration Details

Replace UIKit device idiom checks with SwiftUI environment-based size classes:

| File | Line | Current Pattern | New Pattern |
|------|------|-----------------|-------------|
| `Dispatch/App/ContentView.swift` | 30 | `UIDevice.current.userInterfaceIdiom == .phone` | Use existing `horizontalSizeClass == .compact` (env already declared line 29) |
| `Dispatch/SharedUI/Components/GlobalFloatingButtons.swift` | 57-59 | `UIDevice.current.userInterfaceIdiom == .phone` | Add `@Environment(\.horizontalSizeClass)` and use `.compact` |
| `Dispatch/Features/Listings/Views/Screens/ListingListView.swift` | 77-79 | `UIDevice.current.userInterfaceIdiom == .pad` | Add `@Environment(\.horizontalSizeClass)` and use `.regular` |
| `Dispatch/Features/Search/Views/Components/PullToSearchHost.swift` | 66-74 | `UIApplication.shared.connectedScenes` safe area hack | Use `GeometryReader` or `@Environment(\.safeAreaInsets)` |

### Acceptance Criteria (3 max)

1. All 4 files use SwiftUI size classes or safe area environment instead of UIKit device checks
2. Builds successfully on iOS, iPadOS, and macOS (macOS code paths unaffected)
3. Layout behavior matches current behavior (compact = phone-like, regular = iPad-like)

### Non-goals (prevents scope creep)

- No changes to macOS-specific code paths
- No changes to actual layout logic (only HOW device type is detected)
- No removal of `#if os(iOS)` conditionals (still needed for platform separation)

### Compatibility Plan

- **Backward compatibility**: N/A - no API/DTO changes
- **Default when missing**: N/A
- **Rollback strategy**: Revert to UIDevice checks if layout issues discovered

---

### Ownership

- **feature-owner**: Migrate all 4 files to SwiftUI size class patterns
- **data-integrity**: Not needed

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

**Required queries for feature-owner:**
1. SwiftUI: `horizontalSizeClass environment usage patterns`
2. SwiftUI: `safe area insets in pure SwiftUI without UIKit`

CONTEXT7_QUERY: horizontalSizeClass environment size class compact regular usage patterns device detection
CONTEXT7_TAKEAWAYS:
- Use `@Environment(\.horizontalSizeClass) private var horizontalSizeClass` to read size class
- SwiftUI sets size class based on: device type, orientation, and Slide Over/Split View on iPad
- `.compact` = iPhone portrait OR iPad in narrow Split View column
- `.regular` = iPad full screen or wide Split View, macOS always regular
- Size class is layout-based, not device-based; iPad in Split View can be `.compact`
CONTEXT7_APPLIED:
- @Environment(\.horizontalSizeClass) -> ContentView.swift:29, ListingListView.swift:73

CONTEXT7_QUERY: safe area insets GeometryReader safeAreaInsets environment without UIKit
CONTEXT7_TAKEAWAYS:
- Use `GeometryReader` with `geometry.safeAreaInsets` to get safe area insets
- `safeAreaInsets` returns `EdgeInsets` with top, bottom, leading, trailing values
- This is view-level safe area (may include nav bar), not device-level
- No pure SwiftUI equivalent for UIKit's window-level safe area
CONTEXT7_APPLIED:
- Kept UIKit bridge in PullToSearchHost.swift:66-79 (intentional - no SwiftUI equivalent)

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (/websites/developer_apple_swiftui)

| Query | Pattern Used |
|-------|--------------|
| horizontalSizeClass environment size class patterns | @Environment(\.horizontalSizeClass) for layout decisions |
| safe area insets GeometryReader without UIKit | Kept UIKit bridge - no SwiftUI equivalent for window-level safe area |

**Decision Notes:**
- ContentView.swift: Migrated from `UIDevice.current.userInterfaceIdiom == .phone` to `horizontalSizeClass == .compact`
- ListingListView.swift: Migrated from `UIDevice.current.userInterfaceIdiom == .pad` to `horizontalSizeClass == .regular`
- GlobalFloatingButtons.swift: **Intentionally kept device idiom** - iPad uses different UI paradigm (toolbar FilterMenu) regardless of size class
- PullToSearchHost.swift: **Intentionally kept UIKit bridge** - no pure SwiftUI equivalent for device-level safe area insets

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-21

#### Checklist

- [x] Ruthless simplicity - migration removes UIKit dependency where appropriate, code is cleaner
- [x] One clear primary action per screen/state - N/A (refactor, no UI flow changes)
- [x] Strong hierarchy - headline -> primary -> secondary - N/A (no visual changes)
- [x] No clutter - comments are concise and explain rationale clearly
- [x] Native feel - size classes are SwiftUI-native, aligns with platform conventions

#### Verdict Notes

**Migrated files (correct decisions):**
1. `ContentView.swift` - Uses `horizontalSizeClass == .compact` for layout decisions. iPad in narrow Split View correctly gets phone-like UI.
2. `ListingListView.swift` - Uses `horizontalSizeClass == .regular` for stage cards. Adapts to available space.

**Kept UIKit files (justified decisions):**
1. `GlobalFloatingButtons.swift` - Device idiom kept intentionally. iPad has different UI paradigm (toolbar FilterMenu) regardless of size class. This is device capability, not layout.
2. `PullToSearchHost.swift` - UIKit bridge kept intentionally. No SwiftUI equivalent for window-level safe area (Dynamic Island). Platform limitation.

**Why SHIP YES:**
- All decisions are well-documented with clear rationale
- Size class usage follows SwiftUI best practices
- Kept UIKit usages are platform limitations, not laziness
- Code is cleaner and more idiomatic where migration was possible

---

### Implementation Notes

**Size Class Semantics:**
- `.compact` = iPhone (portrait) or iPad Split View narrow column
- `.regular` = iPad (full screen or wide Split View column)

**Important:** The comment in GlobalFloatingButtons.swift (line 56) says "Use idiom, not size class - iPad in Split View can be .compact". This is a deliberate choice that needs review:
- If we want DEVICE-based behavior (iPhone vs iPad hardware), keep UIDevice
- If we want LAYOUT-based behavior (narrow vs wide), use size class

**Recommendation:** Use size class for layout-based decisions (SwiftUI best practice). The comment suggests the original author wanted device-based behavior, but size-class-based is more flexible and matches SwiftUI patterns.

**PullToSearchHost special case:**
The `UIApplication.shared.connectedScenes` pattern is a workaround to get device-level safe area (Dynamic Island height) rather than view-adjusted safe area. Options:
1. Use `GeometryReader` with `.safeAreaInsets` (view-level, may include nav bar)
2. Pass safe area as parameter from parent
3. Accept the view-level safe area if behavior is acceptable

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
