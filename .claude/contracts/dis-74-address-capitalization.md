## Interface Lock

**Feature**: DIS-74: Auto-capitalize address, city, and province fields
**Created**: 2026-01-21
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

Based on checked indicators (none checked - minimal UI formatting change):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

### Acceptance Criteria (3 max)

1. All displayed address, city, and province fields appear in title case (e.g., "San Francisco" not "san francisco" or "SAN FRANCISCO")
2. Title-case formatting is implemented via a reusable String extension
3. Builds pass on iOS and macOS with no new warnings

### Non-goals (prevents scope creep)

- No changes to data storage (values remain as-is in Supabase)
- No changes to input behavior (users can type however they want)
- No validation or auto-correction during text entry
- No changes to search/filter logic

### Compatibility Plan

- **Backward compatibility**: N/A (display-only change)
- **Default when missing**: N/A
- **Rollback strategy**: Remove String extension and .titleCased() calls

---

### Ownership

- **feature-owner**: Create String extension, apply to all 7 display locations
- **data-integrity**: Not needed

---

### Implementation Notes

**String extension approach**:
Create `String+TitleCase.swift` with a `titleCased()` method that handles:
- Capitalizing first letter of each word
- Preserving small words (of, the, and) in lowercase except at start
- Handling edge cases (empty strings, single characters)

**Files to modify** (7 total):
1. `PropertyRow.swift` - city/province in locationText (line 76-78)
2. `PropertyDetailView.swift` - city/province in metadataSection (line 84)
3. `ListingRow.swift` - address (line 27)
4. `ListingDetailView.swift` - city/province in stageSection (line 190)
5. `SearchResult.swift` - listing.city in subtitle (line 76)
6. `ListingDraftDemoView.swift` - address/city/province TextFields (lines 141, 148, 150)
7. `PropertyInputSection.swift` - address/city/province displays

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: String capitalized title case extension method capitalize first letter of each word
CONTEXT7_TAKEAWAYS:
- Swift String has `.capitalized` property that capitalizes first letter of each word
- `capitalizedString` in NSString capitalizes first letter of each substring separated by spaces/tabs/line terminators
- For localized capitalization, use `capitalizedStringWithLocale:`
- Swift's title case implementation is marked TBD but `.capitalized` exists via NSString bridging
CONTEXT7_APPLIED:
- Use `.capitalized` property -> String+TitleCase.swift extension (wraps it with small-word handling)

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: Swift (/swiftlang/swift)

| Query | Pattern Used |
|-------|--------------|
| String capitalized title case | Used `.capitalized` property inside custom `titleCased()` method with small-word handling |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A
**Reviewed**: N/A

UI Review Required is NO - this is a formatting-only change with no layout, hierarchy, or interaction changes. Jobs Critique not required.

---

**IMPORTANT**:
- `UI Review Required: NO` - Jobs Critique section is not required; integrator skips this check
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
