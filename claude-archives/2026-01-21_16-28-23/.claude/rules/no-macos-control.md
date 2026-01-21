# Minimize Screen Takeover

> **Version**: 2.0
> **Tier**: ENFORCED (blocks agent actions)

## Core Principle

Agents MUST minimize visual disruption to the user's screen. **Prefer headless operations over tools that launch apps or simulators.**

When running many agents in parallel, simulator windows and app launches are highly disruptive.

## Prohibited Tools (macOS UI Control - NEVER)

The following tools are NEVER permitted:

| Tool | Why Prohibited |
|------|----------------|
| `mcp__xcodebuildmcp__build_run_macos` | Builds AND launches macOS app |
| `mcp__xcodebuildmcp__launch_mac_app` | Launches macOS app |
| `mcp__xcodebuildmcp__stop_mac_app` | Stops macOS app |

## Preferred Tools (Headless - No Screen Takeover)

**Always prefer these tools** because they run without visual disruption:

| Tool | Why Preferred |
|------|---------------|
| `mcp__xcodebuildmcp__build_macos` | Compile only, no launch |
| `mcp__xcodebuildmcp__build_sim` | Compile only, no simulator window |
| `mcp__xcodebuildmcp__test_macos` | Unit tests, no UI |
| `mcp__xcodebuildmcp__list_sims` | List only, no launch |

## Restricted Tools (Simulator Launch - Use Sparingly)

These tools **launch or interact with simulator windows** and should be avoided unless specifically needed for validation (xcode-pilot only):

| Tool | Impact | Use By |
|------|--------|--------|
| `mcp__xcodebuildmcp__build_run_sim` | Launches simulator + app | xcode-pilot only |
| `mcp__xcodebuildmcp__test_sim` | Launches simulator | Avoid - use test_macos |
| `mcp__xcodebuildmcp__boot_sim` | Opens simulator window | xcode-pilot only |
| `mcp__xcodebuildmcp__launch_app_sim` | Launches app in simulator | xcode-pilot only |
| `mcp__xcodebuildmcp__screenshot` | Requires running simulator | xcode-pilot only |
| `mcp__xcodebuildmcp__describe_ui` | Requires running simulator | xcode-pilot only |

## Agent Tool Assignments

| Agent | Simulator Launch Tools? | Reason |
|-------|------------------------|--------|
| integrator | NO | Verification uses headless builds + test_macos |
| feature-owner | NO | Implementation doesn't need simulator |
| swift-debugger | NO | Debugging uses code analysis + Supabase queries |
| xcode-pilot | YES | Explicitly for simulator validation |
| ui-polish | NO | UI changes verified by xcode-pilot |
| jobs-critic | NO | Design review is visual inspection only |

## Test Priority Order

1. **`test_macos`** (preferred) - headless, fast, no disruption
2. **Targeted tests** - use `-only-testing:` flag, never full suite
3. **`test_sim`** (avoid) - launches simulator, disruptive

See `integrator.md` for targeted test strategy.

## Screenshot Restriction

Agents MUST NOT take screenshots on macOS. Screenshots are only permitted via xcode-pilot on iOS/iPadOS simulators.

## Rationale

When many agents run in parallel:
- Simulator windows popping up interrupt user workflow
- Multiple simulators compete for resources
- App launches can trigger focus changes

Headless operations (builds, macOS unit tests) have zero visual impact and should always be preferred.

## Enforcement

- Agent tool lists MUST NOT include prohibited macOS tools
- Agent tool lists SHOULD NOT include simulator launch tools (except xcode-pilot)
- Integrator uses test_macos, not test_sim
- Violations of prohibited tools are blocking errors
