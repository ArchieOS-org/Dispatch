## Interface Lock

**Feature**: CI Build Fix - ScrollEdgeEffectStyle API
**Created**: 2025-01-21
**Status**: locked
**Lock Version**: v1
**UI Review Required**: NO

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [ ] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators (none - small fix):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles on all SDKs | feature-owner |
| 2 | CI passes | integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

### Problem Statement

The `ScrollEdgeEffectModifier` in `StandardScreen.swift` uses `.scrollEdgeEffectStyle(.soft, for: .top)` which is an iOS 26/macOS 26 API. The code currently uses `#if compiler(>=6.2)` for compile-time guarding, but this check is insufficient when:
- CI runs with Swift 6.2+ compiler but older SDK that lacks the symbol
- The symbol doesn't exist at compile time, causing `error: value of type 'ScrollEdgeEffectModifier.Content' has no member 'scrollEdgeEffectStyle'`

**Current approach (failing)**:
```swift
#if compiler(>=6.2)
if #available(iOS 26, macOS 26, *) {
  content.scrollEdgeEffectStyle(.soft, for: .top)
} else {
  content
}
#else
content
#endif
```

### Root Cause

`#if compiler(>=6.2)` checks Swift compiler version, not SDK version. The API symbol must exist in the SDK at compile time. If Xcode's SDK doesn't include the iOS 26/macOS 26 symbols, the code won't compile regardless of compiler version.

### Solution Options

**Option 1: Remove the iOS 26+ API entirely (SAFEST)**
- Remove `scrollEdgeEffectStyle` usage since CI cannot build it
- Re-add when Xcode 18 SDK is available in CI
- Pros: Guaranteed to work, no complexity
- Cons: Loses the soft edge effect on iOS 26+

**Option 2: SDK version check via canImport (PREFERRED if viable)**
- Use `#if canImport(SwiftUI, _version: X)` if a version is available
- Requires knowing the SwiftUI module version that includes the API
- May not be reliable

**Option 3: Custom build flag (COMPLEX)**
- Add `-DHAS_IOS26_SDK` flag to Xcode 18 builds only
- Wrap code in `#if HAS_IOS26_SDK`
- Requires CI configuration changes

### Recommendation

**Option 1 (Remove)** is recommended for now. The `scrollEdgeEffectStyle` provides a subtle visual enhancement but is not critical functionality. Once CI is updated to Xcode 18 with iOS 26 SDK, the code can be re-enabled.

### Acceptance Criteria (3 max)

1. CI builds pass on all platforms (iOS, iPadOS, macOS)
2. Code compiles on both Xcode 17 (iOS 18 SDK) and Xcode 18 (iOS 26 SDK)
3. Soft edge effect is preserved for local development with Xcode 18 (if possible with option that works)

### Non-goals (prevents scope creep)

- No other UI changes
- No new features
- Do not refactor StandardScreen beyond this fix

### Compatibility Plan

- **Backward compatibility**: N/A (build fix only)
- **Default when missing**: Falls back to default scroll edge behavior
- **Rollback strategy**: Revert commit if needed

---

### Ownership

- **feature-owner**: Fix ScrollEdgeEffectModifier to compile on all SDK versions
- **data-integrity**: Not needed

---

### Context7 Queries

- Swift: compile time conditional compilation for unavailable API symbols SDK version → `#if compiler(>=X.Y)` and `#if canImport(Module, _version:)` patterns
- Swift: compiler directive conditional compilation hasFeature → `#if compiler(>=6.2)` checks Swift compiler version, not SDK availability

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES (pre-contract research)
**Libraries Queried**: /swiftlang/swift

| Query | Pattern Used |
|-------|--------------|
| compiler directive conditional compilation for SDK availability | Confirmed `#if compiler` checks compiler version, not SDK |
| canImport with version | `#if canImport(Module, _version:)` exists but requires module version info |

**Notes**: Context7 confirmed that `#if compiler(>=X.Y)` checks the Swift compiler version, not the presence of SDK symbols. For APIs that don't exist in the SDK, the symbol lookup fails before the `#if` branch is even evaluated. The safest approach is to remove the API usage until SDK is available.

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A
**Reviewed**: N/A

Not applicable - `UI Review Required: NO` (build fix only, no visual changes)

---

### Implementation Notes

**File to modify**: `/Users/noahdeskin/conductor/workspaces/dispatch/quito/Dispatch/App/Shell/StandardScreen.swift`
**Lines**: 231-246

**Recommended change** (Option 1 - Remove):
```swift
private struct ScrollEdgeEffectModifier: ViewModifier {
  func body(content: Content) -> some View {
    // scrollEdgeEffectStyle requires iOS 26/macOS 26 SDK (Xcode 18+).
    // Disabled until CI has Xcode 18 SDK available.
    // TODO: Re-enable when CI is updated to Xcode 18
    // #if compiler(>=6.2)
    // if #available(iOS 26, macOS 26, *) {
    //   content.scrollEdgeEffectStyle(.soft, for: .top)
    // } else {
    //   content
    // }
    // #else
    content
    // #endif
  }
}
```

**Alternative** (if we want to keep it for local dev with Xcode 18):
Use a custom Active Compilation Condition flag that only Xcode 18 sets:
- In Xcode project, add `XCODE18_SDK` to Active Compilation Conditions for builds with iOS 26 SDK
- Code: `#if XCODE18_SDK && compiler(>=6.2)`

This requires project configuration changes and may be overkill for a subtle visual effect.

---

**IMPORTANT**:
- If `UI Review Required: YES` → integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` → Jobs Critique section is not required; integrator skips this check
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
