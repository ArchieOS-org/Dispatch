You are performing a code review on the changes in the current branch.

The current branch is **deskinnoah/dis-39-macos-add-things-3-style-collapsible-side-menu**, and the target branch is **origin/main**.

## Code Review Instructions

The entire git diff for this branch has been provided below, as well as a list of all commits made to this branch.

**CRITICAL: EVERYTHING YOU NEED IS ALREADY PROVIDED BELOW.** The complete git diff and full commit history are included in this message.

**DO NOT run git diff, git log, git status, or ANY other git commands.** All the information you need to perform this review is already here.

When reviewing the diff:
1. **Focus on logic and correctness** - Check for bugs, edge cases, and potential issues.
2. **Consider readability** - Is the code clear and maintainable? Does it follow best practices in this repository?
3. **Evaluate performance** - Are there obvious performance concerns or optimizations that could be made?
4. **Assess test coverage** - Does the repository have testing patterns? If so, are there adequate tests for these changes?
5. **Ask clarifying questions** - Ask the user for clarification if you are unsure about the changes or need more context.
6. **Don't be overly pedantic** - Nitpicks are fine, but only if they are relevant issues within reason.

In your output:
- Provide a summary overview of the general code quality.
- Present the identified issues in a table with the columns: index (1, 2, etc.), line number(s), code, issue, and potential solution(s).
- If no issues are found, briefly state that the code meets best practices.

## Full Diff

**REMINDER: DO NOT use any tools to fetch git information.** Simply read the diff and commit history that follow.

