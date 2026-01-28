## Interface Lock

**Feature**: [Feature Name]
**Created**: [YYYY-MM-DD]
**Status**: [draft | locked | complete]
**Lock Version**: v1 (increment on any contract change)
**UI Review Required**: NO (set YES if customer-facing UI, hierarchy/layout changes, or primary interaction changes)

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [ ] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 1.5 | Schema ready | data-integrity (if checked) |
| 2 | Tests pass, criteria met | feature-owner, integrator |
| 2.5 | Design bar | jobs-critic, ui-polish (if UI checked) |
| 3 | Validation | xcode-pilot (if high-risk checked) |

---

### Contract

- New/changed model fields: [list or "None"]
- DTO/API changes: [list or "None"]
- State/actions added: [list or "None"]
- Migration required: Y/N

### Acceptance Criteria (3 max)

1. [measurable outcome]
2. [measurable outcome]
3. [measurable outcome]

### Non-goals (prevents scope creep)

- [what this feature explicitly does NOT include]
- [example: "No new Favorites screen, no sorting changes"]

### Compatibility Plan

- **Backward compatibility**: [how older DTOs behave, or "N/A"]
- **Default when missing**: [field defaults, or "N/A"]
- **Rollback strategy**: [how to undo if needed]

---

### Ownership

- **feature-owner**: [scope]
- **data-integrity**: [if schema changes, otherwise "Not needed"]

---

### Context7 Attestation [MANDATORY]

> **Enforcement**: Integrator BLOCKS DONE if required reports are missing or CONTEXT7 CONSULTED: NO

#### Required Libraries (filled by planner or feature-owner)

| Library | Context7 ID | Why Needed |
|---------|-------------|------------|
| [e.g., SwiftUI] | [e.g., /websites/developer_apple_swiftui] | [e.g., View binding patterns] |

**N/A is only valid** for pure refactors with no framework/library usage.

---

#### Agent Reports

Each agent fills their section below. **Integrator verifies these are complete before DONE.**

##### feature-owner Report (MUST FILL)

**CONTEXT7 CONSULTED**: [YES | NO | N/A]

| Library | Query | Result |
|---------|-------|--------|
| [e.g., SwiftUI] | [what was asked] | [pattern/answer applied] |

_N/A only valid for pure refactors with zero framework code._

##### ui-polish Report (FILL IF CODE CHANGES)

**CODE CHANGES MADE**: [YES | NO]

| Library | Query | Result |
|---------|-------|--------|
| [e.g., SwiftUI] | [what was asked] | [pattern/answer applied] |

_Leave empty if no code changes (review only)._

##### swift-debugger Report (FILL IF INVOKED)

**DEBUGGING PERFORMED**: [YES | NO]

| Library | Query | Result |
|---------|-------|--------|
| [e.g., Swift] | [what was asked] | [framework pattern found] |

_Leave empty if swift-debugger not invoked._

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: [SHIP YES | SHIP NO | PENDING]
**Reviewed**: [YYYY-MM-DD HH:MM]

#### Checklist

- [ ] Ruthless simplicity - nothing can be removed without losing meaning
- [ ] One clear primary action per screen/state
- [ ] Strong hierarchy - headline → primary → secondary
- [ ] No clutter - whitespace is a feature
- [ ] Native feel - follows platform conventions

#### Verdict Notes

[jobs-critic writes specific feedback here]

---

**IMPORTANT**:
- If `UI Review Required: YES` → integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` → Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO → integrator MUST reject DONE

**Context7 Attestation [MANDATORY]**:
- Integrator MUST verify each agent's Context7 report is filled:
  - **feature-owner**: MUST have report with `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors)
  - **ui-polish**: MUST have report if `CODE CHANGES MADE: YES`
  - **swift-debugger**: MUST have report if `DEBUGGING PERFORMED: YES`
- If any required report is missing or shows `CONTEXT7 CONSULTED: NO` → integrator MUST reject DONE
- `N/A` is only valid for pure refactors with zero framework/library code
