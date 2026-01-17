# Dispatch

Dispatch is a Swift multi-platform app (iOS, iPadOS, macOS) with a Supabase backend.

## Architecture

- **Language**: Swift 5
- **UI Framework**: SwiftUI
- **Backend**: Supabase (Postgres + Auth + Realtime)
- **Build System**: Xcode 16+
- **Package Manager**: Swift Package Manager

## Key Directories

- `Dispatch/` - Main app source code
- `DispatchTests/` - Unit tests
- `DispatchUITests/` - UI tests

## Available Builds & Schemes

| Scheme | Description |
|--------|-------------|
| `Dispatch` | Main application |
| `DispatchTests` | Unit test bundle |
| `DispatchUITests` | UI test bundle |

### Supported Platforms & Destinations

| Platform | Destination | Deployment Target |
|----------|-------------|-------------------|
| iOS | `platform=iOS Simulator,name=iPhone 17` | iOS 18.0+ |
| iPadOS | `platform=iOS Simulator,name=iPad Pro 13-inch (M5)` | iOS 18.0+ |
| macOS | `platform=macOS` | macOS 15.0+ |

### Build Configurations

- **Debug**: Development builds with debugging symbols
- **Release**: Optimized production builds

## Common Commands

### Building (prefer XcodeBuild MCP tools when available)

```bash
# iOS Simulator
xcodebuild -project Dispatch.xcodeproj -scheme Dispatch \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# iPad Simulator
xcodebuild -project Dispatch.xcodeproj -scheme Dispatch \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build

# macOS
xcodebuild -project Dispatch.xcodeproj -scheme Dispatch \
  -destination 'platform=macOS' build
```

### Testing

```bash
# Unit tests (iOS Simulator)
xcodebuild test -project Dispatch.xcodeproj -scheme Dispatch \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# Unit tests (macOS)
xcodebuild test -project Dispatch.xcodeproj -scheme Dispatch \
  -destination 'platform=macOS'
```

### Linting

```bash
swiftlint lint
```

### Style Enforcement (Integrator PATCHSET 4)

Integrator must run these commands at PATCHSET 4:

```bash
# 1. Format check (if swiftformat exists)
if command -v swiftformat &> /dev/null; then
  swiftformat . --lint
fi

# 2. Lint
swiftlint lint
```

- If swiftformat not found → skip with "N/A"
- If either fails → BLOCKED
- See `.claude/rules/style-enforcement.md` for policy

## MCP Tools

### Available MCP Servers

| Server | Wildcard | Purpose |
|--------|----------|---------|
| `mcp__xcodebuildmcp__*` | Xcode build, test, simulator control | Build iOS/macOS, run tests, take screenshots |
| `mcp__context7__*` | Documentation lookup | Get up-to-date library docs |
| `mcp__supabase__*` | Database operations | Query, migrate, manage schema |
| `mcp__github__*` | GitHub operations | PRs, issues, code search |

**IMPORTANT**: Use wildcards (`mcp__xcodebuildmcp__*`) when documenting MCP tools. Don't list specific method names unless you've confirmed they exist - tool names may change between MCP server versions.

### XcodeBuild MCP Usage

Use `mcp__xcodebuildmcp__*` tools for:
- Building for iOS Simulator and macOS
- Running unit and UI tests
- Taking simulator screenshots
- Booting/managing simulators
- Getting build settings

**Fallback**: If MCP tools are unavailable, use the bash commands in "Common Commands" section.

### Context7 for Documentation

**Always use Context7 MCP tools to look up current documentation before implementing features.**

```
# Find a library ID
mcp__context7__resolve-library-id with libraryName="swiftui"

# Get documentation
mcp__context7__query-docs with libraryId="/websites/developer_apple_swiftui" query="your question"
```

### Key Library IDs

| Library | Context7 ID |
|---------|-------------|
| SwiftUI | `/websites/developer_apple_swiftui` |
| Swift | `/swiftlang/swift` |
| Supabase | Use `resolve-library-id` to find |

## Code Style Guidelines

- Follow SwiftLint rules in `.swiftlint.yml`
- Use SwiftUI for all new views
- Use 2-space indentation
- Prefer `let` over `var` when possible
- Use meaningful variable and function names

## Project Documentation

- `DESIGN_SYSTEM.md` - UI patterns and components
- `DATA_SYSTEM.md` - Data flow and Supabase patterns

## Multi-Platform Development

- Support all platforms: iOS, iPadOS, macOS
- Use `#if os(iOS)` / `#if os(macOS)` for platform-specific code
- Consider iPad-specific layouts with size classes
- Test on multiple simulators before committing

## Dependencies

- **Supabase Swift** (v2.0.0+) - Backend services

---

## Agent Architecture

Dispatch uses a vertical slice agent architecture for multi-agent coordination.

### How to Use Agents

**By default**, Claude works directly on tasks (fast, no overhead).

**To activate the agent system**, say any of:
- "act as a manager"
- "manager mode"
- "orchestrate this"
- "use agents"

This triggers full orchestration: dispatch-planner → contract → feature-owner → verification.

See `.claude/rules/manager-mode.md` for details.

### Architecture Diagram

```
[Small Change?] ──Yes──→ feature-owner + integrator (immediate)
       │
      No
       ↓
dispatch-planner
  │
  ├─ dispatch-explorer (ONLY if unfamiliar area)
  │
  ├─ Interface Lock → persisted to .claude/contracts/
  │
  ├─ feature-owner (vertical slice)
  │       │
  │       ├─ PATCHSET 1-3 (with integrator feedback)
  │       │
  │       └─ PATCHSET 4 triggers jobs-critic
  │
  ├─ jobs-critic (after PATCHSET 4) → writes SHIP verdict to contract
  │
  ├─ ui-polish (after jobs-critic SHIP: YES)
  │
  ├─ xcode-pilot (simulator validation after ui-polish)
  │
  │              [WAIT for all above]
  │                      ▼
  └─ integrator (FINAL) ─────────────→ DONE
```

