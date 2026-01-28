## Interface Lock

**Feature**: Multi-Platform UI Fixes Verification (Branch nsd97/native-toolbar-sidebar)
**Created**: 2026-01-19
**Status**: locked
**Lock Version**: v1
**UI Review Required**: NO

---

### Summary

This contract covers verification of multi-platform UI fixes already implemented on branch `nsd97/native-toolbar-sidebar`. The fixes address iPad crash issues and macOS toolbar/sidebar behavior.

**Key Commits Already Applied**:
- `8da6fb8` fix: restore Cmd+/ sidebar toggle for NavigationSplitView
- `e1cead6` chore: delete unused NativeSplitView.swift (dead code cleanup)
- `25d4b51` fix: remove custom macOS header and fix toolbar background integration
- `13d97cf` fix: remove SidebarMaterialModifier causing iPad layout oscillation crash
- `d4dec8b` refactor: delete unused toolbar/sidebar components and update contract

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [ ] **Unfamiliar area** (adds dispatch-explorer)

**Note**: This is a verification contract. All fixes are already implemented; we are validating builds and behavior.

### Patchset Plan

Single verification patchset:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Builds pass (iOS, iPadOS, macOS) | integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

### Issues Verified

#### 1. iPad Layout Oscillation Crash (P0) - ALREADY FIXED
- **File**: `/Dispatch/Features/Menu/Views/Components/UnifiedSidebar.swift`
- **Fix Applied**: Removed `SidebarMaterialModifier` that caused UICollectionView layout oscillation
- **Commit**: `13d97cf`
- **Related Contract**: `.claude/contracts/ipad-layout-oscillation-fix.md`

#### 2. macOS Keyboard Shortcuts (P1) - ALREADY WORKING
- **File**: `/Dispatch/App/DispatchApp.swift` (lines 106-111)
- **Current Implementation**: Uses `DispatchCommands { cmd in appState.dispatch(cmd) }`
- **File**: `/Dispatch/App/State/DispatchCommands.swift`
- **Shortcuts Implemented**:
  - Cmd+N: New Item
  - Cmd+Shift+N: New Window
  - Cmd+F: Search
  - Cmd+1: My Workspace
  - Cmd+R: Sync Now
  - Cmd+/: Toggle Sidebar
  - Escape: Back

#### 3. macOS Sidebar Toggle (P2) - ALREADY WORKING
- **File**: `/Dispatch/App/Platform/MacContentView.swift` (lines 256-262)
- **Implementation**: NotificationCenter subscriber handles `.toggleSidebar` notification
- **Commit**: `8da6fb8`

### Acceptance Criteria (3 max)

1. iPad Pro 13-inch (M5) build succeeds without layout oscillation warnings
2. macOS build succeeds with functional keyboard shortcuts (Cmd+N, Cmd+F, Cmd+/)
3. iOS Simulator (iPhone) build succeeds

### Non-goals (prevents scope creep)

- No new features or UI changes
- No refactoring beyond what's already committed
- No changes to keyboard shortcut bindings

### Compatibility Plan

- **Backward compatibility**: N/A (verification only)
- **Default when missing**: N/A
- **Rollback strategy**: N/A (no new changes being made)

---

### Ownership

- **feature-owner**: Not needed (verification only)
- **integrator**: Verify builds on all three platforms
- **data-integrity**: Not needed

---

### Context7 Queries

N/A - Verification contract, no new framework code being written.

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: N/A
**Libraries Queried**: N/A

| Query | Pattern Used |
|-------|--------------|
| N/A (verification only) | N/A |

**Rationale**: This is a verification contract - no new code is being written, only validating existing fixes.

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A (UI Review Required: NO)
**Reviewed**: N/A

Verification contract - no customer-facing UI changes being made.

---

### Validation Checklist

Integrator must verify all three platforms build successfully:

- [ ] **iOS Build**:
  ```bash
  xcodebuild -project Dispatch.xcodeproj -scheme Dispatch \
    -destination 'platform=iOS Simulator,name=iPhone 17' build
  ```

- [ ] **iPadOS Build**:
  ```bash
  xcodebuild -project Dispatch.xcodeproj -scheme Dispatch \
    -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
  ```

- [ ] **macOS Build**:
  ```bash
  xcodebuild -project Dispatch.xcodeproj -scheme Dispatch \
    -destination 'platform=macOS' build
  ```

### Behavior Verification (Manual)

If builds pass, recommend manual verification:
- [ ] iPad: Navigate sidebar rapidly 10+ times, no crash
- [ ] macOS: Cmd+/ toggles sidebar
- [ ] macOS: Cmd+N opens quick entry
- [ ] macOS: Cmd+F opens search

---

### Key Files Reference

| File | Purpose |
|------|---------|
| `/Dispatch/App/DispatchApp.swift` | App entry, scene configuration, commands attachment |
| `/Dispatch/App/State/DispatchCommands.swift` | macOS menu bar commands and shortcuts |
| `/Dispatch/App/Platform/MacContentView.swift` | macOS-specific navigation container |
| `/Dispatch/Features/Menu/Views/Components/UnifiedSidebar.swift` | Shared sidebar content (iPad + macOS) |

---

**IMPORTANT**:
- UI Review Required: NO - This is a verification contract
- Context7 Attestation: N/A - No new framework code
- Integrator runs FINAL to confirm all builds pass
