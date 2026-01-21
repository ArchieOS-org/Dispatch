## Interface Lock

**Feature**: Fix Multiple Simulator Spawning Issue
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
- [x] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators (documentation-only change):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Documentation compiles (markdown valid) | feature-owner |
| 2 | All criteria met, no broken links | feature-owner, integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

### Problem Statement

When agents with simulator access run, multiple simulators spawn simultaneously because:

1. **No `session-set-defaults` usage** - Device selection is inline in commands rather than set once at session start
2. **No "check before boot" protocol** - Agents do not verify if a simulator is already running before booting
3. **No simulator lifecycle management** - No cleanup procedures, no reuse patterns documented
4. **jobs-critic tool inconsistency** - Has `screenshot`/`describe_ui` tools but no explicit rule preventing simulator boot

### Acceptance Criteria (3 max)

1. xcode-pilot.md includes "Simulator Session Protocol" requiring `list_sims` check before `boot_sim` and mandatory `session-set-defaults` usage
2. no-macos-control.md includes "Simulator Coordination Protocol" documenting single-simulator rule and check-before-boot requirement
3. jobs-critic.md explicitly documents that it MUST NOT boot simulators; can only use `screenshot`/`describe_ui` if simulator already running

### Non-goals (prevents scope creep)

- No changes to agent tool permissions (tools stay in agent definitions as-is)
- No new MCP tool development
- No changes to manager-mode task sequencing (already has xcode-pilot running last)
- No automated enforcement (documentation-only for now)

### Compatibility Plan

- **Backward compatibility**: N/A (documentation changes only)
- **Default when missing**: N/A
- **Rollback strategy**: Git revert

---

### Ownership

- **feature-owner**: Update all 3 documentation files per acceptance criteria
- **data-integrity**: Not needed

---

### Files to Modify

| File | Change |
|------|--------|
| `.claude/agents/xcode-pilot.md` | Add "Simulator Session Protocol" section with check-before-boot and session-set-defaults requirements |
| `.claude/rules/no-macos-control.md` | Add "Simulator Coordination Protocol" section documenting single-simulator rule |
| `.claude/agents/jobs-critic.md` | Add explicit note that jobs-critic MUST NOT boot simulators |

---

### Detailed Requirements

#### 1. xcode-pilot.md - Simulator Session Protocol

Add new section after "# Role" with these requirements:

```markdown
## Simulator Session Protocol [ENFORCED]

Before any simulator operation, xcode-pilot MUST follow this protocol:

### Step 1: Set Session Defaults (ONCE per session)
```
mcp__xcodebuildmcp__session-set-defaults with:
- simulatorName: "iPhone 17" (canonical iOS target)
- OR simulatorId: [specific UUID if needed]
```

### Step 2: Check Before Boot (EVERY TIME)
Before calling `boot_sim`:
1. Call `list_sims` to get current simulator state
2. Check if target simulator is already "Booted"
3. If already booted: SKIP boot_sim, proceed to build/install
4. If not booted: Call boot_sim

### Step 3: Reuse Running Simulator
- NEVER boot a second simulator
- If a different simulator is running, either:
  a) Use it if compatible (iOS device)
  b) Document why a different simulator is required

### Canonical Simulator Target
- **iOS validation**: iPhone 17
- **iPadOS validation**: iPad Pro 13-inch (M5)
- ONE simulator at a time, period
```

#### 2. no-macos-control.md - Simulator Coordination Protocol

Add new section after "## Restricted Tools":

```markdown
## Simulator Coordination Protocol [ENFORCED]

### Single Simulator Rule
Only ONE simulator may be running at any time during agent operations.

### Check-Before-Boot Requirement
Any agent with access to `boot_sim` MUST:
1. Call `list_sims` first
2. Check if any simulator is already booted
3. Reuse existing booted simulator if compatible
4. Only boot if no simulator is running

### Session Defaults Requirement
Agents with simulator access SHOULD call `session-set-defaults` at the start of their work to lock in the target simulator, preventing inconsistent device targeting.

### Why This Matters
Multiple simultaneous simulators:
- Consume excessive system resources
- Create visual disruption (multiple windows)
- Cause race conditions in app installation
- Make logs harder to trace
```

#### 3. jobs-critic.md - Simulator Restriction

Add explicit note in the tools section or after "# Critique Process":

```markdown
## Simulator Access Restriction [ENFORCED]

jobs-critic has access to `screenshot` and `describe_ui` tools for visual inspection, but:

- **MUST NOT** call `boot_sim`, `open_sim`, or `build_run_sim`
- **MUST NOT** launch a simulator
- **MAY ONLY** use screenshot/describe_ui if a simulator is ALREADY running (booted by xcode-pilot)
- If no simulator is running, jobs-critic evaluates design from code review only

This restriction exists because jobs-critic runs BEFORE xcode-pilot in the agent sequence. Booting a simulator would violate the single-simulator rule and the sequencing protocol.
```

---

### Context7 Queries

N/A - This is a documentation-only change. No framework code involved.

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: N/A
**Libraries Queried**: N/A

| Query | Pattern Used |
|-------|--------------|
| N/A - documentation only | N/A |

**N/A**: Valid for pure documentation changes with no framework/library usage.

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A (UI Review Required: NO)
**Reviewed**: N/A

#### Checklist

N/A - No UI changes

#### Verdict Notes

Not applicable - this is a documentation-only change affecting agent behavior rules.

---

**IMPORTANT**:
- `UI Review Required: NO` - integrator skips Jobs Critique check
- Context7 Attestation is N/A for pure documentation changes
- This is a documentation-only contract - no code changes required
