# No macOS Autonomous Control

> **Version**: 1.1
> **Tier**: ENFORCED (blocks agent actions)

## Core Principle

Agents MUST NOT use tools that **launch, run, or control** macOS applications. Headless build and test operations are safe and allowed.

## Prohibited Tools (UI Control - Takes Over Mac)

The following tools are NEVER permitted because they launch or control macOS apps:

| Tool | Why Prohibited |
|------|----------------|
| `mcp__xcodebuildmcp__build_run_macos` | Builds AND launches macOS app |
| `mcp__xcodebuildmcp__launch_mac_app` | Launches macOS app |
| `mcp__xcodebuildmcp__stop_mac_app` | Stops macOS app |

## Allowed Tools (Headless Operations - Safe)

These macOS tools are **permitted** because they run headlessly without UI control:

| Tool | Why Allowed |
|------|-------------|
| `mcp__xcodebuildmcp__build_macos` | Compile only, no launch |
| `mcp__xcodebuildmcp__test_macos` | Unit tests only, no UI control |

## Allowed Tools (iOS/iPadOS Simulators)

These simulator-only tools are also permitted:

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

The distinction is between **headless operations** and **UI control**:

- **Headless operations** (allowed): `build_macos` compiles code, `test_macos` runs unit tests. These do not launch apps or take over the user's screen.
- **UI control** (prohibited): `build_run_macos`, `launch_mac_app`, `stop_mac_app` launch visible applications that take over the Mac's display and require user interaction.

iOS/iPadOS simulator control is sandboxed and safe, so all simulator tools remain permitted.

## Enforcement

- Agent tool lists MUST NOT include prohibited tools
- Agent tool lists SHOULD include allowed headless macOS tools for cross-platform verification
- Integrator verifies both iOS + macOS builds
- Violations of prohibited tools are blocking errors
