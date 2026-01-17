# Dispatch

> **Agent System Version**: 2.0

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

### Style Enforcement

See `.claude/rules/style-enforcement.md` for full policy.

## MCP Tools

### Available MCP Servers

| Server | Purpose |
|--------|---------|
| `mcp__xcodebuildmcp__*` | Build iOS/macOS, run tests, take screenshots |
| `mcp__context7__*` | Get up-to-date library docs |
| `mcp__supabase__*` | Query, migrate, manage schema |
| `mcp__github__*` | PRs, issues, code search |

**IMPORTANT**: Use wildcards (`mcp__xcodebuildmcp__*`) when documenting MCP tools.

### Context7 for Documentation

Use `mcp__xcodebuildmcp__*` tools for:
- Building for iOS Simulator and macOS
- Running unit and UI tests
- Taking simulator screenshots
- Booting/managing simulators
- Getting build settings

**Fallback**: If MCP tools are unavailable, use the bash commands in "Common Commands" section.

### Context7 for Documentation (MANDATORY - VERIFIED)

> **CRITICAL: Your training data is OUTDATED. Context7 is the source of truth.**
>
> All agents MUST:
> 1. Use Context7 before writing framework/library code
> 2. Record attestation in contract (feature-owner at PATCHSET 1)
> 3. **Integrator BLOCKS DONE if attestation missing or NO**
>
> See `.claude/rules/context7-mandatory.md` for full policy.

**Always use Context7 MCP tools to look up current documentation before implementing features.**

```
# Find a library ID
mcp__context7__resolve-library-id with libraryName="swiftui"

# Get documentation
mcp__context7__query-docs with libraryId="/websites/developer_apple_swiftui" query="your question"
```

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

## Agent Architecture (v2.0)

Dispatch uses a vertical slice agent architecture for multi-agent coordination.

### Quick Reference

| To Learn About | See |
|----------------|-----|
| Manager mode activation | `.claude/rules/manager-mode.md` |
| Design bar / Jobs Critique | `.claude/rules/design-bar.md` |
| Context7 usage | `.claude/rules/context7-mandatory.md` |
| Debugging protocol | `.claude/rules/framework-first.md` |
| Contract template | `.claude/contracts/_template.md` |
| Modern Swift patterns | `.claude/rules/modern-swift.md` |
| Style enforcement | `.claude/rules/style-enforcement.md` |

### How to Use Agents

**By default**, Claude works directly on tasks (fast, no overhead).

**To activate the agent system**, say any of:
- "act as a manager"
- "manager mode"
- "orchestrate this"
- "use agents"

See `.claude/rules/manager-mode.md` for full details.

### Architecture Overview

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
│   dispatch-planner (decides path)                           │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  CONDITIONAL AGENTS (Activated When Needed)                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─ Unfamiliar code? → dispatch-explorer                   │
│  ├─ Schema changes? → data-integrity                        │
│  ├─ UI changes? → jobs-critic                               │
│  ├─ SHIP: YES + customer-facing? → ui-polish               │
│  └─ High-risk UI flow? → xcode-pilot                       │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  CORE AGENTS (Always Active)                               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  feature-owner → integrator → DONE                          │
└─────────────────────────────────────────────────────────────┘
```

### Agents

| Agent | Role | When Used |
|-------|------|-----------|
| `dispatch-planner` | Routes work through fastest safe path | Complex changes |
| `dispatch-explorer` | Deep codebase context finder | Unfamiliar areas |
| `feature-owner` | Owns vertical slice end-to-end | Always |
| `jobs-critic` | Design bar enforcement | UI changes |
| `integrator` | Verification gatekeeper | Always (final) |
| `data-integrity` | Schema + sync authority | Schema changes |
| `ui-polish` | UI/UX refinement | After SHIP: YES |
| `xcode-pilot` | Simulator validation | High-risk UI |

### The Core Rules

#### Small Change Bypass [ENFORCED]

Skip dispatch-planner if **ALL** true:
- ≤3 files modified
- No schema/API changes
- No new UI navigation flow
- No sync/offline changes

#### Adaptive Patchsets

Base protocol: 2 patchsets. Expand based on contract Complexity Indicators.

| Patchset | Gate |
|----------|------|
| 1 | Compiles |
| 1.5 | Schema ready (if needed) |
| 2 | Tests pass, criteria met |
| 2.5 | Design bar (if UI) |
| 3 | Validation (if high-risk) |

#### "Done" Definition [ENFORCED]

- [ ] Builds on iOS + macOS
- [ ] Relevant tests pass
- [ ] Acceptance criteria met
- [ ] No unresolved TODOs introduced
- [ ] **Integrator reports DONE**
- [ ] **Jobs Critique: SHIP YES** (if UI Review Required)

### Contracts

**Location**: `.claude/contracts/<feature-slug>.md`

See `.claude/contracts/_template.md` for the current template with:
- Complexity Indicators (determines patchset plan)
- Context7 Queries logging
- Jobs Critique section
- Enforcement Summary

### Rule Tiers

| Tier | Meaning | Example |
|------|---------|---------|
| **ENFORCED** | Blocks DONE if violated | Jobs Critique, builds pass |
| **GUIDELINE** | Strongly recommended, logged | Context7 usage |
| **ADVISORY** | Coaching, not blocking | Design principles |