**Critical**: "DONE" only valid from integrator running AFTER all file-modifying agents complete.

**Principle: "One feature, one owner, one outcome."**

### Agents

| Agent | Role | Supabase Access |
|-------|------|-----------------|
| `dispatch-planner` | Orchestrator - routes work through fastest safe path | Read only |
| `dispatch-explorer` | Deep codebase context finder (conditional) | Read only |
| `feature-owner` | Owns entire vertical slice end-to-end | **Read only** |
| `jobs-critic` | Design bar enforcement - blocks DONE if SHIP: NO | None |
| `integrator` | Verification gatekeeper - checks jobs-critic verdict | None |
| `data-integrity` | Schema + sync authority | **Write/Execute** |
| `ui-polish` | UI/UX refinement specialist (only after SHIP: YES) | None |
| `xcode-pilot` | Simulator validation (after ui-polish) | None |

### The Five Rules

#### Rule A: Default Execution
Run feature-owner + integrator immediately unless risk triggers planner.

**Small Change Bypass** (skip planner if ALL true):
- ≤ 3 files modified
- No schema/API changes
- No new UI navigation flow
- No sync/offline changes

#### Rule B: Interface Lock Required When ANY True
- New state/action surface
- DTO changes
- Schema changes (DDL, indexes, constraints, RLS/policies, triggers, types)
- New UI navigation
- Sync/offline involved

#### Rule C: Strict Permissions
| Agent | Supabase Access | App Code |
|-------|-----------------|----------|
| feature-owner | **Read only** | Full edit |
| data-integrity | **Write/Execute** | Read only |
| integrator | None | Read only |

#### Rule D: "Done" Definition
- [ ] Builds on iOS + macOS
- [ ] Relevant tests pass
- [ ] Acceptance criteria met
- [ ] No unresolved TODOs introduced
- [ ] **Integrator reports DONE**

#### Rule E: Stop Conditions
Every agent must stop and escalate when:
- Contract is missing / not locked
- Lock Version changed mid-run
- Migration required but data-integrity not assigned
- Acceptance criteria cannot be met with current contract

#### Rule F: Agent Sequencing (CRITICAL)
**"DONE" is only valid from a FINAL integrator run after all file-modifying agents complete.**

```
┌─────────────────────────────────────────────────────────────┐
│  MANDATORY SEQUENCE                                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. feature-owner (PATCHSET 1-4)                            │
│           │                                                 │
│           ▼                                                 │
│  2. jobs-critic → writes "Jobs Critique: SHIP YES/NO"       │
│           │        to .claude/contracts/<feature>.md        │
│           │                                                 │
│           ├── SHIP: NO → STOP (fix issues, re-run critic)   │
│           │                                                 │
│           ▼ SHIP: YES                                       │
│  3. ui-polish (refines UI/UX)                               │
│           │                                                 │
│           ▼                                                 │
│  4. xcode-pilot (simulator validation)                      │
│           │                                                 │
│           ▼                                                 │
│  5. integrator (FINAL)                                      │
│           │                                                 │
│           ├── Reads contract, checks "Jobs Critique" field  │
│           ├── If SHIP: NO or missing → REJECT DONE          │
│           │                                                 │
│           ▼ SHIP: YES confirmed                             │
│        DONE                                                 │
└─────────────────────────────────────────────────────────────┘
```

**Why**:
- Running integrator parallel with ui-polish creates a race condition (stale snapshot)
- ui-polish changes what xcode-pilot validates
- jobs-critic verdict must be mechanically checked, not assumed

**Mechanical Enforcement**:
- jobs-critic MUST write `Jobs Critique: SHIP YES` or `Jobs Critique: SHIP NO` to contract
- integrator MUST read contract and verify `Jobs Critique: SHIP YES` before reporting DONE
- If jobs-critic field is missing or NO, integrator MUST reject DONE

**The rule**: After all file-modifying agents complete (feature-owner, ui-polish), integrator MUST run one final time AND verify jobs-critic verdict. Only this final run's "DONE" status is authoritative.

### Risk Gating

| Lane | Trigger | Behavior |
|------|---------|----------|
| **Fast Lane** | UI/state/model only, no schema | Execute immediately |
| **Guarded Lane** | Additive migration (new column w/ default, nullable) | Auto-run, must report SQL |
| **Safe Lane** | Backfills, constraints, deletes, breaking DTOs | Approval required |

### Interface Lock (Contracts)

**Location**: `.claude/contracts/<feature-slug>.md`

Contracts are versioned and committed to the repo. Template available at `.claude/contracts/_template.md`.

```markdown
## Interface Lock

**Feature**: [name]
**Status**: [draft | locked | complete]
**Lock Version**: v1

### Contract
- New/changed model fields: [list]
- DTO/API changes: [list]
- State/actions added: [list]
- Migration required: Y/N

### Acceptance Criteria (3 max)
1. [measurable outcome]

### Non-goals
- [what this feature does NOT include]

### Ownership
- feature-owner: [scope]
- data-integrity: [if needed]
```

### Patchset Protocol

feature-owner emits these markers for integrator verification:

```
PATCHSET 1: model + DTO compile
PATCHSET 2: UI wired to state
PATCHSET 3: sync + persistence
PATCHSET 4: cleanup + tests
```

Integrator runs verification on each patchset:
- PATCHSET 1: compile/typecheck
- PATCHSET 2: build iOS + macOS
- PATCHSET 3: full build + targeted tests
- PATCHSET 4: full test suite + SwiftLint + done checklist
