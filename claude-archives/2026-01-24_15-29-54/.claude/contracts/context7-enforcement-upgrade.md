## Interface Lock

**Feature**: Context7 Enforcement Upgrade (GUIDELINE to MANDATORY)
**Created**: 2026-01-24
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

Based on checked indicators (no special indicators - base protocol):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Documentation compiles/valid | feature-owner |
| 2 | All files updated, criteria met | feature-owner, integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None (agent rules only)
- State/actions added: None
- Migration required: N

### Acceptance Criteria (3 max)

1. Context7 enforcement tier upgraded from GUIDELINE to MANDATORY in `context7-mandatory.md`
2. Contract template includes per-agent Context7 Report table (Required Libraries + Agent Reports subsections)
3. Integrator blocks DONE if Context7 reports missing or attestation is NO (when applicable)

### Non-goals (prevents scope creep)

- No changes to how Context7 tools work
- No changes to Context7 MCP server configuration
- No changes to build/test commands

### Compatibility Plan

- **Backward compatibility**: Existing contracts without new sections will need manual update or creation of new contracts
- **Default when missing**: Integrator treats missing Context7 section as BLOCKED (forces attestation)
- **Rollback strategy**: Revert the 4-5 files to previous versions

---

### Ownership

- **feature-owner**: All rule file updates (context7-mandatory.md, _template.md, manager-mode.md, agent definitions)
- **data-integrity**: Not needed

---

### Files to Modify

| File | Changes |
|------|---------|
| `.claude/rules/context7-mandatory.md` | Upgrade tier from GUIDELINE to MANDATORY; add per-agent reporting rules |
| `.claude/contracts/_template.md` | Add Context7 Attestation section with Required Libraries table and Agent Reports subsections |
| `.claude/rules/manager-mode.md` | Add Context7 reminder in agent prompts |
| `.claude/agents/feature-owner.md` | Update to require Context7 report table entry |
| `.claude/agents/integrator.md` | Update to block DONE if reports missing |
| `.claude/agents/ui-polish.md` | Add Context7 reporting requirement when making code changes |
| `.claude/agents/swift-debugger.md` | Add Context7 reporting requirement for framework investigations |

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

- N/A: This is a documentation-only change with no framework/library code

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: N/A
**Libraries Queried**: N/A (documentation-only change, no framework/library code)

| Query | Pattern Used |
|-------|--------------|
| N/A | Pure documentation update |

**N/A**: Valid - this is a pure rules/documentation refactor with no framework/library usage.

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A
**Reviewed**: N/A

#### Checklist

N/A - No UI changes

#### Verdict Notes

UI Review Required: NO - This is a documentation/rules update only.

---

**IMPORTANT**:
- If `UI Review Required: YES` → integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` → Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO → integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` → integrator MUST reject DONE

---

### Seoul Approach Reference

The upgrade should match Seoul project's implementation:

1. **Contract-based tracking with per-agent tables**:
   - "Required Libraries" table filled by planner
   - "Agent Reports" subsections for each agent to fill

2. **Agent-specific requirements**:
   - feature-owner: MUST report all API usage in contract table
   - ui-polish: Reports if making code changes
   - swift-debugger: Reports framework investigations
   - integrator: Verifies reports are filled, blocks DONE if missing

3. **Manager-mode prompt updates**:
   - Include "Check Context7 for ALL APIs" in every agent prompt

4. **Enforcement tier change**:
   - From: GUIDELINE (logged, not blocking)
   - To: MANDATORY (blocking - integrator rejects DONE if missing)
