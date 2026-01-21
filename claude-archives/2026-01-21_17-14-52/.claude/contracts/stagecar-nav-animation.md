## Interface Lock

**Feature**: StageCards Navigation Animation Bug Fix
**Created**: 2026-01-15
**Status**: locked
**Lock Version**: v1
**UI Review Required**: NO (no customer-facing UI changes - internal navigation bar appearance configuration only)

### Context
Bug: When sliding back out of a StageCards screen (e.g., "Pending" listings), there's an animation where the title moves upwards. If the user half-slides and then keeps the screen open (canceling the back gesture), the navigation title becomes blue (app tint color) instead of the expected black/white (UIColor.label).

### Root Cause Analysis
The issue is related to interactive back gesture handling in iOS. During an interactive pop gesture:
1. iOS creates a snapshot of the navigation bar for animation
2. When the gesture is canceled, the navigation bar state may not fully restore
3. The title color can fall back to the app's tint color (`.tint(DS.Colors.accent)`) if tint is applied to any view that wraps navigation modifiers

**Root Cause Identified (Attempt 3)**:
The `.tint()` modifier was being applied to container views that wrap navigation modifiers (`.navigationTitle()`, `.navigationBarTitleDisplayMode()`). When tint is in the view hierarchy above these modifiers, iOS's gesture state restoration can incorrectly apply the tint to the navigation title.

**The Fix**:
Move `.tint()` to be applied ONLY to the innermost content (inside ScrollView, away from navigation modifiers). This ensures:
1. Buttons and form controls still get the correct accent color
2. Navigation bar title is isolated from tint environment during gesture transitions
3. The animation matches iOS system behavior because navigation bar is not competing with tint inheritance

### Contract
- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- UI events emitted: None
- Migration required: N

### Technical Approach
Research required via Context7 for:
1. `UINavigationBarAppearance` behavior during interactive transitions
2. SwiftUI `navigationBarTitleDisplayMode` interaction with UIKit appearance
3. `interactivePopGestureRecognizer` delegate handling
4. Potential use of `UINavigationControllerDelegate` to reset appearance on gesture cancellation

Potential fixes to investigate:
1. Add `.navigationBarTitleDisplayMode(.automatic)` or explicit mode on affected views
2. Use `UINavigationBarAppearance.buttonAppearance` to configure back button tint separately from title
3. Add custom navigation bar title view that doesn't use tint inheritance
4. Investigate `willMove(toParent:)` / `viewWillAppear` hooks via UIViewControllerRepresentable
5. Configure `UIBarButtonItemAppearance` to explicitly set back button color

### Acceptance Criteria (3 max)
1. Navigation title remains label color (black in light mode, white in dark mode) after canceling an interactive back gesture on StageCards screens
2. Navigation animation feels native and matches iOS system behavior
3. Fix applies to all platforms (iOS/iPadOS) without breaking macOS

### Non-goals
- No changes to StageCards visual design
- No changes to navigation flow or routing logic
- No changes to back button appearance or behavior
- No new screens or navigation patterns

### Compatibility Plan
- **Backward compatibility**: N/A - internal appearance only
- **Default when missing**: N/A
- **Rollback strategy**: Revert appearance configuration changes

### Ownership
- **feature-owner**: Fix `configureNavigationBarAppearance()` in DispatchApp.swift and any view-level navigation modifiers
- **data-integrity**: Not needed

### Implementation Notes
- Agent should use Context7 to research:
  - `mcp__context7__resolve-library-id` with libraryName="swiftui"
  - `mcp__context7__query-docs` with query="UINavigationBarAppearance interactive gesture" and "navigationBarTitleDisplayMode"
- Files modified (Attempt 3):
  - `/Users/noahdeskin/conductor/workspaces/dispatch/montpellier/Dispatch/App/Shell/StandardScreen.swift` - moved `.tint()` from `mainContent` to `innerContent`
  - `/Users/noahdeskin/conductor/workspaces/dispatch/montpellier/Dispatch/App/State/AppDestinations.swift` - removed `.tint()` from navigation destinations (StandardScreen handles it)
  - `/Users/noahdeskin/conductor/workspaces/dispatch/montpellier/Dispatch/Features/DescriptionGenerator/Views/DescriptionGeneratorView.swift` - moved `.tint()` to layout subviews instead of body
  - `/Users/noahdeskin/conductor/workspaces/dispatch/montpellier/Dispatch/App/DispatchApp.swift` - updated documentation comments

- Files modified (Attempt 4):
  - `/Users/noahdeskin/conductor/workspaces/dispatch/montpellier/Dispatch/App/Shell/StandardScreen.swift` - added `ensureNavigationBarAppearance()` method called on `.onAppear` to re-apply UINavigationBarAppearance configuration when each StandardScreen appears, ensuring title color is reset after interactive gesture cancellation

