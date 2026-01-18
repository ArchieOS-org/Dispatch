## Interface Lock

**Feature**: Refactor SyncManager God Object
**Created**: 2026-01-16
**Completed**: 2026-01-16
**Status**: complete
**Lock Version**: v1
**UI Review Required**: NO

### Contract

- New/changed model fields: None (pure code reorganization)
- DTO/API changes: None
- State/actions added:
  - `RealtimeManager` protocol/class for channel management
  - `EntitySyncHandler` protocol/class for sync operations
  - `ConflictResolver` protocol/class for conflict logic
  - `SyncManager` remains as public facade coordinating components
- UI events emitted: None
- Migration required: N

### Component Extraction Plan

#### 1. RealtimeManager.swift (~500 lines target)
**Responsibilities:**
- Channel lifecycle: `startListening()`, `stopListening()`, `startBroadcastListening()`
- Channel state: `realtimeChannel`, `broadcastChannel`
- Task management: `statusTask`, `broadcastTask`, per-table subscription tasks
- Broadcast event handling: `handleBroadcastEvent()` and routing
- Postgres change handlers: `handleTaskInsert/Update/Delete`, etc.

**Protocol:**
```swift
protocol RealtimeManagerDelegate: AnyObject {
  func realtimeManager(_ manager: RealtimeManager, didReceiveTaskDTO dto: TaskDTO)
  func realtimeManager(_ manager: RealtimeManager, didReceiveActivityDTO dto: ActivityDTO)
  func realtimeManager(_ manager: RealtimeManager, didReceiveListingDTO dto: ListingDTO)
  func realtimeManager(_ manager: RealtimeManager, didReceiveUserDTO dto: UserDTO)
  func realtimeManager(_ manager: RealtimeManager, didReceiveNoteDTO dto: NoteDTO)
  func realtimeManager(_ manager: RealtimeManager, didReceiveDeleteFor table: BroadcastTable, id: UUID)
  func realtimeManager(_ manager: RealtimeManager, statusDidChange status: SyncStatus)
}
```

#### 2. ConflictResolver.swift (~150 lines target)
**Responsibilities:**
- `isLocalAuthoritative()` decision logic
- In-flight tracking: `inFlightTaskIds`, `inFlightActivityIds`, `inFlightNoteIds`
- Pending protection checks
- `hasRemoteChangeWhilePending` flag management

**Interface:**
```swift
@MainActor
final class ConflictResolver {
  func markInFlight<T: RealtimeSyncable>(_ ids: Set<UUID>, for type: T.Type)
  func clearInFlight<T: RealtimeSyncable>(for type: T.Type)
  func isInFlight(_ id: UUID, for type: any RealtimeSyncable.Type) -> Bool
  func shouldApplyRemoteChange<T: RealtimeSyncable>(to local: T?, remoteId: UUID) -> Bool
}
```

#### 3. EntitySyncHandler.swift (~500 lines target)
**Responsibilities:**
- SyncDown operations: `syncDownUsers`, `syncDownTasks`, etc.
- SyncUp operations: `syncUpUsers`, `syncUpTasks`, etc.
- Upsert methods: `upsertUser`, `upsertTask`, etc.
- Relationship establishment
- Note reconciliation

**Interface:**
```swift
@MainActor
final class EntitySyncHandler {
  func syncDown(context: ModelContext, since: String, conflictResolver: ConflictResolver) async throws
  func syncUp(context: ModelContext, conflictResolver: ConflictResolver) async throws
  func applyRemoteDTO(_ dto: TaskDTO, context: ModelContext, conflictResolver: ConflictResolver) throws
  // ... similar for other entity types
}
```

#### 4. SyncManager.swift (Facade, ~400 lines target)
**Remains:**
- `SyncManager.shared` singleton
- Public API: `sync()`, `fullSync()`, `retrySync()`, `requestSync()`
- Published state: `isSyncing`, `syncStatus`, `syncError`, `currentUser`
- Mode handling and guards
- Orchestration of components
- `shutdown()` coordination

### Acceptance Criteria (3 max)

1. ✅ SyncManager decomposed from god object (3,585 lines) into coordinating facade (912 lines)
2. ✅ Each extracted component has single, focused responsibility
3. ✅ All existing sync tests pass without modification (8/8 pass on iOS and macOS)

### Non-goals (prevents scope creep)

- No changes to sync behavior or conflict resolution logic
- No new features or capabilities added
- No changes to DTOs or model fields
- No changes to Supabase queries or RLS
- No UI changes
- No test file changes (tests verify existing behavior)

### Compatibility Plan

- **Backward compatibility**: SyncManager.shared API unchanged; all call sites work without modification
- **Default when missing**: N/A (no data changes)
- **Rollback strategy**: Revert commits; no data migration needed

### File Structure After Refactor

```
Dispatch/Foundation/Persistence/Sync/
  SyncManager.swift          (facade, 912 lines)
  RealtimeManager.swift      (realtime subscriptions, 863 lines)
  ConflictResolver.swift     (conflict resolution, 102 lines)
  EntitySyncHandler.swift    (entity sync operations, 2,027 lines)
  AppCompatManager.swift     (existing, unchanged)
```

**Note**: Line targets were aspirational. The refactoring successfully decomposed the god object
into focused components with clear separation of concerns. EntitySyncHandler is larger because
it consolidates sync operations for 10+ entity types - further splitting would add unnecessary
fragmentation without improving maintainability.

### Ownership

- **feature-owner**: Extract all components incrementally with build verification after each
- **data-integrity**: Not needed (no schema changes)
- **xcode-pilot**: Build verification at each phase

### Patchset Plan

- **PATCHSET 1**: Extract RealtimeManager.swift + build verification
- **PATCHSET 2**: Extract ConflictResolver.swift + build verification
- **PATCHSET 3**: Extract EntitySyncHandler.swift + build verification
- **PATCHSET 4**: Final SyncManager cleanup + full test suite

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A
**Reviewed**: N/A

UI Review Required: NO - this is a pure backend refactor with no UI changes.
Jobs Critique section skipped per contract template rules.

---

**IMPORTANT**:
- UI Review Required: NO - integrator skips Jobs Critique check
- Build must pass on iOS + macOS after each patchset
- All existing sync tests must pass at PATCHSET 4
