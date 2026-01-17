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

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

- [library]: [question asked] → [brief pattern/answer used]

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

### Enforcement Summary

| Check | Enforced By | Consequence |
|-------|-------------|-------------|
| UI Review Required: YES → Jobs Critique | integrator | Blocks DONE if SHIP NO/PENDING |
| Lock Version changed | all agents | Must stop and re-read contract |
| Acceptance criteria met | integrator | Required for DONE |
| Context7 Queries logged | integrator | Warning if missing (not blocking) |
