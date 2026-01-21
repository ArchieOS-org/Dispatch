## Interface Lock

**Feature**: Floating Glass Sidebar and Toolbar (macOS)
**Created**: 2026-01-19
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

### Problem Summary

Three visual issues must be fixed on macOS:

#### Problem 1: Sidebar Appears Opaque (Not Translucent)

**Root Causes:**
1. `MacWindowPolicy.swift` is missing:
   - `window.isOpaque = false`
   - `window.backgroundColor = .clear`
   These are REQUIRED for NSVisualEffectView/Material to render translucently.

2. `StandardScreen.swift` applies opaque `DS.Colors.Background.primary` with `.ignoresSafeArea()`. Materials blur what's BEHIND them - opaque backgrounds block translucency.

**Current State in `MacWindowPolicy.swift:71-95`:**
- Has `titlebarAppearsTransparent = true`
- Has `.fullSizeContentView` style mask
- MISSING `window.isOpaque = false`
- MISSING `window.backgroundColor = .clear`

#### Problem 2: Sidebar Not Floating Shape

**Current in `ResizableSidebar.swift:157-161`:**
```swift
.background {
  Rectangle()  // Plain rectangle - no rounded corners
    .glassSidebarBackground()
    .ignoresSafeArea(.all, edges: .top)
}
```

**Required Xcode/Finder Style:**
- Rounded corners (~12-16pt radius)
- Inset/padding from window edges (~8pt)
- Subtle shadow for depth
- StrokeBorder for definition

#### Problem 3: Toolbar Uses Light Material, Not Liquid Glass

**Current in `BottomToolbar.swift:65-73`:**
```swift
.background {
  Rectangle()
    .fill(.regularMaterial)  // Opaque, light colored
    .overlay(alignment: .top) {
      Rectangle()
        .fill(Color.primary.opacity(0.1))
        .frame(height: 1)
    }
}
```

**Required:**
- Change to `.thinMaterial` or `.ultraThinMaterial`
- Use `RoundedRectangle` instead of `Rectangle`
- Add shadow and strokeBorder like `LiquidGlassToolbar` pattern

### Files to Modify

| File | Path | Changes |
|------|------|---------|
| `MacWindowPolicy.swift` | `Dispatch/Foundation/Platform/MacWindowPolicy.swift` | Add `window.isOpaque = false`, `window.backgroundColor = .clear` in `configure()` method |
| `ResizableSidebar.swift` | `Dispatch/Foundation/Platform/macOS/ResizableSidebar.swift` | Change `SidebarContainerView` to use `RoundedRectangle`, add padding, shadow, stroke |
| `BottomToolbar.swift` | `Dispatch/Foundation/Platform/macOS/BottomToolbar.swift` | Change `.regularMaterial` to glass effect, add rounded corners, shadow |
| `GlassEffect.swift` | `Packages/DesignSystem/Sources/DesignSystem/Effects/GlassEffect.swift` | Add `glassFloatingSidebarBackground()` variant |
| `DSSpacing.swift` | `Packages/DesignSystem/Sources/DesignSystem/Tokens/DSSpacing.swift` | Add tokens for sidebar inset and corner radius |
| `DSRadius.swift` | `Packages/DesignSystem/Sources/DesignSystem/Tokens/DSRadius.swift` | Add `floatingPanel` radius token |

### Acceptance Criteria (3 max)

1. **Sidebar is translucent**: Desktop/content shows through sidebar material blur on macOS
2. **Sidebar has floating panel appearance**: Rounded corners (16pt), inset from edges (8pt), shadow, stroke border - matches Xcode/Finder style
3. **Toolbar has liquid glass effect**: Uses thin material, rounded corners, shadow, stroke - consistent with sidebar

### Non-goals (prevents scope creep)

- No changes to iOS/iPadOS sidebar or toolbar appearance
- No changes to sidebar resize/collapse behavior
- No changes to toolbar button layout or actions
- No changes to full-screen mode handling

### Compatibility Plan

- **Backward compatibility**: N/A - visual-only changes
- **Default when missing**: N/A
- **Rollback strategy**: Revert file changes; no data implications

---

### Ownership

- **feature-owner**: All six files - window configuration, sidebar container, toolbar background, design tokens
- **data-integrity**: Not needed

---

### Implementation Notes

#### 1. MacWindowPolicy.swift Changes

In the `configure(_ window:)` method, add after line 78:

```swift
// 1a. Window Transparency for Material Backgrounds
// Required for NSVisualEffectView/Material to show translucency
window.isOpaque = false
window.backgroundColor = .clear
```

#### 2. ResizableSidebar.swift Changes

In `SidebarContainerView`, modify the background (around line 157):

