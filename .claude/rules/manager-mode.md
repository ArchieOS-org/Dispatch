# Manager Mode (On-Demand Orchestration)

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

THEN you MUST switch to **Manager Mode**:

### Manager Mode Behavior

1. **First**: Invoke `dispatch-planner` via the Task tool to analyze and route the request
   ```
   Task tool with subagent_type="dispatch-planner"
   ```

2. **Follow the plan**: Execute dispatch-planner's recommendations:
   - If it recommends `feature-owner` → invoke feature-owner
   - If it recommends `data-integrity` → invoke data-integrity
   - If it creates a contract → respect the Interface Lock
   - Follow the PATCHSET protocol

3. **Agent sequencing**: Respect the mandatory sequence:
   - feature-owner (PATCHSET 1-4)
   - jobs-critic (after PATCHSET 2 if UI changes)
   - ui-polish (if assigned, after SHIP: YES)
   - xcode-pilot (if assigned, after ui-polish)
   - integrator (FINAL)

4. **Report back**: After each agent completes, summarize results to the user

### Example Flow

```
User: "Add a favorites feature - act as manager"

Claude: "Manager mode activated. Let me invoke dispatch-planner to analyze this request."
→ Task(dispatch-planner): "Add a favorites feature for bookmarking listings"

dispatch-planner returns:
- Path: Planner (multi-file, new state)
- Contract: .claude/contracts/favorites.md
- Assignments: feature-owner, jobs-critic, integrator

Claude: "Plan ready. Creating contract and invoking feature-owner..."
→ Task(feature-owner): [implements per contract]

...continues through agent sequence...
```

## Why This Exists

The agent system adds overhead (contracts, patchsets, verification) that's valuable for complex features but overkill for simple edits. This toggle lets users choose:

| Mode | Use When | Behavior |
|------|----------|----------|
| **Direct** (default) | Simple edits, quick fixes | Work directly, fast |
| **Manager** (on-demand) | Complex features, risky changes | Full agent orchestration |

## NOT Manager Mode

These do NOT activate manager mode:
- "help me with..." → direct work
- "can you..." → direct work
- "implement..." → direct work
- Questions/exploration → direct work

Only explicit manager triggers activate the system.
