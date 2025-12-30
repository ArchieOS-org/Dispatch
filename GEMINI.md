# Dispatch
Dispatch is a premium, multi-platform Swift application (iOS, iPadOS, macOS) built on Supabase. It synchronizes data between specific, strictly typed SwiftData models and a Postgres backend. Built to Steve Jobs standards.

## Tech Stack
- **Language**: Swift 6 (Strict Concurrency)
- **UI Framework**: SwiftUI (Unified `StandardScreen` layout)
- **Backend**: Supabase (Postgres, Auth, Realtime v2)
- **Persistence**: SwiftData (Local-first, syncs via `SyncManager`)
- **Build System**: Xcode 16+ / Swift Package Manager

## Architecture: "One Boss"
We strictly follow the **One Boss** pattern to manage state and navigation.
1.  **AppState**: The single source of truth. Owns `AuthManager` and `SyncCoordinator`.
2.  **DispatchApp (Scene)**: Plumbing only. Decides which Root View to show.
    - Uses a `ZStack` and explicit `.transition(.opacity)` to switch between `LoginView`, `OnboardingLoadingView`, and `AppShellView`.
3.  **AppShellView**: The main UI container / Router.
    - Handles the root `NavigationStack`.
    - Defines global `navigationDestination` modifiers (using `DispatchDestinationsModifier` or explicit `.navigationDestination`).
    - **Chrome Policy**: Only `AppShellView` controls the toolbar style and background. Individual screens may ONLY add items.
4.  **StandardScreen**: ALL screens must use `StandardScreen(title: ...)` generic wrapper.
    - **CRITICAL**: Do NOT use `NavigationStack` inside a `StandardScreen` unless it is a modal or a standalone flow. The screen should rely on the parent `AppShellView` stack.

## Layout Contract
We enforce a strict layout contract via `StandardScreen`.
- **Default**: Use `StandardScreen(layout: .column)` for 95% of screens (text, forms, lists, details).
- **Exceptions**: Use `StandardScreen(layout: .fullBleed)` ONLY for:
    - Interactive Maps
    - Dense, multi-column data tables
    - Media canvases (images/video)
    - Special dashboards (approved explicitly)
- **Tokens**: `DS.Layout.pageMargin`, `DS.Layout.maxContentWidth`.
- **Violations**: NEVER add top-level `.padding(.horizontal)` or `.frame(maxWidth:)` inside a screen. The wrapper handles this.
    - *Top-level means applied to the view returned directly from body / content of a Screen (outside reusable components).*

## Navigation & Routing
- **Router Pattern**: We define navigation destinations at the **ROOT** level (`AppShellView` or `ContentView`'s main tab view), usually via a centralized modifier (e.g., `DispatchDestinationsModifier`).
- **New Types**: If you add a new destination type, you MUST:
    1. Ensure it conforms to `Hashable`.
    2. Add a `.navigationDestination(for:)` entry in `DispatchDestinationsModifier`.
    3. Add a minimal UI smoke test that pushes this destination.
- **No Dual-Mode Screens**: Do NOT implement `embedInNavigationStack` flags in production views.
- **PreviewShell**: use `PreviewShell { MyScreen() }` for previews and test harnesses.
    - `PreviewShell` provides: `NavigationStack`, `DispatchDestinationsModifier`, and required mock environments (`AppState`, `SyncManager`, `LensState`).
    - **Rule**: No screen carries preview/test scaffolding flags in production code.

## Data Mutation & Sync (Local-First)
- **SyncManager**: The singleton orchestrator (`SyncManager.shared`).
- **Mutation Rules**:
    1.  **MainActor**: All model mutations happen on MainActor using `@Environment(\.modelContext)`. Views may read via `@Query`, but significant logic should live in an Action layer.
    2.  **Trigger Sync**: After ANY mutation, call `syncManager.requestSync()` immediately.
    3.  **Deletes**: Use soft-delete conventions. Set status to `.deleted`, call `markPending()`. DO NOT hard delete unless explicitly allowed.
    4.  **No Direct API**: NEVER call Supabase client directly from Views.

## Design System (Monochrome)
- **Files**: `Dispatch/Design/ColorSystem.swift`, `Dispatch/Design/Typography.swift`.
- **DS.Colors**: Use `DS.Colors.Text.primary`, `DS.Colors.Background.card`, etc.
    - ❌ NO raw `Color.red` or `Color(.systemGray)`.
- **DS.Typography**: Use `DS.Typography.headline`, `DS.Typography.body`, etc.
- **Components**: Prefer `StandardList`, `StandardRow`, `PrimaryButton`.

## Screen Creation Guide (Non-negotiables)
When creating a new screen, you must strict adherence to this checklist:
1.  **Wrapper**: Must start with `StandardScreen(title: "My Title", layout: .column)`.
2.  **Forbidden Modifiers**:
    - ❌ `NavigationStack`, `NavigationSplitView` (unless modal)
    - ❌ `.navigationTitle("...")` (handled by StandardScreen)
    - ❌ `.toolbarBackground(...)`, `.windowToolbarStyle(...)` (AppShell owns chrome)
    - ❌ Top-level `.padding(.horizontal)` or `.frame(maxWidth:)`
    - ❌ `NSWindow`, `NSApp`, `WindowAccessor` hacks
3.  **Allowed Interactions**:
    - ✅ `.toolbar { ToolbarItem... }` (Items only)
    - ✅ `NavigationLink(value: MyModel)` (Value-based only, no destination builders)
4.  **Registration**: Register the destination in `AppShellView` or `DispatchDestinationsModifier`.

## Definition of Done (new screen)
- [ ] Appears via router destinations (root-level).
- [ ] Uses strict `DS.*` tokens only.
- [ ] No guardrail violations (padding/frame/navigation hacks).
- [ ] **Tests**:
    - Core logic/commands have unit tests.
    - **Core Screens** (Main Nav / Primary Detail views) MUST have a Snapshot test.
    - Main Nav changes include a UI smoke test update.

## Agent Rules (The Steve Jobs Standard)
- **No Glitches**: Transitions must be smooth (`.transition(.opacity)`). No blank screens.
- **Premium Feel**: Use "Invisible Toolbar" look on macOS.
- **Consistency**: Don't invent new patterns. Use `StandardScreen` and `DS.*` tokens.
- **Safety**: Verify `SyncManager.currentUser` before mounting the main app.

## Screen Template
Use this template for new screens to ensure compliance:

```swift
// Dispatch/Views/Screens/NewFeatureView.swift
import SwiftUI
import SwiftData

struct NewFeatureView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var syncManager: SyncManager

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