```
> cd "/Users/noahdeskin/conductor/workspaces/dispatch/philadelphia" && git diff 22486bfe1c6cacb4d53515a0d0a685b8c2dc445c
diff --git a/.github/workflows/ci.yml b/.github/workflows/ci.yml
index da22b61..7f0ff6f 100644
--- a/.github/workflows/ci.yml
+++ b/.github/workflows/ci.yml
@@ -21,7 +21,7 @@ jobs:
     env:
       SCHEME: Dispatch
       PROJECT: Dispatch.xcodeproj
-      DESTINATION: platform=iOS Simulator,name=iPhone 16,OS=18.1
+      DESTINATION: platform=iOS Simulator,name=iPhone 16,OS=18.4
 
     steps:
       - name: Checkout
diff --git a/Dispatch/ContentView.swift b/Dispatch/ContentView.swift
index fa06247..0eabf0f 100644
--- a/Dispatch/ContentView.swift
+++ b/Dispatch/ContentView.swift
@@ -37,6 +37,14 @@ struct ContentView: View {
     /// Centralized WorkItemActions environment object for shared navigation
     @StateObject private var workItemActions = WorkItemActions()
 
+    // MARK: - macOS Bottom Toolbar State
+
+    #if os(macOS)
+    @State private var showMacOSQuickEntry = false
+    @State private var showMacOSAddListing = false
+    @State private var showMacOSSearch = false
+    #endif
+
     // MARK: - Search State (iPhone only)
 
     @StateObject private var searchManager = SearchPresentationManager()
@@ -172,9 +180,22 @@ struct ContentView: View {
 
     // MARK: - iPad/macOS Sidebar Navigation
 
+    #if os(macOS)
+    /// Toolbar context based on current tab selection
+    private var toolbarContext: ToolbarContext {
+        switch selectedTab {
+        case .tasks:
+            return .taskList
+        case .activities:
+            return .activityList
+        case .listings:
+            return .listingList
+        }
+    }
+
+    /// macOS: Things 3-style resizable sidebar with custom drag handle
     private var sidebarNavigation: some View {
-        NavigationSplitView {
-            #if os(macOS)
+        ResizableSidebar {
             List(selection: $selectedTab) {
                 Label("Tasks", systemImage: DS.Icons.Entity.task)
                     .tag(Tab.tasks)
@@ -183,8 +204,74 @@ struct ContentView: View {
                 Label("Listings", systemImage: DS.Icons.Entity.listing)
                     .tag(Tab.listings)
             }
+            .listStyle(.sidebar)
+            #if !os(macOS)
             .navigationTitle("Dispatch")
-            #else
+            #endif
+        } content: {
+            NavigationStack {
+                Group {
+                    switch selectedTab {
+                    case .tasks:
+                        TaskListView()
+                    case .activities:
+                        ActivityListView()
+                    case .listings:
+                        ListingListView()
+                    }
+                }
+                .dispatchDestinations()
+            }
+            .safeAreaInset(edge: .bottom, spacing: 0) {
+                BottomToolbar(
+                    context: toolbarContext,
+                    onNew: {
+                        if selectedTab == .listings {
+                            showMacOSAddListing = true
+                        } else {
+                            showMacOSQuickEntry = true
+                        }
+                    },
+                    onSearch: { showMacOSSearch = true }
+                )
+            }
+        }
+        .sheet(isPresented: $showMacOSQuickEntry) {
+            QuickEntrySheet(
+                defaultItemType: selectedTab == .activities ? .activity : .task,
+                currentUserId: currentUserId,
+                listings: activeListings,
+                onSave: { syncManager.requestSync() }
+            )
+        }
+        .sheet(isPresented: $showMacOSAddListing) {
+            AddListingSheet(
+                currentUserId: currentUserId,
+                onSave: { syncManager.requestSync() }
+            )
+        }
+        .sheet(isPresented: $showMacOSSearch) {
+            SearchOverlay(
+                isPresented: $showMacOSSearch,
+                searchText: .constant(""),
+                onSelectResult: { _ in }
+            )
+        }
+        .onReceive(NotificationCenter.default.publisher(for: .newItem)) { _ in
+            if selectedTab == .listings {
+                showMacOSAddListing = true
+            } else {
+                showMacOSQuickEntry = true
+            }
+        }
+        .onReceive(NotificationCenter.default.publisher(for: .openSearch)) { _ in
+            showMacOSSearch = true
+        }
+    }
+    #else
+    /// iPad: Standard NavigationSplitView sidebar
+    private var sidebarNavigation: some View {
+        NavigationSplitView {
             List {
                 sidebarButton(for: .tasks, label: "Tasks", icon: DS.Icons.Entity.task)
                 sidebarButton(for: .activities, label: "Activities", icon: DS.Icons.Entity.activity)
@@ -192,7 +279,6 @@ struct ContentView: View {
             }
             .listStyle(.sidebar)
             .navigationTitle("Dispatch")
-            #endif
         } detail: {
             Group {
                 switch selectedTab {
@@ -208,6 +294,7 @@ struct ContentView: View {
         }
         .navigationSplitViewStyle(.balanced)
     }
+    #endif
 
     #if os(iOS)
     @ViewBuilder
diff --git a/Dispatch/Design/Effects/GlassEffect.swift b/Dispatch/Design/Effects/GlassEffect.swift
index e78bbda..278614d 100644
--- a/Dispatch/Design/Effects/GlassEffect.swift
+++ b/Dispatch/Design/Effects/GlassEffect.swift
@@ -8,21 +8,43 @@
 import SwiftUI
 
 extension View {
-    /// Applies a circular glass effect background on iOS 26+, material fallback on earlier versions.
-    /// Explicitly circular - use for round buttons only.
-    @ViewBuilder
-    func glassCircleBackground() -> some View {
-        if #available(iOS 26.0, *) {
-            self.glassEffect(.regular.interactive())
-        } else {
-            self
-                .background(.ultraThinMaterial)
-                .clipShape(Circle())
-                .overlay {
-                    Circle()
-                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
-                }
-                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
+  /// Applies a circular glass effect background on iOS 26+, material fallback on earlier versions.
+  /// Explicitly circular - use for round buttons only.
+  @ViewBuilder
+  func glassCircleBackground() -> some View {
+    if #available(iOS 26.0, *) {
+      self.glassEffect(.regular.interactive())
+    } else {
+      self
+        .background(.ultraThinMaterial)
+        .clipShape(Circle())
+        .overlay {
+          Circle()
+            .strokeBorder(.white.opacity(0.2), lineWidth: 1)
         }
+        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
     }
+  }
+
+  /// Applies a glass effect background for sidebars and panels on macOS 26+.
+  /// Falls back to regularMaterial on earlier versions.
+  /// Use .regular (not .interactive) for static sidebars - less visual noise.
+  @ViewBuilder
+  func glassSidebarBackground() -> some View {
+    #if os(macOS)
+    if #available(macOS 26.0, *) {
+      self
+        .background {
+          Rectangle()
+            .fill(.clear)
+            .glassEffect(.regular)
+        }
+    } else {
+      self
+        .background(.regularMaterial)
+    }
+    #else
+    self.background(.regularMaterial)
+    #endif
+  }
 }
diff --git a/Dispatch/Design/Spacing.swift b/Dispatch/Design/Spacing.swift
index 6479b1a..92df173 100644
--- a/Dispatch/Design/Spacing.swift
+++ b/Dispatch/Design/Spacing.swift
@@ -140,5 +140,36 @@ extension DS {
 
         /// Search overlay modal max width (for larger screens)
         static let searchModalMaxWidth: CGFloat = 500
+
+        // MARK: - Sidebar (macOS)
+
+        /// Minimum sidebar width
+        static let sidebarMinWidth: CGFloat = 200
+
+        /// Maximum sidebar width
+        static let sidebarMaxWidth: CGFloat = 400
+
+        /// Default sidebar width
+        static let sidebarDefaultWidth: CGFloat = 240
+
+        /// Width of the invisible drag handle hit area
+        static let sidebarDragHandleWidth: CGFloat = 8
+
+        /// Height of the visible drag handle indicator
+        static let sidebarDragHandleHeight: CGFloat = 40
+
+        // MARK: - Bottom Toolbar (macOS)
+
+        /// Bottom toolbar height
+        static let bottomToolbarHeight: CGFloat = 44
+
+        /// Bottom toolbar icon button size
+        static let bottomToolbarButtonSize: CGFloat = 36
+
+        /// Bottom toolbar icon size
+        static let bottomToolbarIconSize: CGFloat = 18
+
+        /// Bottom toolbar horizontal padding
+        static let bottomToolbarPadding: CGFloat = 12
     }
 }
diff --git a/Dispatch/DispatchApp.swift b/Dispatch/DispatchApp.swift
index dedea9c..4ff537f 100644
--- a/Dispatch/DispatchApp.swift
+++ b/Dispatch/DispatchApp.swift
@@ -68,7 +68,36 @@ struct DispatchApp: App {
         }
         .modelContainer(sharedModelContainer)
         #if os(macOS)
+        .windowStyle(.hiddenTitleBar)
         .commands {
+            CommandGroup(after: .newItem) {
+                Button("New Item") {
+                    NotificationCenter.default.post(name: .newItem, object: nil)
+                }
+                .keyboardShortcut("n", modifiers: .command)
+
+                Button("Search") {
+                    NotificationCenter.default.post(name: .openSearch, object: nil)
+                }
+                .keyboardShortcut("f", modifiers: .command)
+
+                Divider()
+
+                Button("My Tasks") {
+                    NotificationCenter.default.post(name: .filterMine, object: nil)
+                }
+                .keyboardShortcut("1", modifiers: .command)
+
+                Button("Others' Tasks") {
+                    NotificationCenter.default.post(name: .filterOthers, object: nil)
+                }
+                .keyboardShortcut("2", modifiers: .command)
+
+                Button("Unclaimed") {
+                    NotificationCenter.default.post(name: .filterUnclaimed, object: nil)
+                }
+                .keyboardShortcut("3", modifiers: .command)
+            }
             CommandGroup(after: .toolbar) {
                 Button("Sync Now") {
                     Task {
@@ -77,6 +106,12 @@ struct DispatchApp: App {
                 }
                 .keyboardShortcut("r", modifiers: .command)
             }
+            CommandGroup(after: .sidebar) {
+                Button("Toggle Sidebar") {
+                    NotificationCenter.default.post(name: .toggleSidebar, object: nil)
+                }
+                .keyboardShortcut("/", modifiers: .command)
+            }
         }
         #endif
         .onChange(of: scenePhase) { newPhase in
diff --git a/Dispatch/Views/Components/macOS/BottomToolbar.swift b/Dispatch/Views/Components/macOS/BottomToolbar.swift
new file mode 100644
index 0000000..a1e4144
--- /dev/null
+++ b/Dispatch/Views/Components/macOS/BottomToolbar.swift
@@ -0,0 +1,186 @@
+//
+//  BottomToolbar.swift
+//  Dispatch
+//
+//  Things 3-style bottom toolbar for macOS with context-aware actions.
+//  Created by Claude on 2025-12-25.
+//
+
+#if os(macOS)
+import SwiftUI
+
+/// Screen context for bottom toolbar action configuration.
+/// The toolbar changes based on the current screen, not selection.
+enum ToolbarContext {
+  /// List views: TaskListView, ActivityListView, ListingListView
+  case taskList
+  case activityList
+  case listingList
+
+  /// Detail views: WorkItemDetailView, ListingDetailView
+  case workItemDetail
+  case listingDetail
+
+  /// Whether this context represents a list view
+  var isList: Bool {
+    switch self {
+    case .taskList, .activityList, .listingList:
+      return true
+    case .workItemDetail, .listingDetail:
+      return false
+    }
+  }
+}
+
+/// A Things 3-style bottom toolbar for macOS with context-aware actions.
+/// Icons only, no labels, with hover states and glass material background.
+struct BottomToolbar: View {
+  let context: ToolbarContext
+
+  // List context actions
+  var onNew: (() -> Void)?
+  var onSearch: (() -> Void)?
+
+  // Detail context actions
+  var onClaim: (() -> Void)?
+  var onDelete: (() -> Void)?
+
+  // Claim state for detail views
+  var isClaimable: Bool = true
+  var isClaimed: Bool = false
+
+  var body: some View {
+    HStack(spacing: 0) {
+      if context.isList {
+        listToolbar
+      } else {
+        detailToolbar
+      }
+    }
+    .frame(height: DS.Spacing.bottomToolbarHeight)
+    .background {
+      Rectangle()
+        .fill(.regularMaterial)
+        .overlay(alignment: .top) {
+          Rectangle()
+            .fill(Color.primary.opacity(0.1))
+            .frame(height: 1)
+        }
+    }
+  }
+
+  // MARK: - List Toolbar
+
+  @ViewBuilder
+  private var listToolbar: some View {
+    // Left group
+    HStack(spacing: 0) {
+      if let onNew {
+        ToolbarIconButton(
+          icon: "plus",
+          action: onNew,
+          accessibilityLabel: "New item"
+        )
+      }
+
+      // Placeholder buttons for future features
+      ToolbarIconButton(
+        icon: "plus.square",
+        action: {},
+        accessibilityLabel: "Add subtask"
+      )
+      .disabled(true)
+      .opacity(0.4)
+
+      ToolbarIconButton(
+        icon: "calendar",
+        action: {},
+        accessibilityLabel: "Schedule"
+      )
+      .disabled(true)
+      .opacity(0.4)
+    }
+    .padding(.leading, DS.Spacing.bottomToolbarPadding)
+
+    Spacer()
+
+    // Right group
+    HStack(spacing: 0) {
+      ToolbarIconButton(
+        icon: "arrow.right",
+        action: {},
+        accessibilityLabel: "Move"
+      )
+      .disabled(true)
+      .opacity(0.4)
+
+      if let onSearch {
+        ToolbarIconButton(
+          icon: "magnifyingglass",
+          action: onSearch,
+          accessibilityLabel: "Search"
+        )
+      }
+    }
+    .padding(.trailing, DS.Spacing.bottomToolbarPadding)
+  }
+
+  // MARK: - Detail Toolbar
+
+  @ViewBuilder
+  private var detailToolbar: some View {
+    // Left: Claim button (only for work items, not listings)
+    HStack(spacing: 0) {
+      if context == .workItemDetail, let onClaim, isClaimable {
+        ToolbarIconButton(
+          icon: isClaimed ? "hand.raised.slash" : "hand.raised",
+          action: onClaim,
+          accessibilityLabel: isClaimed ? "Release" : "Claim"
+        )
+      }
+    }
+    .padding(.leading, DS.Spacing.bottomToolbarPadding)
+
+    Spacer()
+
+    // Right: Delete button
+    HStack(spacing: 0) {
+      if let onDelete {
+        ToolbarIconButton(
+          icon: "trash",
+          action: onDelete,
+          accessibilityLabel: "Delete",
+          isDestructive: true
+        )
+      }
+    }
+    .padding(.trailing, DS.Spacing.bottomToolbarPadding)
+  }
+}
+
+#Preview("List Context") {
+  VStack(spacing: 0) {
+    Spacer()
+    BottomToolbar(
+      context: .taskList,
+      onNew: { print("New") },
+      onSearch: { print("Search") }
+    )
+  }
+  .frame(width: 400, height: 200)
+}
+
+#Preview("Detail Context") {
+  VStack(spacing: 0) {
+    Spacer()
+    BottomToolbar(
+      context: .workItemDetail,
+      onClaim: { print("Claim") },
+      onDelete: { print("Delete") },
+      isClaimable: true,
+      isClaimed: false
+    )
+  }
+  .frame(width: 400, height: 200)
+}
+#endif
diff --git a/Dispatch/Views/Components/macOS/ResizableSidebar.swift b/Dispatch/Views/Components/macOS/ResizableSidebar.swift
new file mode 100644
index 0000000..cfd7272
--- /dev/null
+++ b/Dispatch/Views/Components/macOS/ResizableSidebar.swift
@@ -0,0 +1,156 @@
+//
+//  ResizableSidebar.swift
+//  Dispatch
+//
+//  Things 3-style resizable sidebar container for macOS
+//  Created for DIS-39: Things 3-style collapsible side menu
+//
+
+import SwiftUI
+
+#if os(macOS)
+/// A container view that provides a Things 3-style resizable sidebar.
+/// - Sidebar can be resized by dragging the edge
+/// - Sidebar can be collapsed completely
+/// - State persists across app launches
+/// - Responds to keyboard shortcut (Cmd+/)
+struct ResizableSidebar<Sidebar: View, Content: View>: View {
+  @StateObject private var state = SidebarState()
+  @Environment(\.accessibilityReduceMotion) private var reduceMotion
+
+  @ViewBuilder let sidebar: () -> Sidebar
+  @ViewBuilder let content: () -> Content
+
+  var body: some View {
+    GeometryReader { geometry in
+      HStack(spacing: 0) {
+        // Sidebar content - always in hierarchy when visible or dragging
+        if state.shouldShowSidebar {
+          sidebar()
+            .frame(width: state.displayWidth)
+            .glassSidebarBackground()
+            .clipped()
+        }
+
+        content()
+          .frame(maxWidth: .infinity)
+      }
+      // Unified drag handle overlay - persists through entire drag
+      .overlay(alignment: .leading) {
+        UnifiedDragHandle(state: state, reduceMotion: reduceMotion)
+          .offset(x: state.shouldShowSidebar ? state.displayWidth - DS.Spacing.sidebarDragHandleWidth / 2 : 0)
+      }
+    }
+    // Only animate isVisible changes, NOT during drag
+    .animation(
+      state.isDragging ? .none : (reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.8)),
+      value: state.isVisible
+    )
+    .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
+      withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
+        state.toggle()
+      }
+    }
+  }
+}
+
+// MARK: - Unified Drag Handle
+
+/// A persistent drag handle that works in both collapsed and expanded states.
+/// This overlay persists through the entire drag operation, preventing gesture cancellation.
+private struct UnifiedDragHandle: View {
+  @ObservedObject var state: SidebarState
+  let reduceMotion: Bool
+
+  @State private var isHovering: Bool = false
+  @State private var dragStartWidth: CGFloat = 0
+
+  var body: some View {
+    Rectangle()
+      .fill(Color.clear)
+      .frame(width: DS.Spacing.sidebarDragHandleWidth)
+      .contentShape(Rectangle())
+      .overlay(alignment: .center) {
+        // Visible handle indicator - shows on hover or during drag
+        RoundedRectangle(cornerRadius: 2)
+          .fill(Color.primary.opacity(0.3))
+          .frame(width: 4, height: DS.Spacing.sidebarDragHandleHeight)
+          .opacity(isHovering || state.isDragging ? 1 : 0)
+          .animation(
+            reduceMotion ? .none : .easeInOut(duration: 0.15),
+            value: isHovering || state.isDragging
+          )
+      }
+      .onHover { hovering in
+        isHovering = hovering
+      }
+      .onContinuousHover { phase in
+        switch phase {
+        case .active:
+          NSCursor.resizeLeftRight.push()
+        case .ended:
+          NSCursor.pop()
+        }
+      }
+      .gesture(dragGesture)
+      .onTapGesture {
+        // Toggle sidebar on tap
+        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
+          state.toggle()
+        }
+      }
+  }
+
+  private var dragGesture: some Gesture {
+    DragGesture(minimumDistance: 1)
+      .onChanged { value in
+        if !state.isDragging {
+          // Capture starting state
+          dragStartWidth = state.isVisible ? state.width : 0
+          state.isDragging = true
+        }
+
+        // Update liveWidth instantly - sidebar follows cursor
+        state.liveWidth = dragStartWidth + value.translation.width
+      }
+      .onEnded { _ in
+        // Determine final state based on final width
+        let finalWidth = state.liveWidth
+
+        if finalWidth < DS.Spacing.sidebarMinWidth - 30 {
+          // Collapse
+          withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
+            state.isVisible = false
+          }
+        } else if finalWidth > 50 || state.isVisible {
+          // Expand or stay visible with proper width
+          withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
+            state.isVisible = true
+            state.width = state.clampedWidth(finalWidth)
+            state.liveWidth = state.width
+          }
+        }
+
+        state.isDragging = false
+      }
+  }
+}
+
+// MARK: - Preview
+
+#Preview("ResizableSidebar") {
+  ResizableSidebar {
+    List {
+      Label("Tasks", systemImage: "checklist")
+      Label("Activities", systemImage: "figure.run")
+      Label("Listings", systemImage: "building.2")
+    }
+    .listStyle(.sidebar)
+  } content: {
+    Text("Detail Content")
+      .frame(maxWidth: .infinity, maxHeight: .infinity)
+      .background(Color.secondary.opacity(0.1))
+  }
+  .frame(width: 800, height: 600)
+}
+#endif
diff --git a/Dispatch/Views/Components/macOS/SidebarState.swift b/Dispatch/Views/Components/macOS/SidebarState.swift
new file mode 100644
index 0000000..eb4e533
--- /dev/null
+++ b/Dispatch/Views/Components/macOS/SidebarState.swift
@@ -0,0 +1,91 @@
+//
+//  SidebarState.swift
+//  Dispatch
+//
+//  Manages sidebar state with persistence for macOS
+//  Created for DIS-39: Things 3-style collapsible side menu
+//
+
+import Combine
+import SwiftUI
+
+#if os(macOS)
+/// Manages sidebar visibility and width state with persistence.
+/// Uses @AppStorage to remember state across app launches.
+@MainActor
+final class SidebarState: ObservableObject {
+  /// Whether the sidebar is currently visible
+  @AppStorage("sidebarVisible") var isVisible: Bool = true
+
+  /// Current sidebar width (when visible) - default 240pt
+  @AppStorage("sidebarWidth") private var storedWidth: Double = 240
+
+  /// Whether the sidebar is currently being dragged
+  @Published var isDragging: Bool = false
+
+  /// Live width during drag (can go below minWidth for collapse preview)
+  @Published var liveWidth: CGFloat = 240
+
+  /// Current sidebar width as CGFloat
+  var width: CGFloat {
+    get { CGFloat(storedWidth) }
+    set { storedWidth = Double(clampedWidth(newValue)) }
+  }
+
+  /// The effective width to display (liveWidth during drag, width otherwise)
+  var displayWidth: CGFloat {
+    isDragging ? max(0, liveWidth) : width
+  }
+
+  /// Whether to show sidebar based on drag state
+  /// During drag, sidebar always stays in view hierarchy (just shrinks to 0 width)
+  /// This prevents view hierarchy changes mid-drag which cause glitches
+  var shouldShowSidebar: Bool {
+    isDragging || isVisible
+  }
+
+  /// Clamps width to valid range
+  func clampedWidth(_ newWidth: CGFloat) -> CGFloat {
+    min(DS.Spacing.sidebarMaxWidth, max(DS.Spacing.sidebarMinWidth, newWidth))
+  }
+
+  /// Toggle sidebar visibility (animation handled at view level)
+  func toggle() {
+    isVisible.toggle()
+    if isVisible {
+      liveWidth = width
+    }
+  }
+
+  /// Show sidebar (animation handled at view level)
+  func show() {
+    guard !isVisible else { return }
+    isVisible = true
+    liveWidth = width
+  }
+
+  /// Hide sidebar (animation handled at view level)
+  func hide() {
+    guard isVisible else { return }
+    isVisible = false
+  }
+}
+
+// MARK: - Notifications for keyboard shortcuts
+
+extension Notification.Name {
+  /// Posted when the sidebar toggle keyboard shortcut is triggered
+  static let toggleSidebar = Notification.Name("toggleSidebar")
+
+  /// Posted when the new item keyboard shortcut is triggered (Cmd+N)
+  static let newItem = Notification.Name("newItem")
+
+  /// Posted when the search keyboard shortcut is triggered (Cmd+F)
+  static let openSearch = Notification.Name("openSearch")
+
+  /// Posted when filter shortcuts are triggered (Cmd+1/2/3)
+  static let filterMine = Notification.Name("filterMine")
+  static let filterOthers = Notification.Name("filterOthers")
+  static let filterUnclaimed = Notification.Name("filterUnclaimed")
+}
+#endif
diff --git a/Dispatch/Views/Components/macOS/ToolbarIconButton.swift b/Dispatch/Views/Components/macOS/ToolbarIconButton.swift
new file mode 100644
index 0000000..628db74
--- /dev/null
+++ b/Dispatch/Views/Components/macOS/ToolbarIconButton.swift
@@ -0,0 +1,80 @@
+//
+//  ToolbarIconButton.swift
+//  Dispatch
+//
+//  Things 3-style icon button for macOS bottom toolbar
+//  Created by Claude on 2025-12-25.
+//
+
+#if os(macOS)
+import SwiftUI
+
+/// A 36pt icon-only button with hover state for the macOS bottom toolbar.
+/// Follows Things 3 styling: icon-only, no labels, subtle hover feedback.
+struct ToolbarIconButton: View {
+  let icon: String
+  let action: () -> Void
+  let accessibilityLabel: String
+  var isDestructive: Bool = false
+
+  @State private var isHovering = false
+  @Environment(\.accessibilityReduceMotion) private var reduceMotion
+
+  var body: some View {
+    Button(action: action) {
+      Image(systemName: icon)
+        .font(.system(size: DS.Spacing.bottomToolbarIconSize, weight: .medium))
+        .foregroundStyle(iconColor)
+        .frame(
+          width: DS.Spacing.bottomToolbarButtonSize,
+          height: DS.Spacing.bottomToolbarButtonSize
+        )
+        .contentShape(Rectangle())
+        .background(
+          RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall)
+            .fill(isHovering ? Color.primary.opacity(0.08) : Color.clear)
+        )
+    }
+    .buttonStyle(.plain)
+    .onHover { hovering in
+      isHovering = hovering
+    }
+    .animation(
+      reduceMotion ? .none : .easeInOut(duration: 0.15),
+      value: isHovering
+    )
+    .accessibilityLabel(accessibilityLabel)
+  }
+
+  private var iconColor: Color {
+    if isDestructive {
+      return isHovering ? .red : .red.opacity(0.7)
+    } else {
+      return isHovering ? .primary : .primary.opacity(0.6)
+    }
+  }
+}
+
+#Preview {
+  HStack(spacing: DS.Spacing.sm) {
+    ToolbarIconButton(
+      icon: "plus",
+      action: {},
+      accessibilityLabel: "New item"
+    )
+    ToolbarIconButton(
+      icon: "magnifyingglass",
+      action: {},
+      accessibilityLabel: "Search"
+    )
+    ToolbarIconButton(
+      icon: "trash",
+      action: {},
+      accessibilityLabel: "Delete",
+      isDestructive: true
+    )
+  }
+  .padding()
+  .background(Color(nsColor: .windowBackgroundColor))
+}
+#endif
diff --git a/Dispatch/Views/Containers/WorkItemListContainer.swift b/Dispatch/Views/Containers/WorkItemListContainer.swift
index b61647f..8b5ef54 100644
--- a/Dispatch/Views/Containers/WorkItemListContainer.swift
+++ b/Dispatch/Views/Containers/WorkItemListContainer.swift
@@ -90,10 +90,12 @@ struct WorkItemListContainer<Row: View, Destination: View>: View {
     @ViewBuilder
     private var content: some View {
         VStack(spacing: 0) {
-            // Filter bar
+            #if !os(macOS)
+            // Filter bar - iOS/iPad only (macOS uses Cmd+1/2/3 keyboard shortcuts)
             SegmentedFilterBar(selection: $selectedFilter) { filter in
                 filter.displayName(forActivities: isActivityList)
             }
+            #endif
 
             // Content
             if isEmpty {
@@ -102,7 +104,20 @@ struct WorkItemListContainer<Row: View, Destination: View>: View {
                 listView
             }
         }
+        #if !os(macOS)
         .navigationTitle(title)
+        #endif
+        #if os(macOS)
+        .onReceive(NotificationCenter.default.publisher(for: .filterMine)) { _ in
+            selectedFilter = .mine
+        }
+        .onReceive(NotificationCenter.default.publisher(for: .filterOthers)) { _ in
+            selectedFilter = .others
+        }
+        .onReceive(NotificationCenter.default.publisher(for: .filterUnclaimed)) { _ in
+            selectedFilter = .unclaimed
+        }
+        #endif
     }
 
     // MARK: - Subviews
diff --git a/Dispatch/Views/Modifiers/SyncNowToolbar.swift b/Dispatch/Views/Modifiers/SyncNowToolbar.swift
index d4cfa9c..c5602e2 100644
--- a/Dispatch/Views/Modifiers/SyncNowToolbar.swift
+++ b/Dispatch/Views/Modifiers/SyncNowToolbar.swift
@@ -11,9 +11,9 @@ import SwiftUI
 /// A view modifier that adds a "Sync now" toolbar button.
 ///
 /// Replaces pull-to-refresh with an explicit sync action:
-/// - iOS: Toolbar button in trailing position
-/// - iPad: Toolbar button with ⌘R keyboard shortcut
-/// - macOS: ⌘R handled via Commands in DispatchApp.swift
+/// - iOS/iPad: Toolbar button in trailing position with ⌘R keyboard shortcut
+/// - macOS: No toolbar button (Cmd+R handled via Commands in DispatchApp.swift,
+///          top bar is empty for Things 3-style bottom toolbar)
 ///
 /// Usage:
 /// ```swift
