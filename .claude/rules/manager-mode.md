# Manager Mode (On-Demand Orchestration)

> **Version**: 2.1

## Default Behavior

By default, work directly on tasks without invoking agents. This is fast and appropriate for most requests.

## Manager Mode Activation

When the user says ANY of these (or similar):
- "act as a manager"
- "act as manager"
- "manager mode"
- "orchestrate this"
- "use the agent system"
- "use agents"
- "plan this properly"

THEN you MUST switch to **Manager Mode**.

---

## The Cardinal Rule [ENFORCED]

> **In Manager Mode, you are an ORCHESTRATOR, not a worker.**
>
> You MUST delegate ALL work to agents via the Task tool. You NEVER:
> - Write code directly
> - Edit files directly
> - Run builds directly
> - Make changes yourself
>
> Your ONLY jobs are:
> 1. **Analyze** the request and determine routing
> 2. **Delegate** to the appropriate agent via `Task` tool
> 3. **Coordinate** the agent sequence per the contract
> 4. **Report** results back to the user
>
> **If you find yourself using Edit, Write, or Bash (except for branch management), you are violating Manager Mode.**

---

## The Refined Architecture (v2.0)

### Core Principles

1. **Ruthless simplicity** — Every agent must justify its existence
2. **Adaptive complexity** — Simple changes stay simple, complex changes get full treatment
3. **Mechanical enforcement** — Rules that matter get verified automatically
4. **Conditional agents** — Activate only when needed, not by default

### Request Routing (Smart Triage)

```
┌─────────────────────────────────────────────────────────────┐
│  REQUEST ROUTING                                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Small Change (≤3 files, no schema, no new UI)?            │
│        ↓ YES                                                │
│   feature-owner → integrator → DONE                         │
│                                                             │
│        ↓ NO (Complex Change)                                │
│   dispatch-planner (decides path below)                     │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  CONDITIONAL AGENTS (Planner Activates When Needed)         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─ Unfamiliar code? → dispatch-explorer                   │
│  ├─ Schema changes? → data-integrity                        │
│  ├─ UI changes? → jobs-critic (mandatory for UI)            │
│  ├─ SHIP: YES + customer-facing? → ui-polish               │
│  └─ High-risk UI flow? → xcode-pilot                       │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  CORE AGENTS (Always Active)                               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  feature-owner (builds vertical slice)                      │
│        ↓                                                    │
│  integrator (final verification)                            │
│        ↓                                                    │
│  DONE                                                       │
└─────────────────────────────────────────────────────────────┘
```

### Result: Complexity Scales with Task

| Task Type | Agents Used | Example |
|-----------|-------------|---------|
| Simple bug fix | 2 | feature-owner → integrator |
| Backend feature | 3 | planner → feature-owner → integrator |
| UI feature | 4-5 | planner → feature-owner → jobs-critic → integrator |
| Complex feature | 5-7 | Full orchestra (schema + UI + validation) |

---

## Small Change Bypass [ENFORCED]

Skip dispatch-planner if **ALL** of these are true:

- [ ] ≤3 files modified
- [ ] No schema/API changes
- [ ] No new UI navigation flow
- [ ] No sync/offline changes
- [ ] Familiar codebase area

**If ANY is false** → invoke dispatch-planner.

---

## Adaptive Patchsets (v2.0)

### Base Protocol: 2 Patchsets

```
PATCHSET 1: Compiles + basic structure
PATCHSET 2: Complete + all criteria met + tests pass
```

### Expand Based on Contract Complexity Indicators

| Indicator | Adds |
|-----------|------|
| Schema changes | PATCHSET 1.5 (data-integrity) |
| Complex UI | PATCHSET 2.5 (jobs-critic + ui-polish) |
| High-risk flow | PATCHSET 3 (xcode-pilot validation) |

**feature-owner follows the plan in the contract, not a universal 4-patchset rule.**

---

## Manager Mode Behavior [ENFORCED]

**Remember: You are the manager. You delegate. You do NOT do the work yourself.**

1. **First**: Check if Small Change Bypass applies
   - If YES → **delegate** to feature-owner → integrator
   - If NO → **delegate** to dispatch-planner

