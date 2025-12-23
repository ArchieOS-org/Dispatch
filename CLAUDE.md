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
| iOS | `platform=iOS Simulator,name=iPhone 16` | iOS 18.0+ |
| iPadOS | `platform=iOS Simulator,name=iPad Pro 13-inch (M4)` | iOS 18.0+ |
| macOS | `platform=macOS` | macOS 15.0+ |

### Build Configurations

- **Debug**: Development builds with debugging symbols
- **Release**: Optimized production builds

## Common Commands

### Building (prefer XcodeBuild MCP tools when available)

```bash
# iOS Simulator
xcodebuild -project Dispatch.xcodeproj -scheme Dispatch \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# iPad Simulator
xcodebuild -project Dispatch.xcodeproj -scheme Dispatch \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build

# macOS
xcodebuild -project Dispatch.xcodeproj -scheme Dispatch \
  -destination 'platform=macOS' build
```

### Testing

```bash
# Unit tests (iOS Simulator)
xcodebuild test -project Dispatch.xcodeproj -scheme Dispatch \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# Unit tests (macOS)
xcodebuild test -project Dispatch.xcodeproj -scheme Dispatch \
  -destination 'platform=macOS'
```

### Linting

```bash
swiftlint lint
```

## Using Context7 for Documentation

**Always use Context7 MCP tools to look up current documentation before implementing features.**

```
# Find a library ID
mcp__context7__resolve-library-id with libraryName="swiftui"

# Get documentation
mcp__context7__get-library-docs with context7CompatibleLibraryID="/websites/developer_apple_swiftui" topic="your topic"
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
