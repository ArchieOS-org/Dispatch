## Interface Lock

**Feature**: SharedBackend Swift Package
**Created**: 2026-01-16
**Status**: locked
**Lock Version**: v1
**UI Review Required**: NO

### Contract

- New/changed model fields: None (package creates new types, no app model changes)
- DTO/API changes:
  - New `BackendConfig` protocol for config injection
  - New `Backend` class wrapping SupabaseClient
  - New service protocols: `AuthServiceProtocol`, `DatabaseServiceProtocol`, `StorageServiceProtocol`, `RealtimeServiceProtocol`
- State/actions added:
  - `Backend.shared` singleton replaced by injected `Backend(config:)`
  - App-level `AppBackend` conforming to config
- UI events emitted: None
- Migration required: N

### Acceptance Criteria (3 max)

1. SharedBackend package at `/Packages/SharedBackend` compiles standalone with `swift build`
2. Dispatch app builds on iOS and macOS using SharedBackend as local package dependency
3. Existing functionality (auth, sync, realtime, storage) works identically after refactor

### Non-goals (prevents scope creep)

- No refactoring of SyncManager internal logic (only update imports/references)
- No moving DTOs to SharedBackend (DTOs are app-specific)
- No moving domain models to SharedBackend
- No new features or behavior changes
- No Supabase schema changes

### Compatibility Plan

- **Backward compatibility**: Keep `var supabase: SupabaseClient` global accessor during transition
- **Default when missing**: N/A (no new fields)
- **Rollback strategy**: Remove SharedBackend package reference, restore original SupabaseService.swift

### Ownership

- **feature-owner**: Full vertical slice - package creation, service implementation, app refactor
- **data-integrity**: Not needed (no schema changes)

### Implementation Notes

**Use Context7 for**:
- Swift Package Manager best practices
- Supabase Swift SDK patterns (use `mcp__context7__resolve-library-id` with "supabase-swift")
- Protocol-oriented design in Swift

**Package Structure**:
```
/Packages/SharedBackend/
  Package.swift
  Sources/SharedBackend/
    Backend.swift
    BackendConfig.swift
    Errors/
      BackendError.swift
    Services/
      AuthService.swift
      DatabaseService.swift
      StorageService.swift
      RealtimeService.swift
```

**Key Design Decisions**:
1. Config injected at runtime via `BackendConfig` protocol - NO hardcoded URLs/keys in package
2. `Backend` class owns `SupabaseClient` and exposes typed services
3. Services are protocols with default implementations for flexibility
4. App creates `AppBackendConfig` conforming to `BackendConfig` using `Secrets.swift`
5. Platform target: iOS 18+ / macOS 15+ (aligned with app requirements)

**Files to Modify in App**:
- `Dispatch/Foundation/Networking/Supabase/SupabaseClient.swift` - refactor to use Backend
- `Dispatch/Foundation/Auth/AuthManager.swift` - use AuthService
- `Dispatch/Foundation/Persistence/Sync/SyncManager.swift` - update imports
- `Dispatch/Foundation/Persistence/Sync/AppCompatManager.swift` - update imports
- `Dispatch/App/State/SyncCoordinator.swift` - update imports
- `Dispatch/Foundation/Testing/SupabaseTestHelpers.swift` - update imports
- `Dispatch.xcodeproj/project.pbxproj` - add local package reference

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A (UI Review Required: NO)
**Reviewed**: N/A

#### Checklist
N/A - No UI changes

#### Verdict Notes
No UI review required for this infrastructure refactor.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
