## Interface Lock

**Feature**: [Feature Name]
**Created**: [YYYY-MM-DD]
**Status**: [draft | locked | complete]
**Lock Version**: v1 (increment on any contract change)
**UI Review Required**: NO (set YES if customer-facing UI, hierarchy/layout changes, or primary interaction changes)

### Contract
- New/changed model fields: [list]
- DTO/API changes: [list]
- State/actions added: [list]
- UI events emitted: [list]
- Migration required: Y/N

### Acceptance Criteria (3 max)
1. [measurable outcome]
2. [measurable outcome]
3. [measurable outcome]

### Non-goals (prevents scope creep)
- [what this feature explicitly does NOT include]
- [example: "No new Favorites screen, no sorting changes"]

### Compatibility Plan
- **Backward compatibility**: [how older DTOs behave]
- **Default when missing**: [field defaults]
- **Rollback strategy**: [how to undo if needed]

### Ownership
- **feature-owner**: [scope]
- **data-integrity**: [if needed]

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: [YES | NO | N/A]
**Libraries Queried**: [list or "N/A"]

| Query | Pattern Used |
|-------|--------------|
| [what was asked] | [what was applied] |

**N/A**: Only valid for pure refactors with no framework/library usage.

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
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` → integrator MUST reject DONE