@@ -26,20 +26,20 @@ struct SyncNowToolbarModifier: ViewModifier {
     @EnvironmentObject private var syncManager: SyncManager
 
     func body(content: Content) -> some View {
+        #if os(macOS)
+        // macOS: No toolbar button - Cmd+R is in menu bar, top bar should be empty
+        content
+        #else
         content.toolbar {
-            #if os(macOS)
-            ToolbarItem(placement: .primaryAction) {
-                syncButton
-            }
-            #else
             ToolbarItem(placement: .topBarTrailing) {
                 syncButton
                     .keyboardShortcut("r", modifiers: .command)
             }
-            #endif
         }
+        #endif
     }
 
+    #if os(iOS)
     private var syncButton: some View {
         Button {
             Task {
@@ -57,6 +57,7 @@ struct SyncNowToolbarModifier: ViewModifier {
         .accessibilityLabel("Sync now")
         .accessibilityHint("Synchronizes your data with the server")
     }
+    #endif
 }
 
 extension View {
diff --git a/Dispatch/Views/Screens/ActivityListView.swift b/Dispatch/Views/Screens/ActivityListView.swift
index a076ce0..4b49d3f 100644
--- a/Dispatch/Views/Screens/ActivityListView.swift
+++ b/Dispatch/Views/Screens/ActivityListView.swift
@@ -30,15 +30,7 @@ struct ActivityListView: View {
 
     @Query private var users: [User]
 
-    #if os(macOS)
-    @Query(sort: \Listing.address)
-    private var allListings: [Listing]
-
-    /// Active listings for QuickEntrySheet picker
-    private var activeListings: [Listing] {
-        allListings.filter { $0.status != .deleted }
-    }
-    #endif
+    // macOS listings query removed - QuickEntrySheet now triggered from ContentView
 
     @EnvironmentObject private var syncManager: SyncManager
     @EnvironmentObject private var lensState: LensState
@@ -58,10 +50,7 @@ struct ActivityListView: View {
     @State private var itemForSubtaskAdd: WorkItem?
     @State private var newSubtaskTitle = ""
 
-    // MARK: - State for Quick Entry (macOS only - iOS uses GlobalFloatingButtons)
-    #if os(macOS)
-    @State private var showQuickEntry = false
-    #endif
+    // macOS quick entry state removed - now handled in ContentView bottom toolbar
 
     // MARK: - State for Sync Failure Toast
     @State private var showSyncFailedToast = false
@@ -171,26 +160,7 @@ struct ActivityListView: View {
                 showAddSubtaskSheet = false
             }
         }
-        #if os(macOS)
-        .sheet(isPresented: $showQuickEntry) {
-            QuickEntrySheet(
-                defaultItemType: .activity,
-                currentUserId: currentUserId,
-                listings: activeListings,
-                onSave: { syncManager.requestSync() }
-            )
-        }
-        .toolbar {
-            ToolbarItem(placement: .primaryAction) {
-                Button {
-                    showQuickEntry = true
-                } label: {
-                    Label("Add", systemImage: "plus")
-                }
-                .keyboardShortcut("n", modifiers: .command)
-            }
-        }
-        #endif
+        // macOS toolbar removed - bottom toolbar in ContentView handles quick entry
         .alert("Sync Issue", isPresented: $showSyncFailedToast) {
             Button("OK", role: .cancel) {}
         } message: {
diff --git a/Dispatch/Views/Screens/ListingDetailView.swift b/Dispatch/Views/Screens/ListingDetailView.swift
index c91aacc..e46feac 100644
--- a/Dispatch/Views/Screens/ListingDetailView.swift
+++ b/Dispatch/Views/Screens/ListingDetailView.swift
@@ -129,17 +129,14 @@ struct ListingDetailView: View {
         #if os(iOS)
         .navigationBarTitleDisplayMode(.inline)
         #endif
+        #if os(iOS)
         .toolbar {
-            #if os(iOS)
             ToolbarItem(placement: .topBarTrailing) {
                 OverflowMenu(actions: listingActions)
             }
-            #else
-            ToolbarItem(placement: .automatic) {
-                OverflowMenu(actions: listingActions)
-            }
-            #endif
         }
+        #endif
+        // macOS uses bottom toolbar for delete action (handled via OverflowMenu for now)
         // MARK: - Alerts
         .alert("Delete Listing?", isPresented: $showDeleteListingAlert) {
             Button("Cancel", role: .cancel) {}
diff --git a/Dispatch/Views/Screens/ListingListView.swift b/Dispatch/Views/Screens/ListingListView.swift
index 3bd35ed..d8aa449 100644
--- a/Dispatch/Views/Screens/ListingListView.swift
+++ b/Dispatch/Views/Screens/ListingListView.swift
@@ -54,10 +54,7 @@ struct ListingListView: View {
     @State private var itemForSubtaskAdd: WorkItem?
     @State private var newSubtaskTitle = ""
 
-    // MARK: - State for Add Listing (macOS only - iOS uses GlobalFloatingButtons for tasks/activities)
-    #if os(macOS)
-    @State private var showAddListing = false
-    #endif
+    // macOS add listing state removed - now handled in ContentView bottom toolbar
 
     // MARK: - Computed Properties
 
@@ -118,7 +115,9 @@ struct ListingListView: View {
                 listView
             }
         }
+        #if !os(macOS)
         .navigationTitle("Listings")
+        #endif
         // MARK: - Alerts and Sheets
         .alert("Delete Note?", isPresented: $showDeleteNoteAlert) {
             Button("Cancel", role: .cancel) {
@@ -152,24 +151,7 @@ struct ListingListView: View {
                 showAddSubtaskSheet = false
             }
         }
-        #if os(macOS)
-        .sheet(isPresented: $showAddListing) {
-            AddListingSheet(
-                currentUserId: currentUserId,
-                onSave: { syncManager.requestSync() }
-            )
-        }
-        .toolbar {
-            ToolbarItem(placement: .primaryAction) {
-                Button {
-                    showAddListing = true
-                } label: {
-                    Label("Add", systemImage: "plus")
-                }
-                .keyboardShortcut("n", modifiers: .command)
-            }
-        }
-        #endif
+        // macOS toolbar removed - bottom toolbar in ContentView handles add listing
     }
 
     @ViewBuilder
diff --git a/Dispatch/Views/Screens/TaskListView.swift b/Dispatch/Views/Screens/TaskListView.swift
index 54c88a8..8f62d30 100644
--- a/Dispatch/Views/Screens/TaskListView.swift
+++ b/Dispatch/Views/Screens/TaskListView.swift
@@ -31,15 +31,7 @@ struct TaskListView: View {
 
     @Query private var users: [User]
 
-    #if os(macOS)
-    @Query(sort: \Listing.address)
-    private var allListings: [Listing]
-
-    /// Active listings for QuickEntrySheet picker
-    private var activeListings: [Listing] {
-        allListings.filter { $0.status != .deleted }
-    }
-    #endif
+    // macOS listings query removed - QuickEntrySheet now triggered from ContentView
 
     @EnvironmentObject private var syncManager: SyncManager
     @EnvironmentObject private var lensState: LensState
@@ -59,10 +51,7 @@ struct TaskListView: View {
     @State private var itemForSubtaskAdd: WorkItem?
     @State private var newSubtaskTitle = ""
 
-    // MARK: - State for Quick Entry (macOS only - iOS uses GlobalFloatingButtons)
-    #if os(macOS)
-    @State private var showQuickEntry = false
-    #endif
+    // macOS quick entry state removed - now handled in ContentView bottom toolbar
 
     // MARK: - State for Sync Failure Toast
     @State private var showSyncFailedToast = false
@@ -172,26 +161,7 @@ struct TaskListView: View {
                 showAddSubtaskSheet = false
             }
         }
-        #if os(macOS)
-        .sheet(isPresented: $showQuickEntry) {
-            QuickEntrySheet(
-                defaultItemType: .task,
-                currentUserId: currentUserId,
-                listings: activeListings,
-                onSave: { syncManager.requestSync() }
-            )
-        }
-        .toolbar {
-            ToolbarItem(placement: .primaryAction) {
-                Button {
-                    showQuickEntry = true
-                } label: {
-                    Label("Add", systemImage: "plus")
-                }
-                .keyboardShortcut("n", modifiers: .command)
-            }
-        }
-        #endif
+        // macOS toolbar removed - bottom toolbar in ContentView handles quick entry
         .alert("Sync Issue", isPresented: $showSyncFailedToast) {
             Button("OK", role: .cancel) {}
         } message: {

```

## Commit History

```
> cd "/Users/noahdeskin/conductor/workspaces/dispatch/philadelphia" && git log origin/main..HEAD
commit 3ce3ba1ab783b2214d88cb16cad11b9cef8c3ccf
Author: nsd97 <nsd@me.com>
Date:   Thu Dec 25 14:46:39 2025 -0500

    feat(macos): add Things 3-style bottom toolbar and hide top toolbar (DIS-39)
    
    - Add BottomToolbar component with New Item (+) and Search buttons
    - Add ToolbarIconButton for consistent icon button styling
    - Integrate bottom toolbar into macOS sidebar navigation via safeAreaInset
    - Add .windowStyle(.hiddenTitleBar) to remove unified title bar
    - Hide SegmentedFilterBar on macOS (use Cmd+1/2/3 for filters)
    - Add Cmd+N for new item and Cmd+F for search shortcuts
    - Add filter keyboard shortcuts (Cmd+1: Mine, Cmd+2: Others, Cmd+3: Unclaimed)
    - Remove .navigationTitle() on macOS views to clean up window chrome
    - Update SyncNowToolbar to skip toolbar on macOS (uses menu bar Cmd+R)
    - Add sidebar spacing constants (min/max width)
    - Enhance GlassEffect with darker blur and border styling
    
    🤖 Generated with [Claude Code](https://claude.com/claude-code)
    
    Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>

commit ddbac4b209c56d7f8d9a5fa27019d25534110c88
Author: nsd97 <nsd@me.com>
Date:   Thu Dec 25 13:25:28 2025 -0500

    fix(ci): update iOS simulator version to 18.4
    
    The CI runner with Xcode 16.1 doesn't have iOS 18.1 simulators.
    Updated to iOS 18.4 which is available on the macos-15 runner.
    
    🤖 Generated with [Claude Code](https://claude.com/claude-code)
    
    Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>

commit 6fa1b739bb9ca5da75d74d0e2d2ff7e6a04c960b
Author: nsd97 <nsd@me.com>
Date:   Thu Dec 25 13:21:10 2025 -0500

    feat(ui): implement Things 3-style resizable macOS sidebar (DIS-39)
    
    Add custom macOS sidebar replacing NavigationSplitView with smooth drag-to-resize and collapse behavior. Includes real-time cursor-following drag, spring animations, keyboard toggle (Cmd+/), and persistent state across app launches.
    
    - New SidebarState: @AppStorage persistence, live drag tracking
    - New ResizableSidebar: Custom layout with unified drag handle
    - Smooth drag: No animation during drag, spring settle on release
    - Keyboard shortcut: Cmd+/ to toggle sidebar visibility
    - iPad/macOS: Separate implementations (iPad keeps NavigationSplitView)
    
    🤖 Generated with [Claude Code](https://claude.com/claude-code)
    
    Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>

```