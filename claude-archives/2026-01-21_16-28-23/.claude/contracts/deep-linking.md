## Interface Lock

**Feature**: Deep Linking Support for Entity Navigation
**Created**: 2026-01-17
**Status**: locked
**Lock Version**: v1
**UI Review Required**: NO

### Contract
- New/changed model fields: None
- DTO/API changes: None
- State/actions added:
  - `AppCommand.deepLink(URL)` - new command case for URL handling
- UI events emitted: None (uses existing navigation system)
- Migration required: N

### Accepted URL Patterns
```
dispatch://listing/{uuid}   -> AppRoute.listing(UUID)
dispatch://task/{uuid}      -> AppRoute.workItem(.task(UUID))
dispatch://property/{uuid}  -> AppRoute.property(UUID)
```

### Acceptance Criteria (3 max)
1. Tapping `dispatch://listing/{valid-uuid}` in Safari/Notes navigates to that listing
2. Invalid UUIDs or non-existent entities show appropriate error (no crash)
3. OAuth redirect handling (`com.googleusercontent.apps.*`) remains functional

### Non-goals (prevents scope creep)
- No Universal Links / Associated Domains (marked as future work)
- No new UI for "entity not found" - use existing error patterns
- No deep link analytics or tracking

### Compatibility Plan
- **Backward compatibility**: N/A - new feature
- **Default when missing**: Invalid URLs are logged and ignored
- **Rollback strategy**: Remove `dispatch://` from Info.plist

### Implementation Notes
- Use existing `AppRoute` enum (ID-based, SwiftData-safe)
- Route through `AppState.dispatch()` for consistency
- Handle both iPhone (phonePath) and iPad/macOS (destination paths)
- Preserve existing OAuth URL handling in `.onOpenURL`

### Ownership
- **feature-owner**: Full vertical slice - Info.plist, DeepLinkHandler, AppCommand, AppState, DispatchApp
- **data-integrity**: Not needed (no schema/sync changes)

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A (UI Review Required: NO)
**Reviewed**: N/A

#### Checklist
N/A - No customer-facing UI changes

#### Verdict Notes
UI Review not required per contract - deep linking is a navigation mechanism with no visual changes.

---

### Patchset Breakdown

**PATCHSET 1**: Model + Infrastructure
- Add `dispatch` URL scheme to Info.plist
- Create `DeepLinkHandler.swift` with URL parsing logic
- Add `AppCommand.deepLink(URL)` case

**PATCHSET 2**: State Integration
- Handle `.deepLink` in `AppState.dispatch()`
- Route parsed URLs to appropriate `AppRoute`
- Handle invalid UUID / parse errors

**PATCHSET 3**: App Integration
- Update `DispatchApp.onOpenURL` to detect and route deep links
- Preserve OAuth redirect handling
- Handle entity-not-found edge case

**PATCHSET 4**: Cleanup + Tests
- Add unit tests for DeepLinkHandler URL parsing
- Test invalid UUID handling
- Verify OAuth still works
- SwiftLint pass

---

**IMPORTANT**:
- UI Review Required: NO - integrator skips Jobs Critique check
- This is a Fast Lane feature (no schema, no breaking DTO, no destructive ops)