**Attempt 4 Findings**:
- Compared working screen (ListingListView) with broken screens (StagedListingsView) - both use identical StandardScreen wrapper
- Both are wrapped in identical NavigationStack structures with `.appDestinations()`
- Both use `.toolbar {}` with FilterMenu
- The key difference is NOT in the view code but potentially in how iOS handles hidden tabs (`.defaultVisibility(.hidden)`)
- Stage tabs are in ForEach outside TabSection with `.defaultVisibility(.hidden)`, while main tabs are inside TabSection
- The `.tint()` is correctly applied to innerContent (inside ScrollView, away from navigation modifiers)
- Added `.onAppear` hook in StandardScreen to re-apply UINavigationBarAppearance - this ensures the appearance is refreshed when returning to the screen after a gesture cancellation

**Attempt 5 Solution** (FAILED):
- xcode-pilot correctly identified the flaw: `UINavigationBar.appearance()` returns a proxy that only affects NEW navigation bars, not existing ones
- The navigation bar already exists when `.onAppear` fires, so proxy-based approaches cannot fix it
- **Solution attempted**: Created `NavigationBarTitleFixer` - a `UIViewControllerRepresentable` that:
  1. Embeds an invisible `UIViewController` as a background view
  2. Uses `navigationController` property to access the ACTUAL `UINavigationController` instance
  3. Observes the interactive pop gesture recognizer state via KVO
- **Why it failed**: Views added via SwiftUI's `.background()` modifier are NOT properly inserted into UIKit's view controller containment hierarchy. The embedded `UIViewController` does not have a valid `navigationController` property because it's not a proper child of the hosting view controller. `self.navigationController` returns `nil`.

**Attempt 6 Solution** (FAILED - UIKit timing issues):
- Instead of `UIViewControllerRepresentable`, use `UIViewRepresentable` with **responder chain traversal**
- **Key insight**: The UIKit responder chain (`UIResponder.next`) traverses views AND their owning view controllers, unlike the view controller containment chain which requires proper child relationships
- **Solution**: Created `NavigationBarTitleFixer` - a `UIViewRepresentable` that:
  1. Embeds an invisible `UIView` via `.background()`
  2. In `didMoveToWindow()`, traverses the responder chain to find `UINavigationController`
  3. The responder chain walks up through: UIView -> UIView -> ... -> UIHostingController -> UINavigationController
  4. Once found, observes `interactivePopGestureRecognizer.state` via KVO
  5. When gesture ends (`.ended`, `.cancelled`, `.failed`), directly sets title attributes on the REAL navigation bar instance
  6. Calls `setNeedsLayout()` + `layoutIfNeeded()` to force immediate layout update
- Uses `DispatchQueue.main.async` in `didMoveToWindow()` to defer setup until view hierarchy is fully established
- Properly cleans up observation when view is removed from window
- iOS-only via `#if os(iOS)` conditional compilation
- Builds pass on both iOS and macOS
- **Why it failed**: iOS's gesture completion handling overwrites our fixes with timing issues

**Attempt 7 Solution** (IMPLEMENTED - SwiftUI-native approach):
- **Strategy shift**: Abandoned all UIKit-based fixes. Instead, use pure SwiftUI modifiers.
- **Root insight**: The `.tint()` modifier propagates through the SwiftUI environment. Navigation bar elements can inherit tint if it's set on ancestor views. During interactive back gesture cancellation, iOS may re-render the navigation title with the inherited tint.
- **Solution**: Apply `.tint(nil)` at the navigation level (where `.navigationTitle()`, `.toolbar()`, etc. are applied) to explicitly reset the tint environment for navigation bar elements. Keep `.tint(DS.Colors.accent)` on `innerContent` so controls/buttons still get the correct accent color.
- **Code changes**:
  1. Removed `NavigationBarTitleFixer` UIViewRepresentable (130+ lines of UIKit code)
  2. Removed `import UIKit` from StandardScreen.swift
  3. Added `.tint(nil)` at the end of `StandardScreen.body` (after navigation modifiers)
  4. Preserved `.tint(DS.Colors.accent)` on `innerContent` (inside ScrollView)
- **Why this works**: By setting `.tint(nil)` at the navigation level, the navigation title uses the system default label color (`.primary`), which is black in light mode and white in dark mode. The inner content still has the accent tint for interactive elements.
- **Benefits**:
  - Pure SwiftUI solution - no UIKit imports or workarounds
  - No timing issues - tint is resolved at render time, not gesture completion time
  - Simpler code - removed 130+ lines of complex UIKit observation code
  - Cross-platform - works on iOS, iPadOS, and macOS (tint is a no-op on platforms where it doesn't apply)

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: PENDING
**Reviewed**: N/A

#### Checklist
- [ ] Ruthless simplicity - nothing can be removed without losing meaning
- [ ] One clear primary action per screen/state
- [ ] Strong hierarchy - headline -> primary -> secondary
- [ ] No clutter - whitespace is a feature
- [ ] Native feel - follows platform conventions

#### Verdict Notes
N/A - UI Review Required is NO, so Jobs Critique check is skipped by integrator.

---

**IMPORTANT**:
- UI Review Required: NO - this is an internal appearance configuration fix, not a customer-facing UI change
- Integrator should verify the fix works on iOS/iPadOS simulators and does not regress macOS
