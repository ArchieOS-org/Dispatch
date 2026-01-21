## Interface Lock

**Feature**: Archive Listing Generator Feature
**Created**: 2026-01-18
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

This is a **structural reorganization** (not feature development). Standard 2-patchset plan:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles (all platforms) | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None (removing only)
- Migration required: N

### Acceptance Criteria (3 max)

1. **Listing Generator feature is not visible in the app UI** - No sidebar entry, no Tools menu entry, no navigation path leads to it
2. **All ListingGenerator files moved to Archive folder** - `Dispatch/Archive/ListingGenerator/` contains all 33 related files
3. **App compiles and tests pass on iOS + macOS** - No broken references, no compile errors

### Non-goals (prevents scope creep)

- No deleting files permanently (Archive only)
- No refactoring other features
- No schema changes
- No removal of ListingGeneratorDraft from SwiftData (data preservation)

### Compatibility Plan

- **Backward compatibility**: N/A - removing feature from navigation only
- **Default when missing**: N/A
- **Rollback strategy**: Move files back from Archive, restore navigation references

---

### Files to Archive

**ListingGenerator Feature Files (33 total):**

```
Dispatch/Features/ListingGenerator/
  Models/
    GeneratedOutput.swift
    GeneratorStatus.swift
    ListingGeneratorDraft.swift
    ListingGeneratorSnapshot.swift
    ListingGeneratorState.swift
    MLSFields.swift
    RefinementRequest.swift
    ReportIntegration.swift
    UploadedDocument.swift
    UploadedPhoto.swift
  Services/
    MockAIService.swift
    MockTrainingDataService.swift
  Views/
    ListingGeneratorView.swift
    ListingInputView.swift
    ListingOutputView.swift
    Components/
      DocumentRow.swift
      DraftRow.swift
      FetchedReportRow.swift
      GenerationProgressView.swift
      GeneratorStatusChip.swift
      ListingPickerRow.swift
      MLSFieldRow.swift
      OutputCard.swift
      PhotoThumbnail.swift
      VersionSelector.swift
    Sections/
      DocumentUploadSection.swift
      DraftsSection.swift
      MLSFieldsSection.swift
      OutputComparisonSection.swift
      PhotoUploadSection.swift
      PropertyInputSection.swift
      RefinementSection.swift
      ReportToggleSection.swift
```

### Navigation/UI References to Remove

| File | Change Required |
|------|-----------------|
| `Dispatch/App/State/AppRouter.swift` | Remove `case listingGenerator` from AppTab enum |
| `Dispatch/App/State/AppRouter.swift` | Remove `case listingGenerator(listingId:)` and `case listingGeneratorDraft(draftId:)` from AppRoute enum |
| `Dispatch/App/State/AppCommand.swift` | Remove `case openListingGenerator(listing:)` command |
| `Dispatch/App/State/AppDestinations.swift` | Remove listingGenerator route handling (lines 95-99) |
| `Dispatch/App/State/DispatchCommands.swift` | Remove "Tools" CommandMenu (lines 61-66) |
| `Dispatch/App/Support/AppTab+Display.swift` | Remove listingGenerator from title/icon switches |
| `Dispatch/App/Platform/iPadContentView.swift` | Remove "Tools" TabSection (lines 92-104), remove listingGenerator case from tabRootView |
| `Dispatch/App/Platform/MacContentView.swift` | Remove listingGenerator case from toolbarContext and macTabRootView |
| `Dispatch/Features/Listings/Views/Screens/ListingListView.swift` | Remove @Query for ListingGeneratorDraft (if displayed in UI) |

### Test File References

| File | Change Required |
|------|-----------------|
| `DispatchTests/State/AppRouterTests.swift` | May need updates if testing listingGenerator cases |

---

### Ownership

- **feature-owner**: Move files to Archive, remove all navigation references, ensure compilation
- **data-integrity**: Not needed (no schema changes)

---

### Context7 Queries

N/A - This is a file reorganization task, no framework/library usage.

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: N/A
**Libraries Queried**: N/A

This is a pure refactor/reorganization with no new framework/library usage.

### Implementation Summary (PATCHSET 1)

**Files Archived**: 32 files moved to `Dispatch/Archive/ListingGenerator/`
**Model Preserved**: `ListingGeneratorDraft.swift` moved to `Dispatch/Models/Archived/` for SwiftData schema compatibility
**Xcode Project**: Added `Archive` to membershipExceptions in PBXFileSystemSynchronizedBuildFileExceptionSet

**Navigation References Removed**:
- `AppRouter.swift`: Removed `listingGenerator` from AppTab, removed `listingGenerator(listingId:)` and `listingGeneratorDraft(draftId:)` from AppRoute
- `AppCommand.swift`: Removed `openListingGenerator(listing:)` command
- `AppDestinations.swift`: Removed listingGenerator route handling
- `DispatchCommands.swift`: Removed Tools CommandMenu
- `AppTab+Display.swift`: Removed listingGenerator from title/icon switches
- `iPadContentView.swift`: Removed Tools TabSection and listingGenerator case
- `MacContentView.swift`: Removed listingGenerator cases from toolbarContext, sidebarCount, macTabRootView
- `MenuPageView.swift`: Removed listingGenerator case from route mapping
- `ContentView.swift`: Removed listingGenerator cases from routeFor and screen mapping
- `AppState.swift`: Removed openListingGenerator handling and listingGenerator from newItem switch
- `ListingListView.swift`: Removed drafts @Query, DraftsSectionCard, and confirmDeleteDraft
- `AppRouterTests.swift`: Removed listingGenerator route equality tests

**Build Status**: iOS + macOS builds pass

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A
**Reviewed**: N/A

UI Review not required - this removes a feature from navigation, does not add/change UI.

---

### Implementation Notes

**CRITICAL**: The `ListingGeneratorDraft` model is used in a SwiftData @Query in `ListingListView.swift`. This model file should remain importable OR the @Query should be removed to avoid compile errors. Review whether drafts are displayed in the listing list UI.

**File Movement Strategy**:
1. Create `Dispatch/Archive/` folder
2. Move entire `Dispatch/Features/ListingGenerator/` to `Dispatch/Archive/ListingGenerator/`
3. Files in Archive will NOT be compiled (excluded from Xcode target)
4. Remove all imports/references to archived files

**Alternative if Archive exclusion is complex**:
- Comment out the navigation entry points only
- Keep files in place but unreachable
- This is simpler but less clean

---

**IMPORTANT**:
- UI Review Required: NO - integrator skips Jobs Critique check
- Context7 Attestation: N/A is valid for pure refactors
- This is a Bypass-eligible change BUT exceeds 3 files, so contract is required
