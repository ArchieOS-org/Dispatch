# Manager Mode (On-Demand Orchestration)

> **Version**: 2.2

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

## Manager Delegation Rule [ENFORCED]

**CRITICAL: In manager mode, you are an orchestrator, NOT a worker.**

### The Manager MUST Delegate via Task Tool

All work happens through agents. The manager's ONLY jobs are:
1. Assess complexity (small change bypass check)
2. Invoke agents via `Task(subagent_type="agent-name", prompt="...")`
3. Summarize agent results to user
4. Coordinate agent sequencing

### The Manager MUST NOT (When in Manager Mode)

| Action | Why Forbidden | Delegate To |
|--------|---------------|-------------|
| Read files directly | Manager doesn't explore | dispatch-explorer |
| Write/edit code | Manager doesn't implement | feature-owner |
| Call Context7 | Agents own documentation lookup | feature-owner, ui-polish |
| Run builds/tests | Manager doesn't verify | integrator |
| Create detailed todos | Agents track their own work | (agents internally) |
| Use Grep/Glob | Manager doesn't search | dispatch-explorer |

### Anti-Pattern (BAD - Manager doing work)

```
Manager: "Let me read ContentView.swift to understand the sidebar..."
Manager: "Let me query Context7 for HIG guidelines..."
Manager: "Creating a todo list for the audit..."
Manager: [Uses Read, Grep, Context7 tools directly]
```

### Correct Pattern (GOOD - Manager delegating)

**CRITICAL: For complex changes, dispatch-planner MUST be invoked FIRST to create a contract.**

```
Manager: "This is a complex UI audit. Invoking dispatch-planner to create contract."
→ Task(subagent_type="dispatch-planner", prompt="Create contract for menu/sidebar HIG audit...")

Manager: "Contract created at .claude/contracts/hig-audit.md. It specifies dispatch-explorer needed."
→ Task(subagent_type="dispatch-explorer", prompt="Find all menu and sidebar files...")

Manager: "Explorer found 15 files. Contract says feature-owner next."
→ Task(subagent_type="feature-owner", prompt="Audit per contract, use Context7 for HIG patterns...")

Manager: "Feature-owner complete. Contract requires jobs-critic (UI Review: YES)."
→ Task(subagent_type="jobs-critic", prompt="Review UI changes, write verdict to contract...")

Manager: "Jobs-critic says SHIP YES. Invoking integrator."
→ Task(subagent_type="integrator", prompt="Verify builds, check contract attestations...")
```

**The contract is the source of truth.** All agents reference it. Without a contract, there's no:
- Context7 Attestation section for feature-owner to fill
- Jobs Critique section for jobs-critic to fill
- Patchset plan for integrator to verify

### Exception: Small Change Bypass

When Small Change Bypass applies (≤3 files, no schema, no new UI), the manager MAY directly invoke feature-owner and integrator without dispatch-planner. But even then, **work happens through Task tool calls**.

---

## The Refined Architecture (v2.1)

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

## Adaptive Patchsets (v2.1)

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

## Manager Mode Behavior

### Step 1: Small Change Bypass Check

Check if ALL of these are true:
- ≤3 files modified
- No schema/API changes
- No new UI navigation flow
- No sync/offline changes
- Familiar codebase area

**If ALL true** → Skip to feature-owner → integrator (no contract needed)
**If ANY is false** → **MUST invoke dispatch-planner FIRST**

### Step 2: Complex Change Flow (dispatch-planner REQUIRED)

**CRITICAL: dispatch-planner creates the contract. Without a contract, the system breaks.**

```
Task(subagent_type="dispatch-planner", prompt="[task description]")
```

dispatch-planner will:
1. Create contract file at `.claude/contracts/<feature-slug>.md`
2. Set complexity indicators (schema, UI, high-risk, unfamiliar)
3. Define patchset plan based on indicators
4. Specify which agents are needed

### Step 3: Follow the Contract

Execute agents in order specified by the contract:

| If Contract Says | Invoke |
|------------------|--------|
| Unfamiliar area checked | dispatch-explorer first |
| Schema changes checked | data-integrity (PATCHSET 1.5) |
| Complex UI checked | jobs-critic (PATCHSET 2.5), ui-polish |
| High-risk flow checked | xcode-pilot (PATCHSET 3) |
| Always | feature-owner, integrator |

### Step 4: Agent Prompts Reference Contract

When invoking agents, reference the contract:

```
Task(subagent_type="feature-owner", prompt="Implement per contract at .claude/contracts/xyz.md.
Use Context7 for framework patterns. Fill Context7 Attestation section.")
```

### Step 5: Report Back

After each agent completes, summarize results to user before invoking next agent.

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
