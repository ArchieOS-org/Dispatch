# Settings Improvements Contract

## Interface Lock

**Feature**: Settings UI Improvements
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES

### Contract

**Changes Required:**
1. **Profile as separate page** - Extract ProfileSection into navigable ProfilePageView
2. **Settings styling** - Remove excessive card backgrounds, follow app pattern of minimal backgrounds with dividers
3. **Mac chevron fix** - Remove `chevron.up.chevron.down` from role picker Menu (rely on native affordance)
4. **Role change modal** - Replace `.confirmationDialog()` with fullscreen modal + fade overlay on iOS/iPadOS
5. **Design system addition** - Add fade overlay pattern to DESIGN_SYSTEM.md and create reusable component

**New/changed model fields:** None
**DTO/API changes:** None
**State/actions added:** Navigation state for Settings → Profile
**Migration required:** NO

### Acceptance Criteria (3 max)
1. Profile is accessible via navigation from Settings, not embedded inline
2. Role change on iOS/iPadOS shows as fullscreen modal with fade overlay (not anchored action sheet)
3. macOS role picker shows single native disclosure indicator (no duplicate chevron)

### Non-goals
- Changing profile functionality (only restructuring UI)
- Adding new settings categories (just fixing current layout)
- Modifying authentication/sign-out behavior

### Ownership
- feature-owner: All UI changes, design system addition
- data-integrity: Not needed (no schema changes)

### Jobs Critique

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-15 10:45

#### Checklist
- [x] Ruthless simplicity - Profile extracted to dedicated page reduces Settings clutter. Modal has minimal controls.
- [x] One clear primary action - RoleChangeModal: filled "Change to [Role]" button is clearly primary, Cancel is text-only secondary.
- [x] Strong hierarchy - Clear visual hierarchy: profile header (avatar + name) > role picker > sign out. Typography tokens used correctly.
- [x] No clutter - Removed excessive card backgrounds. Clean divider-based separation. Whitespace used appropriately.
- [x] Native feel - macOS uses native confirmationDialog. iOS gets custom modal. Chevron conditionally hidden on macOS.

#### Execution
- [x] DS Components: Uses DS.Typography, DS.Colors, DS.Spacing, DS.Shadows throughout. modalScrim added to design system.
- [x] A11y: VoiceOver labels present on all interactive elements. Modal has .isModal trait. Touch targets use minTouchTarget (44pt).
- [x] States: Loading (ProgressView), Error (alert), all states covered with graceful fallbacks.

#### Verdict Notes
Clean implementation that respects platform conventions. The separation of Profile into its own navigable page follows the app pattern and declutters Settings. The role change modal on iOS/iPadOS is well-designed with proper hierarchy and animation. macOS correctly uses native dialog. All design system tokens used consistently.

### Patchset Status
- [x] PATCHSET 1: Create ProfilePageView as separate navigable screen
- [x] PATCHSET 2: Update SettingsView navigation + fix styling patterns
- [x] PATCHSET 3: Fix macOS chevron + create fullscreen role modal for iOS/iPad
- [x] PATCHSET 4: Add fade overlay to design system + cleanup + tests

### Implementation Notes

**PATCHSET 1:**
- Added `case profile` to `AppRoute` in AppRouter.swift
- Added navigation destination handler in AppDestinations.swift
- Created ProfilePageView.swift with full profile management functionality

**PATCHSET 2:**
- Replaced embedded ProfileSection with ProfileRow navigation row
- Removed card backgrounds from Settings sections
- Updated section header from "Profile" to "Account"

**PATCHSET 3:**
- macOS chevron fix: `#if os(iOS)` conditional around chevron icon
- iOS/iPadOS: Created RoleChangeModal with dimmed scrim backdrop
- macOS continues using native confirmationDialog

**PATCHSET 4:**
- Added `DS.Colors.modalScrim` color token (Black 40%)
- Updated DESIGN_SYSTEM.md with modalScrim documentation
- iOS + macOS builds pass
- Pre-existing test failures noted (AppStateTests, ArchitectureTests, PreviewInfrastructureTests)
  - These tests were failing before this feature and are unrelated to settings improvements
