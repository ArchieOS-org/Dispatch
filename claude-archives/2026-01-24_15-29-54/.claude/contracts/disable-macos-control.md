## Interface Lock

**Feature**: Disable macOS Autonomous Control
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

None checked - this is a documentation/configuration change only.

### Patchset Plan

Based on checked indicators (none):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | All file changes complete | feature-owner |
| 2 | Verification complete | integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

### Acceptance Criteria (3 max)

1. No agent has `build_macos` or `test_macos` in their tools list
2. CLAUDE.md and agent files reference "iOS" instead of "iOS + macOS" for build requirements
3. `.claude/rules/no-macos-control.md` exists and explicitly prohibits macOS control

### Non-goals (prevents scope creep)

- Do NOT modify any Swift source code
- Do NOT change xcodebuild commands in CLAUDE.md (those are for human use)
- Do NOT remove macOS as a supported platform from the app itself

### Compatibility Plan

- **Backward compatibility**: N/A (documentation change only)
- **Default when missing**: N/A
- **Rollback strategy**: Revert the commit

---

### Ownership

- **feature-owner**: All file modifications (agent configs, CLAUDE.md, new rule file)
- **data-integrity**: Not needed

---

### Files to Modify

| File | Action | Changes |
|------|--------|---------|
| `.claude/agents/integrator.md` | MODIFY | Remove `build_macos`, `test_macos` from tools; update PATCHSET 2 from "iOS + macOS" to "iOS" |
| `.claude/agents/feature-owner.md` | MODIFY | Remove `build_macos` from tools; update done checklist from "iOS + macOS" to "iOS" |
| `.claude/agents/ui-polish.md` | MODIFY | Remove `build_macos` from tools |
| `CLAUDE.md` | MODIFY | Update line 310 from "Builds on iOS + macOS" to "Builds on iOS" |
| `.claude/rules/no-macos-control.md` | CREATE | Explicit prohibition rule |

---

### Context7 Queries

N/A - This is a documentation/configuration change with no framework/library code.

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: N/A
**Libraries Queried**: N/A

| Query | Pattern Used |
|-------|--------------|
| N/A - pure documentation change | N/A |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A (UI Review not required)
**Reviewed**: N/A

#### Checklist

N/A - No UI changes

#### Verdict Notes

UI Review Required is NO. Jobs Critique is not applicable.

---

### Implementation Notes

**Rule content for `.claude/rules/no-macos-control.md`**:

```markdown
# No macOS Autonomous Control

> **Version**: 1.0
> **Tier**: ENFORCED (blocks agent actions)

## Core Prohibition

Agents MUST NOT use any MCP tools that control, build, test, or interact with macOS directly.

## Prohibited Tools

The following tools are NEVER permitted for agents:

| Tool | Why Prohibited |
|------|----------------|
| `mcp__xcodebuildmcp__build_macos` | Direct macOS build control |
| `mcp__xcodebuildmcp__test_macos` | Direct macOS test control |
| `mcp__xcodebuildmcp__build_run_macos` | Launch macOS app |
| `mcp__xcodebuildmcp__launch_mac_app` | Launch macOS app |
| `mcp__xcodebuildmcp__stop_mac_app` | Stop macOS app |

## Allowed Tools (iOS/iPadOS Only)

These simulator-only tools are permitted:

| Tool | Platform |
|------|----------|
| `mcp__xcodebuildmcp__build_sim` | iOS/iPadOS Simulator |
| `mcp__xcodebuildmcp__build_run_sim` | iOS/iPadOS Simulator |
| `mcp__xcodebuildmcp__test_sim` | iOS/iPadOS Simulator |
| `mcp__xcodebuildmcp__screenshot` | iOS/iPadOS Simulator only |
| `mcp__xcodebuildmcp__describe_ui` | iOS/iPadOS Simulator only |
| `mcp__xcodebuildmcp__boot_sim` | iOS/iPadOS Simulator |
| `mcp__xcodebuildmcp__list_sims` | List simulators |

## Screenshot Restriction

Agents MUST NOT take screenshots on macOS. Screenshots are only permitted on iOS/iPadOS simulators.

## Rationale

macOS autonomous control poses security and stability risks:
- Agents should not launch or stop applications on the host machine
- Build verification for macOS should be done by human developers
- iOS/iPadOS simulator control is sandboxed and safe

## Enforcement

- Agent tool lists MUST NOT include prohibited tools
- Integrator verifies iOS build only (not macOS)
- Violations are blocking errors
```

---

**IMPORTANT**:
- If `UI Review Required: YES` → integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` → Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO → integrator MUST reject DONE
- **Context7 Attestation**: N/A for this pure documentation change
