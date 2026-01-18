## Interface Lock

**Feature**: Report Integration for Description Generator
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES

### Contract

#### New Models/Types
- `ReportType` enum: geoWarehouse, mpac
- `GenerationPhase` enum: idle, fetchingReport, extractingFromImages, generatingDescriptions, complete
- `FetchedReport` struct: id, type, fetchedAt, mockSummary

#### State Changes (DescriptionGeneratorState)
- `enableGeoWarehouse: Bool` - toggle for GEOWarehouse report
- `enableMPAC: Bool` - toggle for MPAC report
- `generationPhase: GenerationPhase` - tracks current generation step
- `fetchedReports: [FetchedReport]` - fetched report results
- `extractedFromImages: Bool` - indicates image extraction occurred

#### New UI Components
- `ReportToggleSection` - minimal toggles before Generate button
- `GenerationProgressView` - phased animation during generation
- Report status indicators in output section

#### Migration Required: N

### Acceptance Criteria (3 max)
1. User can toggle GEOWarehouse and MPAC reports before generation, with elegant minimal animation showing "Obtaining [Report]..." during generation
2. Output section displays fetched reports with checkmarks and ability to view/expand them
3. Visual indication shows information was extracted from uploaded photos

### Non-goals
- Actual backend integration with GEOWarehouse/MPAC APIs
- Persistent storage of report preferences
- Real report data - all content is mock/placeholder

### Ownership
- feature-owner: Full vertical slice (models, state, UI components, wiring)
- data-integrity: Not needed (no schema changes)

### Design Bar Requirements
- Ruthless simplicity: Toggles are plain toggles, progress is single-line text
- One clear primary action: Generate button remains the only primary CTA
- Strong hierarchy: Report toggles clearly secondary, output indicators minimal
- Native feel: Standard SwiftUI controls (Toggle, ProgressView, SF Symbols)

---

### Jobs Critique

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-15 14:30

#### Checklist
- [x] Ruthless simplicity - Plain toggles, single-line progress text, minimal expandable rows
- [x] One clear primary action - Generate button remains sole CTA; report toggles clearly secondary
- [x] Strong hierarchy - Headline -> caption -> controls progression; Sources section maintains hierarchy
- [x] No clutter - Generous DS.Spacing, card backgrounds create separation, icons support text
- [x] Native feel - Standard SwiftUI Toggle, system ProgressView, SF Symbols throughout

#### Execution
- DS Components: All spacing/typography/colors from design system
- Accessibility: VoiceOver labels, hints, accessibilityHidden on decorative icons
- States: Loading phases, empty handling, error display all present
- Animations: Subtle 0.2s easeInOut for disclosure; no gimmicks

#### Verdict Notes
Implementation is clean and minimal. The phased progress indicator ("Obtaining GEOWarehouse...", "Extracting from photos...", "Generating descriptions...") provides user confidence without being busy. FetchedReportRow collapse-by-default keeps output section focused on the generated descriptions. No changes required.

### Patchset Status
- [x] PATCHSET 1: Models + state compile
- [x] PATCHSET 2: UI components wired
- [x] PATCHSET 3: Generation flow updated
- [x] PATCHSET 4: Cleanup + accessibility
