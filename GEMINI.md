# Dispatch
Dispatch is a premium, multi-platform Swift application (iOS, iPadOS, macOS) built on Supabase. It synchronizes data between specific, strictly typed SwiftData models and a Postgres backend. Built to Steve Jobs standards.

## Non-negotiable Principles
1.  **The Steve Jobs Standard**: Zero glitches. Silky smooth rendering. Premium aesthetics (invisible toolbars, perfect typography). Simplicity over complexity.
2.  **One Boss Architecture**: Every domain has exactly one owner. No split authorities. Use the Command Bus (`AppCommand`) for all state changes.
3.  **Local-First / Offline-First**: The UI *always* trusts local SwiftData. Sync happens in the background. We never block the UI on network requests.

## One Boss Map
We strictly follow the **One Boss** pattern. Breaking this contract requires Architect approval.

| Domain | Boss (Owner) | Responsibilities | Forbidden |
| :--- | :--- | :--- | :--- |
| **Root Entry** | `DispatchApp` | Scene Phase, Env Injection, Root ZStack (Login/Shell) | No Business Logic here. |
| **Shell / Chrome** | `AppShellView` | Window Policy, Toolbar Background, Global Chrome | No Navigation Stacks here. |
| **Router / Container** | `ContentView` | Root `NavigationStack`, TabView, Sidebar | No Screens defined inline. |
| **State & Logic** | `AppState` | Auth, SyncCoordinator, Routing State, Sheet State | Not allowed to be `@State` in Views (except ephemeral). |
| **Destinations** | `AppDestinations.swift` | Single registry of `.navigationDestination(for:)` | No destinations in Screens. |
| **Data Sync** | `SyncManager` | Bidirectional Sync, Conflict Resolution | No Supabase calls in Views. |

## Navigation Contract
### Root Structure
- **iOS**: `ContentView` uses a specific iPhone/iPad adaptation logic.
- **macOS**: `ContentView` manages a Sidebar + Detail structure.
- **Router**: Managed via `AppState.router` (One Boss).

### Rules
1.  **Root-Only Stack**: There is EXACTLY ONE `NavigationStack` per column, owned by `ContentView`.
2.  **Central Registry**: All `.navigationDestination(for:)` modifiers live in `Dispatch/State/AppDestinations.swift`.
3.  **No Embeds**: `embedInNavigationStack` is Forbidden in production screens (legacy components may validly use it if marked deprecated).
4.  **Path Management**: `AppState.router.pathMain` is the single source of truth for the stack.

## Layout Contract
We enforce a strict layout contract via `StandardScreen`.

### StandardScreen API
All screens **MUST** be wrapped in `StandardScreen`.

```swift
StandardScreen(title: "My Title", layout: .column) {
    // Content
}
.toolbar { ... }
```

- **layout**: `.column` (default, constrained width) or `.fullBleed` (maps/media).
- **scroll**: `.automatic` (default) or `.disabled` (for custom scrolling).

### Forbidden Modifiers
- ❌ Top-level `.padding(.horizontal)` (StandardScreen handles this).
- ❌ Top-level `.frame(maxWidth:)` (StandardScreen handles this).
- ❌ `.navigationTitle` (StandardScreen handles this for consistency).
- ❌ `NavigationStack` (Unless inside a modal sheet).

## State & Command Bus
### AppState (The Brain)
`AppState` is the Single Source of Truth. It is injected via `.environmentObject`.
- Owns `AuthManager`, `SyncCoordinator`, `router`, `lensState`, `sheetState`.

### AppCommand (The Bus)
All user intentions flow through `AppState.dispatch(_:)`.

```swift
// ✅ Good
appState.dispatch(.selectTab(.listings))
appState.dispatch(.navigate(.listing(id)))

// ❌ Bad
appState.router.selectedTab = .listings
```

### Sheet Management
Sheets are central on macOS.
- **Types**: Defined in `AppState.SheetState` (e.g., `.addListing`, `.quickEntry`).
- **Usage**: Set `appState.sheetState = .addListing`.
- **Binding**: Use `sheetStateBinding` in `ContentView`.

## Sync Contract
The `SyncManager` orchestrates all data movement.

### Lifecycle
1.  **Change**: User performs action → Model updated in SwiftData → `markPending()`.
2.  **Trigger**: `syncManager.requestSync()` called immediately.
3.  **SyncDown**: Users → Listings → Tasks → Activities → ClaimEvents.
4.  **SyncUp**: Pushes all `.pending` records to Supabase.