```swift
.background {
  // Use rounded rectangle for floating panel effect
  RoundedRectangle(cornerRadius: DS.Radius.floatingPanel)
    .glassFloatingSidebarBackground()
}
// Add padding from window edges for floating effect
.padding(.leading, DS.Spacing.floatingPanelInset)
.padding(.vertical, DS.Spacing.floatingPanelInset)
```

**Key considerations:**
- The `containerWidth` calculation may need adjustment to account for new padding
- The drag handle offset may need adjustment
- Keep `.ignoresSafeArea(.all, edges: .top)` for titlebar integration

#### 3. BottomToolbar.swift Changes

Replace the background (lines 65-73):

```swift
.background {
  RoundedRectangle(cornerRadius: DS.Radius.floatingPanel)
    .glassToolbarBackground()
}
.padding(.horizontal, DS.Spacing.floatingPanelInset)
.padding(.bottom, DS.Spacing.floatingPanelInset)
```

#### 4. GlassEffect.swift New Method

Add new method for floating sidebar:

```swift
/// Applies a floating glass panel effect for sidebars on macOS.
/// Includes rounded corners, shadow, and stroke border.
@ViewBuilder
public func glassFloatingSidebarBackground() -> some View {
  #if os(macOS)
  fill(.ultraThinMaterial)
    .overlay {
      RoundedRectangle(cornerRadius: DS.Radius.floatingPanel)
        .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
    }
    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
  #else
  fill(.thinMaterial)
  #endif
}
```

#### 5. DSSpacing.swift New Tokens

Add under `// MARK: - Sidebar` section:

```swift
/// Inset for floating panel from window edges
public static let floatingPanelInset: CGFloat = 8
```

#### 6. DSRadius.swift New Token

Add:

```swift
/// Floating panel corner radius (16pt) - sidebars, toolbars on macOS
public static let floatingPanel: CGFloat = 16
```

### Context7 Queries Required

- **NSWindow**: Query `isOpaque` and `backgroundColor` for translucent window configuration
- **SwiftUI Materials**: Query material hierarchy (ultraThin vs thin vs regular) for sidebar vs toolbar
- **NSVisualEffectView**: Query proper configuration for sidebar panels

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (/websites/developer_apple_swiftui)

| Query | Pattern Used |
|-------|--------------|
| SwiftUI materials thinMaterial ultraThinMaterial regularMaterial for translucent backgrounds with vibrancy | ultraThinMaterial for sidebar (most translucent), thinMaterial for toolbar |

CONTEXT7_QUERY: SwiftUI materials thinMaterial ultraThinMaterial regularMaterial for translucent backgrounds with vibrancy
CONTEXT7_TAKEAWAYS:
- ultraThinMaterial is mostly translucent - best for sidebars where you want desktop to show through
- thinMaterial is more translucent than opaque - good for toolbars
- regularMaterial is somewhat translucent - less blur, more opaque
- Materials can be applied with .fill() on shapes or .background() on views
- Available iOS 15+, macOS 12+
CONTEXT7_APPLIED:
- ultraThinMaterial -> GlassEffect.swift:100 glassFloatingSidebarBackground()
- thinMaterial -> GlassEffect.swift:117 glassFloatingToolbarBackground()

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-19 14:30

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes

This implementation exemplifies Apple's modern macOS design language:

**What Works:**
1. **Native materials over custom colors**: Uses ultraThinMaterial (sidebar) and thinMaterial (toolbar) - proper material hierarchy matching Xcode/Finder
2. **Floating panel treatment**: 16pt corner radius, 8pt inset from window edges, subtle 0.5pt stroke borders at 15% white opacity
3. **Shadow depth**: Appropriate shadow parameters (12pt/10pt radius) create floating effect without feeling heavy
4. **Design token compliance**: All values from DS.Radius.floatingPanel and DS.Spacing.floatingPanelInset - no magic numbers
5. **Platform-appropriate**: macOS-only styling via #if os(macOS), iOS fallback maintains simpler aesthetic

**Would Apple ship this?** Yes - the floating glass panels match the visual language introduced in Xcode 16 and Finder on macOS Sequoia. The implementation is restrained, uses system materials, and creates depth without adding visual noise.

---

### Enforcement Summary

| Check | Responsible Agent | Blocking |
|-------|-------------------|----------|
| Builds on iOS + macOS | integrator | YES |
| Sidebar translucent | jobs-critic | YES (visual) |
| Sidebar floating shape | jobs-critic | YES (visual) |
| Toolbar liquid glass | jobs-critic | YES (visual) |
| Context7 Attestation | integrator | YES |
| Jobs Critique SHIP YES | integrator | YES |

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
