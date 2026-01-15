## Interface Lock

**Feature**: [Feature Name]
**Created**: [YYYY-MM-DD]
**Status**: [draft | locked | complete]
**Lock Version**: v1 (increment on any contract change)

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

### Jobs Critique (written by jobs-critic agent)

**Jobs Critique**: [SHIP YES | SHIP NO | PENDING]
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

**IMPORTANT**: integrator MUST verify `Jobs Critique: SHIP YES` before reporting DONE.
If this field is missing, says PENDING, or says SHIP NO, integrator MUST reject DONE.