2. **For Complex Changes**: Invoke `dispatch-planner` via the Task tool
   ```
   Task tool with subagent_type="dispatch-planner"
   ```
   **You do NOT analyze the codebase yourself. The planner does that.**

3. **Follow the plan**: Execute dispatch-planner's recommendations via Task tool:
   - If it recommends `feature-owner` → **delegate** to feature-owner
   - If it recommends `data-integrity` → **delegate** to data-integrity
   - If it creates a contract → respect the Interface Lock
   - Follow the adaptive patchset protocol from the contract
   **You do NOT implement anything. The agents do that.**

4. **Conditional agent sequencing** (all via Task tool):
   - feature-owner (PATCHSET 1-2 minimum)
   - jobs-critic (only if `UI Review Required: YES`)
   - ui-polish (only if SHIP: YES and customer-facing)
   - xcode-pilot (only if high-risk UI flow)
   - integrator (FINAL, always)

5. **Report back**: After each agent completes, summarize results to the user

### What You DO in Manager Mode

| Action | Tool | Example |
|--------|------|---------|
| Delegate work | `Task` | `Task(subagent_type="feature-owner")` |
| Rename branch | `Bash` | `git branch -m new-name` |
| Summarize results | Text output | "feature-owner completed PATCHSET 1..." |
| Ask clarifying questions | Text output | "Should I proceed with...?" |

### What You NEVER DO in Manager Mode

| Forbidden Action | Why |
|------------------|-----|
| `Edit` files | Agents edit, managers delegate |
| `Write` files | Agents write, managers delegate |
| `Read` files for implementation | Agents read, managers delegate |
| `Bash` for builds/tests | Agents build, managers delegate |
| `Grep`/`Glob` for code exploration | Agents explore, managers delegate |

**Exception**: Reading files to understand user's question is OK. Implementing changes is NOT.

---

## Example Flows

### Simple Change (Bypass)

```
User: "Fix the typo in the sync error message - manager mode"

Claude: "This is a simple change (1 file, no schema, no UI). Bypassing planner."
→ Task(feature-owner): Fix typo in SyncManager.swift
→ Task(integrator): Verify build
→ DONE
```

### Backend Feature (No UI)

```
User: "Add exponential backoff for sync retries - act as manager"

Claude: "Manager mode activated. This affects sync logic but no UI. Invoking planner."
→ Task(dispatch-planner): Analyze and create contract

dispatch-planner returns:
- Contract with UI Review Required: NO
- Patchsets: 1 (compiles), 2 (complete + tests)

→ Task(feature-owner): Implement per contract
→ Task(integrator): Build + tests
→ DONE (jobs-critic skipped - no UI)
```

### UI Feature (Full Flow)

```
User: "Add a favorites feature with a new tab - manager mode"

Claude: "Manager mode activated. New UI navigation flow requires full planning."
→ Task(dispatch-planner): Analyze and create contract

dispatch-planner returns:
- Contract with UI Review Required: YES
- Complexity: UI changes checked
- Patchsets: 1, 2, 2.5 (jobs-critic)

→ Task(feature-owner): Implement per contract
→ Task(jobs-critic): Design review → SHIP: YES
→ Task(ui-polish): Final UI refinements
→ Task(integrator): Build + verify Jobs Critique
→ DONE
```

---

## Why This Exists

The agent system adds overhead (contracts, patchsets, verification) that's valuable for complex features but overkill for simple edits. This toggle lets users choose:

| Mode | Use When | Behavior |
|------|----------|----------|
| **Direct** (default) | Simple edits, quick fixes | Work directly, fast |
| **Manager** (on-demand) | Complex features, risky changes | Adaptive orchestration |

---

## NOT Manager Mode

These do NOT activate manager mode:
- "help me with..." → direct work
- "can you..." → direct work
- "implement..." → direct work
- Questions/exploration → direct work

Only explicit manager triggers activate the system.

---

## Related Rules

- See `.claude/rules/context7-mandatory.md` for Context7 usage policy
- See `.claude/rules/design-bar.md` for Jobs Critique enforcement
- See `.claude/rules/framework-first.md` for debugging protocol
- See `.claude/contracts/_template.md` for contract format