### Conflict Resolution
- **Server Wins** (mostly).
- **Pending Protection**: If a local record is `.pending`, SyncDown skips scalar updates to avoid overwriting user input before it uploads.
- **Orphans**: On first sync (`lastSyncTime == nil`), `reconcileOrphans` runs to delete local records missing from server.

### Avatars
- **Hashing**: SHA256 hash of normalized image stored in `avatar_hash`.
- **Download**: Downloads from public bucket if local hash != remote hash.
- **Optimization**: Does NOT download if hashes match.

## Supabase Backend
**Project URL**: `https://uhkrvxlclflgevocqtkh.supabase.co`

### Schema (Key Tables)
| Table | PK | Key Columns | Notes |
| :--- | :--- | :--- | :--- |
| `users` | `id` (uuid) | `email`, `auth_id`, `avatar_path`, `avatar_hash` | Linked to `auth.users` |
| `listings` | `id` (uuid) | `address`, `status`, `owned_by` | |
| `tasks` | `id` (uuid) | `title`, `status`, `listing_id` | Soft-delete enabled |
| `activities` | `id` (uuid) | `type`, `status`, `listing_id` | Soft-delete enabled |
| `claim_events` | `id` (uuid) | `entity_id`, `entity_type` | Audit trail for claims |

### Realtime
- **Version**: Realtime v2 (Broadcast + Postgres Changes).
- **Usage**: Listens for changes to keep multi-user sessions in sync.

## Project Structure
```
Dispatch/
├── DispatchApp.swift       # Entry Point
├── ContentView.swift       # Router / Container
├── Services/
│   ├── Supabase/           # Backend services
│   └── Sync/               # SyncManager
├── State/
│   ├── AppState.swift      # The Brain
│   └── AppDestinations.swift # Navigation Registry
├── Views/
│   ├── Shell/              # AppShellView, StandardScreen
│   ├── Screens/            # Feature Views (Listings, Tasks)
│   └── Components/         # Reusable UI
└── Models/                 # SwiftData Models
```

## Testing & Guardrails
- **Smoke Tests**: Validate critical flows (Login, Sync, Nav).
- **Compilation**: Complex Views (like `ContentView`) MUST split body into computed properties to prevent type-checker hangs.
- **Linting**: No raw `Color` or `Font`. Use `DS.Colors` and `DS.Typography`.

## Previews (Jobs Standard)
All SwiftUI Previews MUST adhere to the following strict standards to ensure determinism and zero side effects.

### 1. Canonical Shell
- **Rule**: All screen previews MUST be wrapped in `PreviewShell`.
- **Why**: Use `PreviewShell` to inject all required Environment Objects (`AppState`, `SyncManager`, `LensState`, `AppOverlayState`) and provide a stable in-memory `ModelContainer`.
- **Usage**:
  ```swift
  #Preview {
      PreviewShell { context in
          PreviewDataFactory.seed(context)
      } content: { context in
          MyView(...)
      }
  }
  ```

### 2. Strict Isolation (No Side Effects)
- **Rule**: NEVER use `.shared` singletons (e.g., `SyncManager.shared`) in previews.
- **Rule**: `SyncManager` and `AppOverlayState` must be in `.preview` mode.
- **Why**: Prevent network calls, database writes, or keyboard observers from leaking into the canvas.

### 3. Deterministic Data
- **Rule**: Logic that fetches data MUST use `PreviewDataFactory` fixed UUIDs.
- **Rule**: Fetching must use `#Predicate { $0.id == ID }` to guarantee the correct entity is retrieved.
- **Why**: "First" or "Any" fetches are nondeterministic and will break previews randomly.

## Screen Template
Use this template for new screens to ensure compliance:

```swift
// Dispatch/Views/Screens/NewFeatureView.swift
import SwiftUI
import SwiftData

struct NewFeatureView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var syncManager: SyncManager
    @EnvironmentObject private var appState: AppState // Access Command Bus

    @Query private var items: [MyModel]

    var body: some View {
        StandardScreen(title: "New Feature", layout: .column) {
            // Content only. No top-level padding/maxWidth here.
            StandardList(items) { item in
                NavigationLink(value: item) {
                    StandardRow(title: item.title)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add") { add() }
                }
            }
        }
    }

    @MainActor
    private func add() {
        let model = MyModel(title: "New Item")
        modelContext.insert(model)
        model.markPending() // If model conforms to RealtimeSyncable
        syncManager.requestSync()
    }
}
```

