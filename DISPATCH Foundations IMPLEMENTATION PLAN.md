## *With Supabase Live Sync + SwiftData + Multi-Platform Support*

---

## **PHASE 1: FOUNDATION (Weeks 1-2)**

### *Build the persistence layer first—this defines everything else*

### **1.1 Data Models + Supabase Schema**

**Models (SwiftData on-device)**:

```
USER
  ├─ id: UUID
  ├─ name: String
  ├─ email: String
  ├─ avatar: Data? (local cache)
  ├─ userType: UserType (realtor, admin, marketing, exec)
  ├─ listings: [Listing] = [] (for realtors: listings they own)
  ├─ claimedTasks: [Task] = [] (for staff: tasks they've claimed)
  ├─ claimedActivities: [Activity] = [] (for staff: activities they've claimed)
  └─ assignedListings: [Listing] = [] (for staff: listings they're assigned to work on)

STAFF (subset of User where userType.isStaff == true)
  └─ Staff members use Dispatch app to claim tasks, add notes, and execute work

REALTOR (subset of User where userType == .realtor)
  └─ Realtors use a separate app to declare listings and tasks (shared DB)

TASK (WorkItem)
  ├─ id: UUID
  ├─ title: String
  ├─ description: String
  ├─ dueDate: Date?
  ├─ priority: Priority (Low, Medium, High, Urgent)
  ├─ status: TaskStatus (Open, InProgress, Completed, Deleted)
  ├─ declaredBy: UUID (FK to User - the Realtor who declared this)
  ├─ claimedBy: UUID? (FK to User - the Staff member who currently has it claimed)
  ├─ listing: UUID? (FK to Listing, optional)
  ├─ notes: [Note] = []
  ├─ subtasks: [Subtask] = []
  ├─ statusHistory: [StatusChange] = [] (audit trail of all status transitions)
  ├─ claimHistory: [ClaimEvent] = [] (audit trail of all claim/release actions)
  ├─ createdVia: CreationSource (where this task originated: dispatch, slack, realtorApp, api, import)
  ├─ sourceSlackMessages: [String]? (if createdVia == .slack: the Slack message URLs/IDs; nil otherwise)
  ├─ // Key milestone timestamps (for fast queries)
  ├─ claimedAt: Date? (when staff first claimed this)
  ├─ completedAt: Date? (when marked completed)
  ├─ deletedAt: Date? (when soft deleted)
  ├─ createdAt: Date
  ├─ updatedAt: Date
  └─ syncedAt: Date? (for sync tracking)

ACTIVITY (WorkItem)
  ├─ id: UUID
  ├─ title: String
  ├─ description: String
  ├─ type: ActivityType (Call, Email, Meeting, ShowProperty, FollowUp, Other)
  ├─ dueDate: Date?
  ├─ status: ActivityStatus (Open, InProgress, Completed, Deleted)
  ├─ declaredBy: UUID (FK to User - the Realtor who declared this)
  ├─ claimedBy: UUID? (FK to User - the Staff member who currently has it claimed)
  ├─ listing: UUID? (FK to Listing, optional)
  ├─ notes: [Note] = []
  ├─ subtasks: [Subtask] = []
  ├─ statusHistory: [StatusChange] = [] (audit trail of all status transitions)
  ├─ claimHistory: [ClaimEvent] = [] (audit trail of all claim/release actions)
  ├─ createdVia: CreationSource (where this activity originated: dispatch, slack, realtorApp, api, import)
  ├─ sourceSlackMessages: [String]? (if createdVia == .slack: the Slack message URLs/IDs; nil otherwise)
  ├─ // Key milestone timestamps (for fast queries)
  ├─ claimedAt: Date? (when staff first claimed this)
  ├─ completedAt: Date? (when marked completed)
  ├─ deletedAt: Date? (when soft deleted)
  ├─ duration: TimeInterval? [PLACEHOLDER: for call/meeting tracking]
  ├─ createdAt: Date
  ├─ updatedAt: Date
  └─ syncedAt: Date?

LISTING (Entity)
  ├─ id: UUID
  ├─ address: String
  ├─ city: String
  ├─ province: String
  ├─ postalCode: String
  ├─ country: String (default: "Canada")
  ├─ price: Decimal?
  ├─ mlsNumber: String?
  ├─ type: ListingType (Sale, Lease, PreListing, Rental, Other)
  ├─ ownedBy: UUID (FK to User - the Realtor who owns this listing)
  ├─ assignedStaff: UUID? (FK to User - Staff member assigned to work on it)
  ├─ tasks: [Task] = []
  ├─ activities: [Activity] = []
  ├─ notes: [Note] = []
  ├─ statusHistory: [StatusChange] = [] (audit trail of all status transitions)
  ├─ createdVia: CreationSource (where this listing originated: dispatch, slack, realtorApp, api, import)
  ├─ sourceSlackMessages: [String]? (if createdVia == .slack: the Slack message URLs/IDs; nil otherwise)
  ├─ status: ListingStatus (Draft, Active, Pending, Closed, Deleted)
  ├─ // Key milestone timestamps (for fast queries)
  ├─ activatedAt: Date? (when listing went active/live)
  ├─ pendingAt: Date? (when listing went under contract)
  ├─ closedAt: Date? (when deal closed)
  ├─ deletedAt: Date? (when soft deleted)
  ├─ createdAt: Date
  ├─ updatedAt: Date
  ├─ syncedAt: Date?
  └─ [PLACEHOLDER: listing_photos, description, open_houses]

NOTE (Sub-entity)
  ├─ id: UUID
  ├─ content: String
  ├─ createdBy: UUID (FK to User - who wrote this note)
  ├─ parentType: ParentType (task, activity, listing)
  ├─ parentId: UUID (FK to Task/Activity/Listing)
  ├─ createdAt: Date
  ├─ editedAt: Date? (set when note is edited)
  ├─ editedBy: UUID? (FK to User - who last edited)
  ├─ syncedAt: Date?
  └─ [PLACEHOLDER: mentions, attachments]

SUBTASK (Sub-entity)
  ├─ id: UUID
  ├─ title: String
  ├─ completed: Bool = false
  ├─ parentType: ParentType (task, activity)
  ├─ parentId: UUID (FK to Task/Activity)
  ├─ createdAt: Date
  ├─ syncedAt: Date?
  └─ [PLACEHOLDER: assignedTo, dueDate]

STATUS_CHANGE (Sub-entity) - Audit trail for status transitions
  ├─ id: UUID
  ├─ parentType: ParentType (task, activity, listing)
  ├─ parentId: UUID (FK to Task/Activity/Listing)
  ├─ oldStatus: String? (nil for initial creation)
  ├─ newStatus: String
  ├─ changedBy: UUID (FK to User - who made this change)
  ├─ changedAt: Date
  ├─ reason: String? (optional note explaining the change)
  └─ syncedAt: Date?

CLAIM_EVENT (Sub-entity) - Audit trail for claim/release actions
  ├─ id: UUID
  ├─ parentType: ParentType (task, activity)
  ├─ parentId: UUID (FK to Task/Activity)
  ├─ action: ClaimAction (claimed, released)
  ├─ userId: UUID (FK to User - who performed this action)
  ├─ performedAt: Date
  ├─ reason: String? (optional note, e.g., "reassigning to marketing")
  └─ syncedAt: Date? 
```

---

### **1.2 Supabase Schema Overview**

See **Section 2.1** for full PostgreSQL schema. Tables:

- `users` (with user_type column for realtor/admin/marketing/exec)
- `tasks`, `activities`, `listings` (with RLS policies)
- `notes`, `subtasks` (sub-entities)
- `status_changes`, `claim_events` (audit trail)
- `sync_metadata` (tracks last sync per user)

---

### **1.3 SyncManager Service** (The Orchestrator) ✅ IMPLEMENTED

```
SyncManager (Singleton) - Location: Dispatch/Services/Sync/SyncManager.swift
  ├─ Properties:
  │  ├─ modelContainer: ModelContainer (SwiftData)
  │  ├─ lastSyncTime: Date? @Published
  │  ├─ isSyncing: Bool @Published
  │  ├─ syncStatus: SyncStatus @Published (.synced, .syncing, .pending, .error)
  │  ├─ syncError: Error? @Published
  │  └─ currentUserID: UUID? (set when authenticated)
  │
  ├─ Methods (Implemented):
  │  ├─ configure(with: ModelContainer, testUserID: UUID?) → Setup
  │  ├─ sync() async → Full bidirectional sync
  │  ├─ requestSync() → Debounced sync trigger (500ms)
  │  ├─ syncDown(context:) async → Supabase → SwiftData
  │  ├─ syncUp(context:) async → SwiftData → Supabase (dirty entities)
  │  ├─ startListening() async → Realtime WebSocket subscriptions
  │  └─ stopListening() async → Disconnect realtime
  │
  ├─ Methods (Placeholder):
  │  ├─ [TODO: handleConflict() → Manual conflict resolution]
  │  └─ [TODO: retryFailedSync(), offlineQueueManager()]
  │
  └─ Triggers:
     ├─ ✅ App launch (startListening called in DispatchApp.swift)
     ├─ ✅ Data modified locally → call requestSync()
     ├─ ✅ Realtime event received → requestSync() called automatically
     └─ [PLACEHOLDER: Silent push notification received]

USAGE: When modifying data, call SyncManager.shared.requestSync()
       See Section 3.4 for full developer guide.
```

---

### **1.4 Protocols (Shared Interfaces)**

```
WorkItemProtocol
  ├─ id: UUID
  ├─ title: String
  ├─ description: String
  ├─ dueDate: Date?
  ├─ priority: Priority
  ├─ status: any WorkItemStatus  // TaskStatus or ActivityStatus (use associated type in protocol)
  ├─ declaredBy: UUID (Realtor who created)
  ├─ claimedBy: UUID? (Staff who currently has it)
  ├─ listing: UUID?
  ├─ notes: [Note]
  ├─ subtasks: [Subtask]
  ├─ statusHistory: [StatusChange]
  ├─ claimHistory: [ClaimEvent]
  ├─ createdVia: CreationSource
  ├─ createdAt: Date
  ├─ updatedAt: Date
  ├─ syncedAt: Date?
  └─ [PLACEHOLDER: custom properties per type]

ClaimableProtocol
  ├─ canBeClaimed: Bool
  ├─ claimedBy: UUID?
  ├─ claimHistory: [ClaimEvent]
  ├─ claim(by: User) async  // Only Staff can claim; appends to claimHistory
  ├─ release(reason: String?) async  // Appends release event to claimHistory
  └─ [PLACEHOLDER: claimExpiresAt, autoRelease logic]

NotableProtocol
  ├─ notes: [Note]
  ├─ addNote(content: String, by: User) async
  ├─ deleteNote(id: UUID) async
  └─ [PLACEHOLDER: editNote functionality]

RealtimeSyncable (for Supabase integration)
  ├─ syncedAt: Date?
  ├─ isDirty: Bool (local change not yet synced)
  ├─ conflictResolution: ConflictStrategy (Last-Write-Wins, Manual, Realtor-Priority)
  └─ [PLACEHOLDER: syncError tracking]

```

---

## **PHASE 2: SHARED COMPONENTS (Weeks 2-3)**

### **2.1 Design Tokens (Foundation Layer)** ✅ IMPLEMENTED

> **Implementation Status**: Completed 2025-12-06
>
> **Files Created** in `Dispatch/Design/`:
> - `DesignSystem.swift` - Main DS namespace
> - `Typography.swift` - Font styles (headline, body, bodySecondary, caption, captionSecondary)
> - `ColorSystem.swift` - Semantic colors with Priority, TaskStatus, ActivityStatus, SyncStatus, ClaimState mappings
> - `Spacing.swift` - Layout constants (notesStackHeight: 140, noteCascadeOffset: 8, etc.)
> - `Shadows.swift` - Shadow styles including `notesOverflowGradient` LinearGradient
> - `IconSystem.swift` - SF Symbols mappings for Entity, Action, StatusIcons, Claim, ActivityType, Time

```
Dispatch/Design/
├─ DesignSystem.swift    - Main DS namespace
├─ Typography.swift      - Font styles
├─ ColorSystem.swift     - Semantic colors + dark mode support
├─ Spacing.swift         - Layout constants
├─ Shadows.swift         - Shadow styles and gradients
└─ IconSystem.swift      - SF Symbols mappings

```

---

### **2.2 Shared Components** ✅ IMPLEMENTED

> **Implementation Status**: Completed 2025-12-06
>
> **Architecture Decision**: Used `WorkItem` enum wrapper instead of generics (`WorkItemProtocol`) because:
> - Only 2 types (TaskItem, Activity) need unification
> - TaskStatus vs ActivityStatus have different enum types that don't share a common protocol
> - Simpler debugging and code completion compared to generic constraints
> - More explicit pattern matching for type-specific behavior (typeLabel, typeIcon)
>
> **Files Created** (14 total in `Dispatch/Views/Components/`):
> ```
> Dispatch/Views/Components/
> ├── Shared/
> │   ├── PriorityDot.swift        - Color-coded priority indicator (sizes: small/medium)
> │   ├── DueDateBadge.swift       - Contextual due date with overdue/today/upcoming styling
> │   ├── UserAvatar.swift         - Avatar with initials fallback (sizes: small/medium/large)
> │   ├── StatusCheckbox.swift     - Animated completion toggle with spring animation
> │   ├── ClaimButton.swift        - State-dependent claim/release with confirmation dialog
> │   └── CollapsibleHeader.swift  - Scroll-aware header using PreferenceKey (32pt → 18pt)
> │
> ├── WorkItem/
> │   ├── WorkItem.swift           - Enum wrapper unifying TaskItem and Activity
> │   ├── WorkItemRow.swift        - List row with swipe actions (edit/delete)
> │   └── WorkItemDetailView.swift - Full detail view with collapsible header
> │
> ├── Notes/
> │   ├── NoteCard.swift           - Single note with tap-to-show edit/delete actions
> │   ├── NoteStack.swift          - THE DIFFERENTIATOR: 140pt cascading with gradient shadow
> │   └── NoteInputArea.swift      - TextEditor with save/cancel buttons
> │
> └── Subtasks/
>     ├── SubtaskRow.swift         - Checkbox + title + delete button
>     └── SubtasksList.swift       - List with progress bar and add button
> ```
>
> **Key Implementation Notes**:
> - NoteStack uses `LinearGradient` overlay (NOT `.shadow()` modifier) because shadows get clipped by `.clipped()`
> - CollapsibleHeader uses `PreferenceKey` pattern for scroll offset tracking with font interpolation
> - iOS 16.0+ minimum required for `.scrollContentBackground(.hidden)` on TextEditor
> - All components use closure-based actions for maximum flexibility
> - All components respect `DS.*` design tokens from Stage 2.1
> - Comprehensive SwiftUI previews included in each file

---

### **WorkItemRow**

```
WorkItemRow<T: WorkItemProtocol>
  ├─ Displays:
  │  ├─ Checkbox (completion indicator)
  │  ├─ Title (with strikethrough if completed)
  │  ├─ [PLACEHOLDER: subtitle/description preview]
  │  ├─ Due date badge (red if overdue)
  │  ├─ Priority dot (color-coded)
  │  ├─ Claimed by avatar (small circular badge)
  │  ├─ [PLACEHOLDER: sync status indicator (cloud icon with check/arrow)]
  │  └─ Swipe actions: Edit, Delete
  │
  └─ Modifiers:
     ├─ @State var isSyncing: Bool [PLACEHOLDER]
     └─ .onAppear { startAutoRefresh() } [PLACEHOLDER]

```

---

### **WorkItemDetailView** (THE CORE)

```
WorkItemDetailView<T: WorkItemProtocol>
  ├─ Header (Collapsing on scroll)
  │  ├─ Large title (32pt → 18pt as you scroll)
  │  ├─ Project/Listing badge
  │  ├─ Priority indicator (dot + text)
  │  ├─ Due date + time picker
  │  ├─ [PLACEHOLDER: sync status (saving... / synced / error)]
  │  └─ Edit button (top-right)
  │
  ├─ Details Section
  │  ├─ Due date (DatePicker)
  │  ├─ Time (Toggle + TimePicker)
  │  ├─ Priority selector (Picker)
  │  ├─ [PLACEHOLDER: Repeat pattern (None/Daily/Weekly/Monthly/Custom)]
  │  ├─ Listing assignment (Picker or search field)
  │  └─ [PLACEHOLDER: Custom fields (ActivityType, Duration, Attendees, etc.)]
  │
  ├─ Metadata Section
  │  ├─ Created By: UserBadge + date
  │  ├─ Last Updated: Timestamp
  │  ├─ Claimed By (if applicable):
  │  │  ├─ UserBadge (avatar + name)
  │  │  ├─ If claimedByMe: "Release" button
  │  │  ├─ If claimedByOther: Disabled (show name)
  │  │  └─ If unclaimed: "Claim" button (primary blue)
  │  └─ [PLACEHOLDER: Sync history (last sync time, next retry)]
  │
  ├─ Subtasks Section
  │  ├─ ForEach(subtasks)
  │  │  └─ Checkbox + title + edit/delete icons
  │  ├─ "Add subtask" button
  │  └─ [PLACEHOLDER: Subtask progress bar]
  │
  ├─ Notes Section (YOUR DIFFERENTIATOR)
  │  ├─ NoteStack (140pt fixed, clipped)
  │  │  ├─ Previous notes partially visible
  │  │  ├─ Each shows: timestamp, createdBy UserBadge, content (2-line limit)
  │  │  ├─ Edit/Delete icons per note
  │  │  └─ Shadow gradient overlay (indicates more above)
  │  │
  │  └─ NoteInputArea (always below)
  │     ├─ TextEditor (minHeight: 80, maxHeight: 200)
  │     ├─ Placeholder: "Add a note..."
  │     ├─ [Save] [Cancel] buttons
  │     ├─ Current user badge (who's writing)
  │     ├─ [PLACEHOLDER: @ mentions for other realtors]
  │     └─ [PLACEHOLDER: Image/file attachment button]

---

Perfect. Now I understand the exact interaction pattern you need. Here's the complete layout specification for your **Notes Section with Partial Visibility + Shadow Overflow**:

***

## **NOTES SECTION ARCHITECTURE (Detailed Layout)**

### **Visual Hierarchy (From Bottom to Top)**
`[Collapsing Header - Above everything]
        ↓
[SHADOW GRADIENT - Visual separator indicating notes above]
        ↓
[NOTES STACK - Partially Visible]
  └─ Previous Note 1 (Clipped, ~40% visible)
  └─ Previous Note 2 (Clipped, ~30% visible)
  └─ Previous Note 3 (Clipped, ~20% visible)
        ↓
[TEXT INPUT AREA - Full width, always visible]
  └─ TextEditor (editable current note)
  └─ "Add Note" / "Save" buttons`

***

## **DETAILED COMPONENT SPECIFICATIONS**

### **1. Notes Stack Container**
SwiftUI Component: `VStack` with `.frame(height: 140)` and `.clipped()`

**Properties**:
- **Height**: Fixed 140pt (shows ~3 previous notes partially)
- **Clipping**: `.clipped()` modifier to cut off overflow
- **Background**: `.background(Color.clear)`
- **Spacing**: 12pt between each note card

**Key Technical Detail**:[1][2]
- Use `.scrollClipDisabled(false)` if inside ScrollView (iOS 17+)
- Or set `.frame(height: 140)` + `.clipped()` to establish hard boundary
- Shadow rendered OUTSIDE this boundary must use overlay technique

### **2. Shadow Gradient (Overflow Indicator)**
SwiftUI Component: `LinearGradient` overlay above notes stack

**Properties**:
- **Position**: Sits directly above notes stack (between header and notes)
- **Height**: 12pt
- **Gradient**: From black `.opacity(0.15)` at top → `.opacity(0)` at bottom
- **Direction**: Vertical (top to bottom fade)
- **Applied via**: `.overlay()` on notes container

**Effect**: Creates visual illusion that notes continue upward off-screen

`Linear Gradient:
  Top:    Black 15% opacity
  Middle: Black 7% opacity
  Bottom: Black 0% opacity (fully transparent)`

### **3. Previous Notes Cards (Inside Stack)**
SwiftUI Component: `VStack` per note, styled as cards

**Each Note Contains**:
- **Timestamp** (caption font, secondary color, right-aligned)
  - Format: "Nov 29, 3:45 PM"
  - Used as unique identifier for note

- **Content Text** (body font, truncated to 2-3 lines max)
  - `.lineLimit(2)` to cut off overflow

- **Edit/Delete Buttons** (icon buttons, right-aligned)
  - `Image(systemName: "[pencil.circle](http://pencil.circle)")`
  - `Image(systemName: "[trash.circle](http://trash.circle)")`
  - Appear on tap or hover

- **Visual Treatment**:
  - `.background(Color(UIColor.systemGray6))` light / `systemGray5` dark
  - `.cornerRadius(10)`
  - Subtle border: `.border(Color.gray.opacity(0.2), width: 1)`
  - `.padding(.horizontal, 12)`

**Stack Behavior**:[3][4]
- Each card offset slightly downward from previous (`.offset(y: index * 8)`)
- Creates "fanned" or "cascading" visual effect
- Cards naturally clip at 140pt boundary

### **4. Shadow Solution for Clipped Content**[2][5]

**Problem**: Shadow on notes gets clipped by the 140pt frame

**Solution A (Recommended)** - Overlay Shadow:
```

.overlay(alignment: .top) {

LinearGradient(

gradient: Gradient(colors: [

[Color.black](http://Color.black).opacity(0.15),

[Color.black](http://Color.black).opacity(0.05),

Color.clear

]),

startPoint: .top,

endPoint: .bottom

)

.frame(height: 12)

}

```

**Solution B (Alternative)** - Introspect (if using iOS 16):
- Access underlying `UIScrollView.clipsToBounds = false`
- But this requires library (not pure SwiftUI)

**Best for Your Case**: Use **Solution A** — overlay the shadow as a separate layer, not on the notes themselves.

***

## **TEXT INPUT SECTION (Always Visible Below)**

### **Component Stack**
Container: `VStack` with full width

**Subcomponents**:

1. **TextEditor** (For composing new note)
   - `.frame(minHeight: 80, maxHeight: 200)`
   - `.padding(12)`
   - `.background(Color(UIColor.systemGray6))`
   - `.cornerRadius(10)`
   - `.scrollContentBackground(.hidden)`
   - Placeholder: "Add a note..." (secondary text)
   - Font: `.system(.body)`

2. **Action Buttons Row** (below TextEditor)
   - **"Save Note"** button (primary style, blue)
   - **"Cancel"** button (secondary style, grey)
   - `HStack` with `.spacing(12)` and `.padding(12)`
   - Buttons: `.frame(maxWidth: .infinity)` for even distribution

3. **Metadata** (optional, below buttons)
   - Timestamp of when note will be saved
   - Font: `.caption`, secondary color
   - Aligned right

***

## **COMPLETE NOTES SECTION LAYOUT (Top to Bottom)**
```

┌─────────────────────────────┐

│   [Collapsing Header]       │  ← Disappears when scrolling down

│   (Task title, due date)    │

└─────────────────────────────┘

↓

[Gap: 20pt]

┌─────────────────────────────┐

│  ▓▓▓▓ SHADOW GRADIENT ▓▓▓▓   │  ← Visual "more notes above" indicator

│  ▓▓▓▓ (12pt height)  ▓▓▓▓   │     Opacity fades top to bottom

└─────────────────────────────┘

↓

[Gap: 0pt - overlaps slightly]

┌─────────────────────────────┐

│  [Previous Note 1]          │  ← Clipped at ~60% visible

│  "Nov 29, 3:15 PM"          │

│  "Discussed roadmap..."     │

│  ✎ 🗑                        │

├─────────────────────────────┤

│  [Previous Note 2]          │  ← Clipped at ~35% visible

│  "Nov 28, 5:20 PM"          │

│  "Updated timeline..."      │

│  ✎ 🗑                        │

├─────────────────────────────┤

│  [Previous Note 3]          │  ← Clipped at ~15% visible

│  "Nov 27, 2:00 PM"          │

│  "First note on this..."    │

│  ✎ 🗑                        │

│                             │

│  [Content cut off...]       │  ← Hard clip at 140pt

└─────────────────────────────┘

↓

[Gap: 16pt]

┌─────────────────────────────┐

│  [TEXT INPUT AREA]          │

│  ┌─────────────────────────┐│

│  │ "Add a note..."         ││  ← TextEditor (editable)

│  │ (empty or in progress)  ││     minHeight: 80pt

│  │                         ││     maxHeight: 200pt

│  └─────────────────────────┘│

│                             │

│  [Save] [Cancel]            │  ← Action buttons

│                             │

│  Saved 2 minutes ago        │  ← Timestamp (secondary)

└─────────────────────────────┘

```

***

## **KEY SWIFTUI MODIFIERS NEEDED**

| Modifier | Purpose | Component |
|----------|---------|-----------|
| `.frame(height: 140)` | Fixed boundary for notes stack | Notes Container |
| `.clipped()` | Hard cutoff at 140pt | Notes Container |
| `.overlay()` + `LinearGradient` | Shadow effect showing notes above | Above Notes |
| `.lineLimit(2)` | Truncate long note text | Note Text |
| `.offset(y: CGFloat)` | Cascade each note down | Each Note Card |
| `.scrollContentBackground(.hidden)` | Clean TextEditor background | TextEditor |
| `.scrollClipDisabled(true)` | Prevent shadow clipping (iOS 17+) | Parent ScrollView |
| `.padding()` + `.cornerRadius()` | Style individual note cards | Note Cards |

***

## **INTERACTION FLOW**

1. **Initial State**:
   - Header expanded
   - 3 previous notes partially visible (clipped at 140pt)
   - Shadow gradient shows "more notes above"
   - TextEditor empty and ready for input

2. **User Taps TextEditor**:
   - Keyboard appears
   - TextEditor expands to 120pt (or user defined)
   - Notes stay clipped at 140pt

3. **User Scrolls Up** (on parent ScrollView):
   - Header collapses
   - Notes stack remains at fixed height
   - Shadow gradient persists

4. **User Scrolls Down** (on parent ScrollView):
   - Previous notes scroll into view (become fully visible as space opens up)
   - Current TextEditor stays anchored
   - Can expand/contract notes section based on scroll position

5. **User Taps Edit on a Note**:
   - Note card highlights
   - Edit/delete buttons become prominent
   - Can edit or delete that specific note

***

## **CRITICAL SHADOW RENDERING DETAIL**[2]

**The Problem**: `.shadow()` modifier on clipped content gets cut off by the parent frame

**The Solution**: Use `.overlay()` with `LinearGradient` instead of `.shadow()` on the notes themselves. This way:
- Shadow is rendered as a separate visual layer
- Not subject to clipping boundary
- Sits "above" the notes stack visually
- Creates the intended "notes continue upward" effect

**Implementation**:
```

ZStack(alignment: .top) {

// Notes Stack (clipped at 140pt)

VStack { / *notes* / }

.frame(height: 140)

.clipped()

// Shadow Gradient Overlay (NOT clipped)

LinearGradient(...)

.frame(height: 12)

}

```

This way the gradient renders **outside** the clipping boundary.

***

This is the complete specification for your pulley-notes interface. The key is:
- **140pt fixed height** for notes visibility
- **Shadow as overlay gradient** (not `.shadow()` modifier)
- **TextEditor always below**, always visible and editable
- **Cascading offset** for visual depth on previous notes

Sources
[1] Fix Clipping Issues in SwiftUI ScrollView [https://fatbobman.com/en/snippet/preventing-scrollview-content-clipping-in-swiftui/](https://fatbobman.com/en/snippet/preventing-scrollview-content-clipping-in-swiftui/](https://fatbobman.com/en/snippet/preventing-scrollview-content-clipping-in-swiftui/))
[2] SwiftUI: Why are my shadows clipped?? [https://www.bam.tech/en/article/swiftui-why-are-my-shadows-clipped](https://www.bam.tech/en/article/swiftui-why-are-my-shadows-clipped](https://www.bam.tech/en/article/swiftui-why-are-my-shadows-clipped))
[3] shadow will cut by ScrollView #25703 - facebook/react-native [https://github.com/facebook/react-native/issues/25703](https://github.com/facebook/react-native/issues/25703](https://github.com/facebook/react-native/issues/25703))
[4] SwiftUI Live: Peek Scrolling Concept using GeometryReader [https://www.youtube.com/watch?v=onc2xwzjggU](https://www.youtube.com/watch?v=onc2xwzjggU](https://www.youtube.com/watch?v=onc2xwzjggU))
[5] Shadows clipped by ScrollView [https://stackoverflow.com/questions/62157340/shadows-clipped-by-scrollview](https://stackoverflow.com/questions/62157340/shadows-clipped-by-scrollview](https://stackoverflow.com/questions/62157340/shadows-clipped-by-scrollview))
[6] Fix This Problem with SwiftUI Lists [https://www.youtube.com/watch?v=cpT02OtOasE](https://www.youtube.com/watch?v=cpT02OtOasE](https://www.youtube.com/watch?v=cpT02OtOasE))
[7] Building a stack of cards – Flashzilla SwiftUI Tutorial 7/13 [https://www.youtube.com/watch?v=KL1c5Mx3kek](https://www.youtube.com/watch?v=KL1c5Mx3kek](https://www.youtube.com/watch?v=KL1c5Mx3kek))
[8] SwiftUI Example: How to adjust the List View Styling with ... [https://www.youtube.com/watch?v=tjR1hLg4-wc](https://www.youtube.com/watch?v=tjR1hLg4-wc](https://www.youtube.com/watch?v=tjR1hLg4-wc))
[9] SwiftUI Card flip with two views [https://stackoverflow.com/questions/60805244/swiftui-card-flip-with-two-views](https://stackoverflow.com/questions/60805244/swiftui-card-flip-with-two-views](https://stackoverflow.com/questions/60805244/swiftui-card-flip-with-two-views))
[10] Backgrounds and overlays in SwiftUI [https://www.swiftbysundell.com/articles/backgrounds-and-overlays-in-swiftui](https://www.swiftbysundell.com/articles/backgrounds-and-overlays-in-swiftui](https://www.swiftbysundell.com/articles/backgrounds-and-overlays-in-swiftui))
[11] Stacked Cards - Looping Cards - SwiftUI [https://www.youtube.com/watch?v=mEwlTyTtsmE](https://www.youtube.com/watch?v=mEwlTyTtsmE](https://www.youtube.com/watch?v=mEwlTyTtsmE))
[12] SwiftUI: ScrollView clipping [https://philip-trauner.me/blog/post/swiftui-scrollview-clips-to-bounds](https://philip-trauner.me/blog/post/swiftui-scrollview-clips-to-bounds](https://philip-trauner.me/blog/post/swiftui-scrollview-clips-to-bounds))
[13] Shadow is not visible with View() and List() [https://stackoverflow.com/questions/76462407/shadow-is-not-visible-with-view-and-list](https://stackoverflow.com/questions/76462407/shadow-is-not-visible-with-view-and-list](https://stackoverflow.com/questions/76462407/shadow-is-not-visible-with-view-and-list))
[14] Imitating the Card Stack demonstrated by Apple at WWDC [https://www.reddit.com/r/SwiftUI/comments/1dvb06n/imitating_the_card_stack_demonstrated_by_apple_at/](https://www.reddit.com/r/SwiftUI/comments/1dvb06n/imitating_the_card_stack_demonstrated_by_apple_at/](https://www.reddit.com/r/SwiftUI/comments/1dvb06n/imitating_the_card_stack_demonstrated_by_apple_at/))
[15] How to Fix SwiftUI Clipped Images Overlapping Scroll Views [https://www.youtube.com/watch?v=hSZsqWqg0IM](https://www.youtube.com/watch?v=hSZsqWqg0IM](https://www.youtube.com/watch?v=hSZsqWqg0IM))
[16] Creating a list in SwiftUI (4/7) [https://www.cometchat.com/tutorials/creating-a-list-in-swiftui-3-7](https://www.cometchat.com/tutorials/creating-a-list-in-swiftui-3-7](https://www.cometchat.com/tutorials/creating-a-list-in-swiftui-3-7))
[17] SwiftUI: Infinite Scrolling Slideshow/Image Carousel (The ... [https://blog.stackademic.com/swiftui-infinite-scrolling-slideshow-image-carousel-739244177bef](https://blog.stackademic.com/swiftui-infinite-scrolling-slideshow-image-carousel-739244177bef](https://blog.stackademic.com/swiftui-infinite-scrolling-slideshow-image-carousel-739244177bef))
[18] Inner Shadow - SwiftUI Handbook [https://designcode.io/swiftui-handbook-inner-shadow/](https://designcode.io/swiftui-handbook-inner-shadow/](https://designcode.io/swiftui-handbook-inner-shadow/))
[19] SwiftUI animation I made using a combination of materials, ... [https://www.reddit.com/r/iOSProgramming/comments/1l4tx0m/swiftui_animation_i_made_using_a_combination_of/](https://www.reddit.com/r/iOSProgramming/comments/1l4tx0m/swiftui_animation_i_made_using_a_combination_of/](https://www.reddit.com/r/iOSProgramming/comments/1l4tx0m/swiftui_animation_i_made_using_a_combination_of/))
[20] notsobigcompany/CardStack: A SwiftUI view that arranges ... [https://github.com/notsobigcompany/CardStack](https://github.com/notsobigcompany/CardStack](https://github.com/notsobigcompany/CardStack))
[21] Color Shadows and Opacity in SwiftUI [https://www.youtube.com/watch?v=nGENKnaSWPM](https://www.youtube.com/watch?v=nGENKnaSWPM](https://www.youtube.com/watch?v=nGENKnaSWPM))
  │
  └─ Claim/Release Button (bottom)
     ├─ State-dependent styling
     └─ Confirmation sheet on tap

```

---

### **NoteStack**

```
NoteStack<T: WorkItemProtocol>
  ├─ Fixed height: 140pt
  ├─ `.clipped()` to enforce boundary
  ├─ ForEach(item.notes.sorted(by: date, descending: true))
  │  └─ NoteCard
  │     ├─ Timestamp (right-aligned, caption font)
  │     ├─ CreatedBy UserBadge (small avatar + name)
  │     ├─ Content (truncated to 2 lines)
  │     ├─ Edit/Delete buttons (appear on hover/swipe)
  │     ├─ `.offset(y: index * 8)` for cascading effect
  │     └─ [PLACEHOLDER: note.syncStatus indicator]
  │
  └─ Overlay: LinearGradient shadow
     └─ Top: Black 15% → Bottom: Transparent (12pt height)

```

---

### **NoteInputArea**

```
NoteInputArea<T: WorkItemProtocol>
  ├─ TextEditor
  │  ├─ minHeight: 80, maxHeight: 200
  │  ├─ `.scrollContentBackground(.hidden)`
  │  ├─ Background: systemGray6 (light) / systemGray5 (dark)
  │  ├─ Border: 1pt, color-border opacity 0.2
  │  └─ `.cornerRadius(10)`
  │
  ├─ Buttons Row
  │  ├─ [Save] button (primary, blue)
  │  ├─ [Cancel] button (secondary, grey)
  │  └─ Spacing: `.spacing(12)`
  │
  ├─ User Context
  │  ├─ "Added by: [Current User Name]"
  │  ├─ [PLACEHOLDER: Avatar next to name]
  │  └─ Timestamp (will be set on save)
  │
  └─ [PLACEHOLDER: Sync Status Badge]
     ├─ "Saving..." (during upload)
     ├─ Checkmark (synced)
     └─ Error icon (retry prompt)

```

---

### **ClaimButton**

```
ClaimButton<T: WorkItemProtocol>
  ├─ States:
  │  ├─ .unclaimed
  │  │  └─ Button: "Claim" (primary blue)
  │  ├─ .claimedByMe
  │  │  └─ Button: "Release" (secondary grey)
  │  └─ .claimedByOther(user)
  │     └─ Button: "Claimed by [Name]" (disabled grey)
  │
  ├─ On Tap:
  │  ├─ If unclaimed → Show ClaimConfirmationSheet
  │  ├─ If claimedByMe → Show release confirmation
  │  └─ If claimedByOther → No action (disabled)
  │
  └─ After Action:
     ├─ Save to SwiftData immediately (optimistic update)
     ├─ Sync to Supabase in background
     └─ [PLACEHOLDER: Real-time update to other users via channel]

```

---

### **2.3 Utility Components**

```
UserBadge
  ├─ Shows: Avatar (12-16pt circle) + Name
  ├─ [PLACEHOLDER: On hover/tap → Show user profile/options]
  └─ Clickable to view user's other items

DateFormatter Utilities
  ├─ "Nov 29, 3:45 PM" (note timestamps)
  ├─ "Tomorrow at 2:00 PM" (due dates, relative)
  ├─ "3 days ago" (relative time)
  └─ [PLACEHOLDER: Localization for international dates]

```

---

## **PHASE 3: LIST & DETAIL SCREENS (Weeks 3-4)**

### **3.1 List Screens**

```
TaskListView
  ├─ NavigationStack
  ├─ Header:
  │  ├─ Title: "Tasks"
  │  ├─ [PLACEHOLDER: Search bar with filters]
  │  └─ [PLACEHOLDER: Sync status indicator (top-right)]
  │
  ├─ SegmentedFilter (3 options)
  │  ├─ "My Tasks" (claimedBy == currentStaff)
  │  ├─ "Others'" (claimedBy != currentStaff AND claimedBy != null)
  │  └─ "Unclaimed" (claimedBy == null)
  │
  ├─ List (`.listStyle(.plain)`, `.scrollContentBackground(.hidden)`)
  │  ├─ Section: "Overdue" (red header, `.textCase(nil)`)
  │  │  └─ ForEach(overdueFilteredTasks)
  │  │     └─ WorkItemRow<Task>
  │  │
  │  ├─ Section: "Today"
  │  │  └─ ForEach(todayFilteredTasks)
  │  │     └─ WorkItemRow<Task>
  │  │
  │  ├─ Section: "Tomorrow"
  │  │  └─ ForEach(tomorrowFilteredTasks)
  │  │     └─ WorkItemRow<Task>
  │  │
  │  └─ Section: "Upcoming"
  │     └─ ForEach(upcomingFilteredTasks)
  │        └─ WorkItemRow<Task>
  │
  ├─ Magic Plus Button
  │  └─ On tap: .sheet(isPresented: $showQuickEntry) { QuickEntrySheet(...) }
  │
  └─ [PLACEHOLDER: Pull-to-refresh gesture → Call syncManager.syncDown()]

ActivityListView (Identical structure to TaskListView)
  ├─ Same segmentation, sections, components
  └─ ForEach(WorkItemRow<Activity>)

ListingListView
  ├─ NavigationStack
  ├─ List
  │  ├─ Grouped by ownedBy (Realtor) or assignedStaff [PLACEHOLDER: Or searchable by address]
  │  └─ ForEach(listings)
  │     ├─ ListingRow
  │     │  ├─ Address (prominent, bold)
  │     │  ├─ Realtor name (secondary)
  │     │  ├─ Task count badge
  │     │  ├─ Activity count badge
  │     │  └─ Status badge (Active/Pending/Closed)
  │     │
  │     └─ On tap: NavigationLink → ListingDetailView
  │
  └─ Magic Plus Button → QuickEntrySheet (creates Listing)

```

---

### **3.2 Detail Screens**

```
TaskDetailView (Wrapper)
  ├─ Input: @State var task: Task
  └─ Returns: WorkItemDetailView<Task>(item: $task)

ActivityDetailView (Wrapper)
  ├─ Input: @State var activity: Activity
  └─ Returns: WorkItemDetailView<Activity>(item: $activity)

ListingDetailView (Full Custom Screen)
  ├─ Header:
  │  ├─ Address (large, bold)
  │  ├─ Owner (Realtor) badge + Assigned Staff badge
  │  ├─ Status badge + [Edit] button
  │  └─ [PLACEHOLDER: Price, bedrooms, bathrooms]
  │
  ├─ TabView or Picker (3 tabs)
  │  ├─ Tab 1: Tasks
  │  │  └─ ForEach(listing.tasks) WorkItemRow<Task>
  │  │
  │  ├─ Tab 2: Activities
  │  │  └─ ForEach(listing.activities) WorkItemRow<Activity>
  │  │
  │  └─ Tab 3: Notes (Listing-level)
  │     ├─ NoteStack (listing.notes)
  │     └─ NoteInputArea (for listing)
  │
  └─ Bottom: [Edit Listing] [Delete Listing] buttons

```

---

## **PHASE 4: MODAL SHEETS (Week 4)**

```
QuickEntrySheet
  ├─ Inputs:
  │  ├─ @Binding var isPresented: Bool
  │  ├─ @Binding var itemType: ItemType (Task | Activity)
  │  ├─ @State var title: String = ""
  │  ├─ @State var listing: Listing? = nil [PLACEHOLDER]
  │  ├─ @State var priority: Priority = .Medium
  │  └─ [PLACEHOLDER: @State var dueDate: Date?, type: ActivityType?, etc.]
  │
  ├─ UI:
  │  ├─ Drag handle (standard iOS)
  │  ├─ TextField: "Task/Activity title"
  │  ├─ Picker: Select Listing (optional)
  │  ├─ Priority selector (4 colored dots)
  │  ├─ [Add] [Cancel] buttons
  │  └─ [PLACEHOLDER: Additional fields per type]
  │
  └─ On Save:
     ├─ Save to SwiftData (local)
     ├─ Enqueue for sync to Supabase
     ├─ Dismiss sheet
     └─ Show toast: "Task added" [PLACEHOLDER]

ClaimConfirmationSheet
  ├─ Title: "Claim '[task.title]'?"
  ├─ Message: "This task will be assigned to you"
  ├─ [Confirm] [Cancel] buttons
  ├─ On Confirm:
  │  ├─ Update task.claimedBy = [currentStaff.id](http://currentStaff.id)
  │  ├─ Save to SwiftData
  │  ├─ Sync to Supabase
  │  └─ [PLACEHOLDER: Notify other team members via push]
  └─ [PLACEHOLDER: "Claiming..." spinner during sync]

```

---

## **PHASE 5: MULTIPLATFORM SUPPORT (Weeks 4-5)**

### **5.1 iPad Support (Priority: HIGH)**

```
// Use NavigationSplitView for master-detail layout
NavigationSplitView(columnVisibility: $columnVisibility) {
  // Sidebar: Task/Activity/Listing list
  TaskListView()
} detail: {
  // Main detail: WorkItemDetailView or ListingDetailView
  if let selectedTask = selectedTask {
    WorkItemDetailView<Task>(item: $selectedTask)
  } else {
    Text("Select a task to view details")
  }
}

[PLACEHOLDER: iPad-specific behaviors]
  ├─ Landscape: Full master-detail visible
  ├─ Portrait: Master on left (40%), Detail on right (60%)
  ├─ Collapsible master (hamburger button)
  ├─ Multi-window support (open multiple tasks simultaneously)
  └─ Larger touch targets, optimized spacing for bigger screen

```

**Structure File Organization**:

```
DispatchApp.swift
  ├─ @Environment(\\.horizontalSizeClass) var sizeClass
  ├─ if sizeClass == .compact { ... } // iPhone
  └─ else { ... } // iPad/Mac

```

---

### **5.2 macOS Support (Priority: LATER)**

```
[PLACEHOLDER: Phase 2 - After iOS/iPad stable]

For now: Enable "Designed for iPad" on Apple Silicon Macs
  └─ Zero effort, 85% functionality

When ready:
  ├─ Create macOS-specific views (menu bar, keyboard shortcuts)
  ├─ Multi-window support
  ├─ Context menus (right-click)
  ├─ Drag-and-drop from Finder
  └─ Keyboard-first navigation

```

---

## **PHASE 6: OFFLINE-FIRST SYNC + REALTIME (Weeks 5-6)**

### **6.1 SyncManager Implementation**

```
class SyncManager: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?

    let supabaseClient: SupabaseClient
    let modelContext: ModelContext
    let currentUserID: UUID

    // SYNC DOWN (Supabase → SwiftData)
    func syncDown() async {
        do {
            isSyncing = true

            // 1. Fetch all tasks/activities/listings updated since lastSyncTime
            let tasks = try await supabaseClient
                .from("tasks")
                .select()
                .gt("updated_at", value: lastSyncTime?.ISO8601Format() ?? "")
                .execute()
                .decoded([Task].self)

            // 2. Upsert into SwiftData
            for task in tasks {
                // Check if exists locally
                let existingTask = ... // query SwiftData
                if let existing = existingTask {
                    // Update (merge changes)
                    existing.title = task.title
                    existing.completed = task.completed
                    // ... update other fields
                } else {
                    // Insert new
                    modelContext.insert(task)
                }
            }

            try [modelContext.save](http://modelContext.save)()
            lastSyncTime = Date()

        } catch {
            syncError = error.localizedDescription
            [PLACEHOLDER: exponential backoff retry logic]
        }

        isSyncing = false
    }

    // SYNC UP (SwiftData → Supabase)
    func syncUp() async {
        do {
            isSyncing = true

            // 1. Find all local items marked as dirty
            let descriptor = FetchDescriptor<Task>(
                predicate: #Predicate { $0.isDirty == true }
            )
            let dirtyTasks = try modelContext.fetch(descriptor)

            // 2. Push to Supabase
            for task in dirtyTasks {
                _ = try await supabaseClient
                    .from("tasks")
                    .upsert(task)
                    .execute()

                // 3. Mark clean
                task.isDirty = false
                task.syncedAt = Date()
            }

            try [modelContext.save](http://modelContext.save)()

        } catch {
            syncError = error.localizedDescription
            [PLACEHOLDER: retry logic]
        }

        isSyncing = false
    }

    // REALTIME LISTENER (Supabase → SwiftData, live)
    func listenForRealtimeChanges() {
        let channel = [supabaseClient.channel](http://supabaseClient.channel)("tasks")

        channel.on(
            .insert,
            handler: { message in
                // Decode and insert into SwiftData
                let task = try JSONDecoder().decode(Task.self, from: message.payload)
                self.modelContext.insert(task)
                try? [self.modelContext.save](http://self.modelContext.save)()
            }
        )

        channel.on(
            .update,
            handler: { message in
                // Fetch updated task from SwiftData and merge
                let updatedTask = try JSONDecoder().decode(Task.self, from: message.payload)
                // ... merge logic
            }
        )

        channel.on(
            .delete,
            handler: { message in
                // Mark as deleted or remove from SwiftData
            }
        )

        Task {
            try await channel.subscribe()
        }
    }
}

```

---

### **6.2 App Lifecycle Integration**

```
@main
struct DispatchApp: App {
    @StateObject private var syncManager = SyncManager()
    @Environment(\\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(syncManager)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                // App came to foreground → sync immediately
                Task {
                    await syncManager.syncDown()
                    syncManager.listenForRealtimeChanges()
                }
            } else if newPhase == .background {
                // App backgrounded → save pending changes
                Task {
                    await syncManager.syncUp()
                }
            }
        }
    }
}

```

---

### **6.3 Background Refresh (Optional, Later)**

```
[PLACEHOLDER: Implement after MVP]

// In your app delegate
func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    // Request background app refresh capability
    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.dispatch.sync",
        using: nil
    ) { task in
        Task {
            await SyncManager.shared.syncDown()
            task.setTaskCompleted(success: true)
        }
    }
    return true
}

// Or: Use Silent Push Notifications when high-priority data changes
// More reliable than standard background fetch

```

---

## **PHASE 7: MULTIPLATFORM BUILD CONFIGURATION**

### **7.1 Xcode Project Structure**

```
Dispatch/
├── Dispatch.xcodeproj
│  ├── DispatchKit/ (Shared framework)
│  │  ├── Foundation/
│  │  ├── Protocols/
│  │  ├── Models/
│  │  ├── Services/ (SyncManager, etc.)
│  │  └── Components/
│  │
│  ├── DispatchiOS/ (iOS target)
│  │  ├── Views/
│  │  ├── App.swift
│  │  └── [PLACEHOLDER: iOS-specific configurations]
│  │
│  ├── DispatchiPadOS/ [PLACEHOLDER: Or merge with iOS using conditional compilation]
│  │
│  └── DispatchmacOS/ [PLACEHOLDER: Phase 2]
│     ├── Views/ (macOS-specific)
│     └── App.swift
│
└── [PLACEHOLDER: DispatchWatch/ for future watchOS support]

```

### **7.2 Build Configuration**

```swift
// Use conditional compilation to share 90% of code
#if os(iOS)
    // iOS-specific imports/behaviors
#elseif os(macOS)
    // macOS-specific imports/behaviors
#endif

// Or use view modifiers for platform-specific UI
extension View {
    func applyPlatformModifiers() -> some View {
        #if os(iOS)
            return self.ignoresSafeArea(.keyboard)
        #else
            return self
        #endif
    }
}

```

---

## **FINAL TIMELINE & PRIORITIES**

| Phase | Focus | Duration | Start | End |
| --- | --- | --- | --- | --- |
| **P1** | Models + Supabase schema + SwiftData setup | 2 weeks | Week 1 | Week 2 |
| **P2** | Shared components (protocols, generics) | 1 week | Week 2 | Week 3 |
| **P3** | List & detail screens | 1 week | Week 3 | Week 4 |
| **P4** | Modal sheets + interactions | 1 week | Week 4 | Week 5 |
| **P5** | iPad multiplatform support | 1 week | Week 5 | Week 6 |
| **P6** | Offline-first sync + realtime | 1 week | Week 6 | Week 7 |
| **P7** | Testing + launch | 1 week | Week 7 | Week 8 |

---

## **KEY PLACEHOLDERS TO FILL IN LATER**

- [x]  ~~ActivityType enum (Call, Email, Meeting, ShowProperty, etc.)~~ → Implemented in Section 1.1
- [ ]  Custom field system (extensible metadata per listing)
- [ ]  Mention system (@realtor notifications)
- [ ]  File/image attachments in notes
- [ ]  Edit history for notes (show who edited what when)
- [x]  ~~Permission/role system (admin, agent, broker)~~ → Implemented as UserType enum (realtor, admin, marketing, exec)
- [ ]  Listing photos + MLS integration
- [ ]  Background sync retry logic + exponential backoff
- [ ]  Silent push notifications
- [ ]  Search + advanced filtering
- [ ]  Analytics + crash reporting
- [ ]  macOS-specific workflows (multi-window, keyboard shortcuts)
- [ ]  watchOS complications [FUTURE]

---

**This plan balances fast MVP launch with enterprise-grade architecture. You can start coding tomorrow on Phase 1, and by Week 2 have a functional prototype with live sync.**

---

# **DISPATCH: IMPLEMENTATION GUIDE FOR JR DEV**

## **Prerequisites Checklist**

Before starting, ensure you have:

- [ ]  Xcode 15.1+ (iOS 17+ minimum)
- [ ]  Swift 5.9+
- [ ]  Supabase project created ([`supabase.co`](http://supabase.co))

### **Supabase Credentials**

| Key | Value |
| --- | --- |
| **Project URL** | [`https://kukmshbkzlskyuacgzbo.supabase.co`](https://kukmshbkzlskyuacgzbo.supabase.co) |
| **Anon Key** | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt1a21zaGJremxza3l1YWNnemJvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI3OTUyOTAsImV4cCI6MjA3ODM3MTI5MH0.Jax3HtgBuu5COWr_p0mXiVuXlCFDsQaj9VUEQGxUOcE` |
- [ ]  `supabase-swift` package added to Xcode
- [ ]  Local Supabase instance (optional, but recommended): `supabase start` via Docker
- [ ]  Basic SwiftUI knowledge (State, Binding, List, NavigationStack)
- [ ]  Familiar with Swift `Codable` and protocols
- [ ]  Git set up for version control

---

## **SECTION 1: CONCRETE DATA MODEL DEFINITIONS**

### **1.1 Enums**

Create `DispatchKit/Models/Enums.swift`:

```swift
import Foundation

// Priority levels
enum Priority: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"

    var color: String {
        switch self {
        case .low: return "gray"
        case .medium: return "yellow"
        case .high: return "orange"
        case .urgent: return "red"
        }
    }

    var displayName: String {
        self.rawValue.capitalized
    }
}

// Activity types
enum ActivityType: String, Codable, CaseIterable {
    case call = "call"
    case email = "email"
    case meeting = "meeting"
    case showProperty = "show_property"
    case followUp = "follow_up"
    case other = "other"

    var displayName: String {
        switch self {
        case .call: return "☎️ Call"
        case .email: return "📧 Email"
        case .meeting: return "📅 Meeting"
        case .showProperty: return "🏠 Show Property"
        case .followUp: return "↩️ Follow-up"
        case .other: return "📝 Other"
        }
    }
}

// Listing status
enum ListingStatus: String, Codable, CaseIterable {
    case draft = "draft"
    case active = "active"
    case pending = "pending"
    case closed = "closed"
    case deleted = "deleted"  // Soft delete

    var displayName: String {
        self.rawValue.capitalized
    }
}

// Listing type
enum ListingType: String, Codable, CaseIterable {
    case sale = "sale"              // For sale listing
    case lease = "lease"            // For lease/rent
    case preListing = "pre_listing" // Coming soon / pocket listing
    case rental = "rental"          // Property management rental
    case other = "other"

    var displayName: String {
        switch self {
        case .sale: return "For Sale"
        case .lease: return "For Lease"
        case .preListing: return "Pre-Listing"
        case .rental: return "Rental"
        case .other: return "Other"
        }
    }
}

// Task status (replaces simple completed Bool)
enum TaskStatus: String, Codable, CaseIterable {
    case open = "open"
    case inProgress = "in_progress"
    case completed = "completed"
    case deleted = "deleted"  // Soft delete

    var displayName: String {
        switch self {
        case .open: return "Open"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .deleted: return "Deleted"
        }
    }

    var isActive: Bool {
        self != .deleted && self != .completed
    }
}

// Activity status (replaces simple completed Bool)
enum ActivityStatus: String, Codable, CaseIterable {
    case open = "open"
    case inProgress = "in_progress"
    case completed = "completed"
    case deleted = "deleted"  // Soft delete

    var displayName: String {
        switch self {
        case .open: return "Open"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .deleted: return "Deleted"
        }
    }

    var isActive: Bool {
        self != .deleted && self != .completed
    }
}

// Parent type for notes/subtasks
enum ParentType: String, Codable {
    case task = "task"
    case activity = "activity"
    case listing = "listing"
}

// Claim state (for UI display)
enum ClaimState: Codable {
    case unclaimed
    case claimedBy(user: User)
    case claimedByOther(user: User)

    var isClaimed: Bool {
        switch self {
        case .unclaimed: return false
        case .claimedBy, .claimedByOther: return true
        }
    }
}

// Claim action type (for history tracking)
enum ClaimAction: String, Codable {
    case claimed = "claimed"     // Staff member claimed this item
    case released = "released"   // Staff member released/unclaimed this item

    var displayName: String {
        switch self {
        case .claimed: return "Claimed"
        case .released: return "Released"
        }
    }
}

// Conflict resolution strategy
enum ConflictStrategy: String, Codable {
    case lastWriteWins = "last_write_wins"
    case serverWins = "server_wins"
    case manual = "manual"
}

// Sync status
enum SyncStatus: String, Codable {
    case synced = "synced"
    case pending = "pending"
    case error = "error"
    case syncing = "syncing"
}

// Creation source - where was this item created?
enum CreationSource: String, Codable, CaseIterable {
    case dispatch = "dispatch"       // Created directly in Dispatch app
    case slack = "slack"             // Created via Slack (through Vecrel)
    case realtorApp = "realtor_app"  // Created in the Realtor-facing app
    case api = "api"                 // Created via API/webhook
    case import_ = "import"          // Bulk imported

    var displayName: String {
        switch self {
        case .dispatch: return "Dispatch App"
        case .slack: return "Slack"
        case .realtorApp: return "Realtor App"
        case .api: return "API"
        case .import_: return "Import"
        }
    }

    var isExternal: Bool {
        self != .dispatch && self != .realtorApp
    }
}

// User types
enum UserType: String, Codable, CaseIterable {
    case realtor = "realtor"       // Declares listings & tasks, uses separate app
    case admin = "admin"           // Staff: claims & executes tasks in Dispatch
    case marketing = "marketing"   // Staff: marketing-specific tasks in Dispatch
    case exec = "exec"             // Oversight, dashboards, approvals

    var isStaff: Bool {
        switch self {
        case .admin, .marketing: return true
        case .realtor, .exec: return false
        }
    }

    var usesDispatchApp: Bool {
        switch self {
        case .admin, .marketing, .exec: return true
        case .realtor: return false
        }
    }

    var displayName: String {
        switch self {
        case .realtor: return "Realtor"
        case .admin: return "Admin"
        case .marketing: return "Marketing"
        case .exec: return "Executive"
        }
    }
}
```

---

### **1.2 Core Data Models**

Create `DispatchKit/Models/Models.swift`:

```swift
import Foundation
import SwiftData

// USER (with UserType to distinguish Realtor, Staff, Exec)
@Model final class User: Codable, Identifiable {
    var id: UUID
    var name: String
    var email: String
    var avatarURL: URL?
    var userType: UserType
    @Relationship(deleteRule: .cascade) var ownedListings: [Listing] = []  // For realtors
    @Relationship var assignedListings: [Listing] = []  // For staff
    @Relationship var claimedTasks: [Task] = []  // For staff
    @Relationship var claimedActivities: [Activity] = []  // For staff

    var isStaff: Bool { userType.isStaff }
    var usesDispatchApp: Bool { userType.usesDispatchApp }

    enum CodingKeys: String, CodingKey {
        case id, name, email
        case avatarURL = "avatar_url"
        case userType = "user_type"
    }

    init(id: UUID = UUID(), name: String, email: String, userType: UserType, avatarURL: URL? = nil) {
        
```

**Acceptance Criteria**:

- [ ]  All enums compile and have appropriate `Codable` conformance
- [ ]  All `@Model` classes have `id: UUID` and `Codable` support
- [ ]  Relationships use `@Relationship(deleteRule: .cascade)` to avoid orphans
- [ ]  `WorkItemProtocol` can be used as a generic constraint in views

---

## **SECTION 2: API CONTRACTS & SUPABASE SCHEMA**

### **2.1 Postgres Schema**

Create file `supabase/schema.sql`:

```sql
-- =============================================
-- USERS (Realtors, Staff, Execs - all in one table)
-- =============================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    avatar_url TEXT,
    user_type TEXT NOT NULL DEFAULT 'admin',  -- 'realtor', 'admin', 'marketing', 'exec'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_user_type ON users(user_type);

-- =============================================
-- LISTINGS
-- =============================================
CREATE TABLE listings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    address TEXT NOT NULL,
    city TEXT DEFAULT '',
    state TEXT DEFAULT '',
    zip TEXT DEFAULT '',
    listing_type TEXT DEFAULT 'sale',  -- 'sale', 'lease', 'pre_listing', 'rental', 'other'
    status TEXT DEFAULT 'draft',       -- 'draft', 'active', 'pending', 'closed', 'deleted'
    
    -- Ownership & Assignment
    owned_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,      -- Realtor who owns this listing
    assigned_staff UUID REFERENCES users(id) ON DELETE SET NULL,        -- Staff member assigned to work on it
    
    -- Creation source tracking
    created_via TEXT DEFAULT 'dispatch',  -- 'dispatch', 'slack', 'realtor_app', 'api', 'import'
    source_slack_messages JSONB,          -- Array of Slack message URLs if created_via = 'slack'
    
    -- Milestone timestamps
    activated_at TIMESTAMPTZ,             -- When listing went active/live
    pending_at TIMESTAMPTZ,               -- When listing went under contract
    closed_at TIMESTAMPTZ,                -- When deal closed
    deleted_at TIMESTAMPTZ,               -- When soft deleted
    
    -- Standard timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    synced_at TIMESTAMPTZ
);

CREATE INDEX idx_listings_owned_by ON listings(owned_by);
CREATE INDEX idx_listings_assigned_staff ON listings(assigned_staff);
CREATE INDEX idx_listings_status ON listings(status);
CREATE INDEX idx_listings_updated_at ON listings(updated_at);

-- =============================================
-- TASKS
-- =============================================
CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT DEFAULT '',
    due_date TIMESTAMPTZ,
    priority TEXT DEFAULT 'medium',        -- 'low', 'medium', 'high', 'urgent'
    status TEXT DEFAULT 'open',            -- 'open', 'in_progress', 'completed', 'deleted'
    
    -- Ownership & Claims
    declared_by UUID NOT NULL REFERENCES users(id),           -- Realtor who declared this task
    claimed_by UUID REFERENCES users(id) ON DELETE SET NULL,  -- Staff member who currently has it claimed
    listing UUID REFERENCES listings(id) ON DELETE SET NULL,
    
    -- Creation source tracking
    created_via TEXT DEFAULT 'dispatch',   -- 'dispatch', 'slack', 'realtor_app', 'api', 'import'
    source_slack_messages JSONB,           -- Array of Slack message URLs if created_via = 'slack'
    
    -- Milestone timestamps
    claimed_at TIMESTAMPTZ,                -- When staff first claimed this
    completed_at TIMESTAMPTZ,              -- When marked completed
    deleted_at TIMESTAMPTZ,                -- When soft deleted
    
    -- Standard timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    synced_at TIMESTAMPTZ
);

CREATE INDEX idx_tasks_declared_by ON tasks(declared_by);
CREATE INDEX idx_tasks_claimed_by ON tasks(claimed_by);
CREATE INDEX idx_tasks_listing ON tasks(listing);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_due_date ON tasks(due_date);
CREATE INDEX idx_tasks_updated_at ON tasks(updated_at);

-- =============================================
-- ACTIVITIES
-- =============================================
CREATE TABLE activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT DEFAULT '',
    activity_type TEXT DEFAULT 'other',    -- 'call', 'email', 'meeting', 'show_property', 'follow_up', 'other'
    due_date TIMESTAMPTZ,
    status TEXT DEFAULT 'open',            -- 'open', 'in_progress', 'completed', 'deleted'
    duration_minutes INTEGER,              -- For call/meeting tracking
    
    -- Ownership & Claims
    declared_by UUID NOT NULL REFERENCES users(id),           -- Realtor who declared this activity
    claimed_by UUID REFERENCES users(id) ON DELETE SET NULL,  -- Staff member who currently has it claimed
    listing UUID REFERENCES listings(id) ON DELETE SET NULL,
    
    -- Creation source tracking
    created_via TEXT DEFAULT 'dispatch',   -- 'dispatch', 'slack', 'realtor_app', 'api', 'import'
    source_slack_messages JSONB,           -- Array of Slack message URLs if created_via = 'slack'
    
    -- Milestone timestamps
    claimed_at TIMESTAMPTZ,                -- When staff first claimed this
    completed_at TIMESTAMPTZ,              -- When marked completed
    deleted_at TIMESTAMPTZ,                -- When soft deleted
    
    -- Standard timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    synced_at TIMESTAMPTZ
);

CREATE INDEX idx_activities_declared_by ON activities(declared_by);
CREATE INDEX idx_activities_claimed_by ON activities(claimed_by);
CREATE INDEX idx_activities_listing ON activities(listing);
CREATE INDEX idx_activities_status ON activities(status);
CREATE INDEX idx_activities_due_date ON activities(due_date);
CREATE INDEX idx_activities_updated_at ON activities(updated_at);

-- =============================================
-- NOTES (Sub-entity, can attach to Task/Activity/Listing)
-- =============================================
CREATE TABLE notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content TEXT NOT NULL,
    parent_type TEXT NOT NULL,             -- 'task', 'activity', 'listing'
    parent_id UUID NOT NULL,
    created_by UUID NOT NULL REFERENCES users(id),
    edited_at TIMESTAMPTZ,
    edited_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    synced_at TIMESTAMPTZ
);

CREATE INDEX idx_notes_parent ON notes(parent_type, parent_id);
CREATE INDEX idx_notes_created_by ON notes(created_by);
CREATE INDEX idx_notes_created_at ON notes(created_at DESC);

-- =============================================
-- SUBTASKS (Sub-entity, can attach to Task/Activity)
-- =============================================
CREATE TABLE subtasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    parent_type TEXT NOT NULL,             -- 'task', 'activity'
    parent_id UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    synced_at TIMESTAMPTZ
);

CREATE INDEX idx_subtasks_parent ON subtasks(parent_type, parent_id);

-- =============================================
-- STATUS_CHANGES (Audit trail for status transitions)
-- =============================================
CREATE TABLE status_changes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_type TEXT NOT NULL,             -- 'task', 'activity', 'listing'
    parent_id UUID NOT NULL,
    old_status TEXT,                       -- NULL for initial creation
    new_status TEXT NOT NULL,
    changed_by UUID NOT NULL REFERENCES users(id),
    reason TEXT,                           -- Optional note explaining the change
    changed_at TIMESTAMPTZ DEFAULT NOW(),
    synced_at TIMESTAMPTZ
);

CREATE INDEX idx_status_changes_parent ON status_changes(parent_type, parent_id);
CREATE INDEX idx_status_changes_changed_at ON status_changes(changed_at DESC);

-- =============================================
-- CLAIM_EVENTS (Audit trail for claim/release actions)
-- =============================================
CREATE TABLE claim_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_type TEXT NOT NULL,             -- 'task', 'activity'
    parent_id UUID NOT NULL,
    action TEXT NOT NULL,                  -- 'claimed', 'released'
    user_id UUID NOT NULL REFERENCES users(id),
    reason TEXT,                           -- Optional note (e.g., "reassigning to marketing")
    performed_at TIMESTAMPTZ DEFAULT NOW(),
    synced_at TIMESTAMPTZ
);

CREATE INDEX idx_claim_events_parent ON claim_events(parent_type, parent_id);
CREATE INDEX idx_claim_events_user ON claim_events(user_id);
CREATE INDEX idx_claim_events_performed_at ON claim_events(performed_at DESC);

-- =============================================
-- SYNC_METADATA (Track last sync per user)
-- =============================================
CREATE TABLE sync_metadata (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    last_sync_tasks TIMESTAMPTZ DEFAULT NOW(),
    last_sync_activities TIMESTAMPTZ DEFAULT NOW(),
    last_sync_listings TIMESTAMPTZ DEFAULT NOW(),
    last_sync_notes TIMESTAMPTZ DEFAULT NOW(),
    last_sync_subtasks TIMESTAMPTZ DEFAULT NOW(),
    last_sync_status_changes TIMESTAMPTZ DEFAULT NOW(),
    last_sync_claim_events TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
-- ROW-LEVEL SECURITY (RLS)

-- =============================================
-- =============================================
-- =============================================
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
-- ROW-LEVEL SECURITY (RLS)
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
-- Policy: Realtors can see tasks they created, claimed, or belong to their listings
ALTER TABLE status_changes ENABLE ROW LEVEL SECURITY;
ALTER TABLE claim_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE subtasks ENABLE ROW LEVEL SECURITY;
-- Realtors can see tasks they declared (via separate app)
    FOR ALL

-- TASKS: Staff see claimed + assigned listings; Realtors see declared + owned listings; Execs see all
CREATE POLICY task_access ON tasks
        OR claimed_by = auth.uid()
    USING (
        declared_by = auth.uid()  -- Realtor who declared it
        OR claimed_by = auth.uid()  -- Staff who claimed it
        OR listing IN (SELECT id FROM listings WHERE assigned_staff = auth.uid())  -- Staff assigned to listing
        OR listing IN (SELECT id FROM listings WHERE owned_by = auth.uid())  -- Realtor who owns listing
        OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND user_type = 'exec')  -- Execs see all
    );
-- Similar policies for activities, listings, notes...
```

-- ACTIVITIES: Same pattern as tasks

CREATE POLICY activity_access ON activities

FOR ALL

USING (

declared_by = auth.uid()

OR claimed_by = auth.uid()

OR listing IN (SELECT id FROM listings WHERE assigned_staff = auth.uid())

OR listing IN (SELECT id FROM listings WHERE owned_by = auth.uid())

OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND user_type = 'exec')

);

-- LISTINGS: Realtors see owned; Staff see assigned; Execs see all

CREATE POLICY listing_access ON listings

FOR ALL

USING (

owned_by = auth.uid()

OR assigned_staff = auth.uid()

OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND user_type = 'exec')

);

-- NOTES: Can see notes on entities you can access

CREATE POLICY note_access ON notes

FOR ALL

USING (

(parent_type = 'task' AND parent_id IN (SELECT id FROM tasks))

OR (parent_type = 'activity' AND parent_id IN (SELECT id FROM activities))

OR (parent_type = 'listing' AND parent_id IN (SELECT id FROM listings))

);

-- SUBTASKS: Can see subtasks on entities you can access

CREATE POLICY subtask_access ON subtasks

FOR ALL

USING (

(parent_type = 'task' AND parent_id IN (SELECT id FROM tasks))

OR (parent_type = 'activity' AND parent_id IN (SELECT id FROM activities))

);

-- STATUS_CHANGES: Can see history on entities you can access

CREATE POLICY status_change_access ON status_changes

FOR ALL

USING (

(parent_type = 'task' AND parent_id IN (SELECT id FROM tasks))

OR (parent_type = 'activity' AND parent_id IN (SELECT id FROM activities))

OR (parent_type = 'listing' AND parent_id IN (SELECT id FROM listings))

);

-- CLAIM_EVENTS: Can see history on entities you can access

CREATE POLICY claim_event_access ON claim_events

FOR ALL

USING (

(parent_type = 'task' AND parent_id IN (SELECT id FROM tasks))

OR (parent_type = 'activity' AND parent_id IN (SELECT id FROM activities))

);

---

### **2.2 DTOs (Codable Models for Supabase)**

Create `DispatchKit/API/DTOs.swift`:

```swift
import Foundation
// =============================================
// USER DTO
// =============================================
struct SupabaseUserDTO: Codable {
    let id: UUID
    let name: String
    let email: String
    let avatar_url: String?
    let user_type: String
    let created_at: Date
    let updated_at: Date

        let user = User(
            id: id,
            name: name,
            email: email,
            userType: UserType(rawValue: user_type) ?? .admin,
            avatarURL: avatar_url.flatMap { URL(string: $0) }
        )
        return user
    }
}

// =============================================
// =============================================
struct SupabaseTaskDTO: Codable {
    let id: UUID
    let title: String
    let description: String
    let due_date: Date?
    let priority: String
    let status: String
    
    // Ownership & Claims
    let declared_by: UUID           // Realtor who declared this task
    let listing: UUID?
    
    // Creation source tracking
    let created_via: String
    let source_slack_messages: [String]?
    // Milestone timestamps
    let claimed_at: Date?
    let completed_at: Date?
    let deleted_at: Date?
    // Standard timestamps
    let created_at: Date
    let updated_at: Date
    let synced_at: Date?

        let task = Task(
            id: id,
            title: title,
            description: description,
            priority: Priority(rawValue: priority) ?? .medium,
            declaredBy: declared_by,
        )
            dueDate: due_date
        task.claimedBy = claimed_by
        task.listing = listing
        task.createdAt = created_at
        task.sourceSlackMessages = source_slack_messages
        task.claimedAt = claimed_at
        task.completedAt = completed_at
        task.deletedAt = deleted_at
        task.updatedAt = updated_at
        task.isDirty = false
        task.createdAt = created_at
        task.syncedAt = synced_at
        task.syncedAt = synced_at
        return task
}

    static func fromTask(_ task: Task) -> [String: Any] {
            "id": 
```

"id": [task.id](http://task.id).uuidString,

"title": task.title,

"description": task.description,

"priority": task.priority.rawValue,

"status": task.status.rawValue,

"declared_by": task.declaredBy.uuidString,

"created_via": task.createdVia.rawValue,

"created_at": task.createdAt.ISO8601Format(),

"updated_at": task.updatedAt.ISO8601Format()

]

if let dueDate = task.dueDate { json["due_date"] = dueDate.ISO8601Format() }

if let claimedBy = task.claimedBy { json["claimed_by"] = claimedBy.uuidString }

if let listing = task.listing { json["listing"] = listing.uuidString }

if let sourceSlack = task.sourceSlackMessages { json["source_slack_messages"] = sourceSlack }

if let claimedAt = task.claimedAt { json["claimed_at"] = claimedAt.ISO8601Format() }

if let completedAt = task.completedAt { json["completed_at"] = completedAt.ISO8601Format() }

if let deletedAt = task.deletedAt { json["deleted_at"] = deletedAt.ISO8601Format() }

return json

}

}

**Acceptance Criteria**:

- [ ]  All DTOs compile and `Codable` matches Postgres schema
- [ ]  `to*()` methods correctly map DTO → SwiftData model
- [ ]  `from*()` static methods correctly serialize model → JSON for push
- [ ]  All new fields included: `status`, `declared_by`, `created_via`, milestone timestamps, audit history

---

## **SECTION 3: CONCRETE SYNCMANAGER BEHAVIOR**

### **3.1 Detecting isDirty**

When to set `isDirty = true`:

```swift
// In SwiftUI views, whenever user edits:
@State var task: Task
// On save:
Button("Save") {
    task.title = newTitle // User edit
    task.isDirty = true   // MARK FOR SYNC
    task.updatedAt = Date()
    try? 
```

---

### **3.2 Conflict Handling Example**

Create `DispatchKit/Services/ConflictResolver.swift`:

```swift
import Foundation
class ConflictResolver {

    static func resolveTaskConflict(
        local: Task,
        remote: Task,
        strategy: ConflictStrategy
    ) -> Task {
        switch strategy {
        case .lastWriteWins:
            // Compare timestamps: keep whichever was edited last
            if remote.updatedAt > local.updatedAt {
                return remote
            } else {
                return local
            }

        case .serverWins:
            return remote

        case .manual:
            // Flag for manual review
```

---

### **3.3 SyncManager: Full Implementation**

Create `DispatchKit/Services/SyncManager.swift`:

```swift
import Foundation
import SwiftData
class SyncManager: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    @Published var syncStatus: SyncStatus = .synced

    let modelContext: ModelContext
    let currentUserID: UUID

    private var realtimeChannel: RealtimeChannelV2?
    init(supabaseClient: SupabaseClient, modelContext: ModelContext, currentUserID: UUID) {
        self.supabaseClient = supabaseClient
        self.currentUserID = currentUserID
    }

    // SYNC DOWN: Supabase → SwiftData
    func syncDown() async {
        await syncTasks()
        await syncListings()
        await syncNotes()
        lastSyncTime = Date()
    }

    private func syncTasks() async {
        do {
            isSyncing = true
            syncStatus = .syncing
            // Fetch tasks updated since last sync
            let lastSync = lastSyncTime?.ISO8601Format() ?? "2000-01-01T00:00:00Z"
            let response = try await supabaseClient
                .from("tasks")
                .select()
                .execute()

            let dtos = try JSONDecoder().decode([SupabaseTaskDTO].self, from: 
```

**Acceptance Criteria**:

- [x]  `syncDown()` fetches tasks with `updated_at > lastSyncTime`
- [x]  Insert vs update logic works (checks local ID first)
- [x]  `isDirty` correctly set to `false` on sync from server
- [ ]  Conflict resolution applied when both sides modified same field
- [x]  `syncUp()` finds dirty tasks and pushes to Supabase
- [x]  After sync, `isSyncing = false` and `syncStatus = .synced`

---

### **3.4 SyncManager Developer Guide (How to Use)**

The sync system is fully operational. Here's how to integrate it when building new features:

#### **Architecture Overview**

```
┌─────────────────────────────────────────────────────────────────┐
│                     BIDIRECTIONAL SYNC                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   LOCAL → SUPABASE (You trigger this)                           │
│   ─────────────────────────────────────                         │
│   1. Modify SwiftData entity                                    │
│   2. Set entity.updatedAt = Date()                              │
│   3. Call SyncManager.shared.requestSync()                      │
│   4. [500ms debounce] → sync() uploads dirty entities           │
│                                                                  │
│   SUPABASE → LOCAL (Automatic via Realtime)                     │
│   ─────────────────────────────────────────                     │
│   1. Remote change triggers WebSocket event                     │
│   2. Event received → requestSync() called automatically        │
│   3. sync() downloads and merges changes                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### **Usage Pattern: When Modifying Data**

```swift
// In any View or Service where you modify data:
func updateTask(_ task: TaskItem, newTitle: String) {
    task.title = newTitle
    task.updatedAt = Date()  // Mark as dirty

    // Trigger sync (debounced - safe to call frequently)
    SyncManager.shared.requestSync()
}

func createNewTask(in context: ModelContext) {
    let task = TaskItem(
        title: "New Task",
        // ... other properties
        updatedAt: Date(),
        syncedAt: nil  // nil = never synced = dirty
    )
    context.insert(task)

    SyncManager.shared.requestSync()
}
```

#### **The "Dirty" Detection Logic**

Entities are considered dirty (need upload) when:
```swift
var isDirty: Bool {
    guard let syncedAt = syncedAt else { return true }  // Never synced
    return updatedAt > syncedAt  // Modified since last sync
}
```

#### **Realtime Events (Already Configured)**

The app listens to these tables via WebSocket:
- `tasks` - Task changes
- `activities` - Activity changes
- `listings` - Listing changes
- `users` - User changes

When any row changes in Supabase (from another device/user), the app automatically:
1. Receives the WebSocket event
2. Calls `requestSync()`
3. Downloads the updated data

#### **Key Files**

| File | Purpose |
|------|---------|
| `SyncManager.swift` | Orchestrates all sync operations |
| `SupabaseClient.swift` | Singleton Supabase client |
| `DebugLogger.swift` | DEBUG-only logging (stripped in Release) |

#### **Testing Sync**

Use `SyncTestHarness` (DEBUG builds only) to:
- View local vs Supabase entity counts
- Create test entities
- Manually trigger sync
- Monitor realtime events

---

## **SECTION 4: CLEAR NAVIGATION & COMPOSITION WIRING**

### **4.1 Selection State Management**

Create `DispatchKit/Environment/NavigationState.swift`:

```swift
import Foundation
import SwiftUI
// Centralized navigation state
class NavigationState: ObservableObject {
    @Published var selectedTask: Task?
    @Published var selectedActivity: Activity?
    @Published var selectedListing: Listing?

    @Published var showActivityDetail = false
    @Published var showListingDetail = false

    // Select a task (used by list row tap)
        selectedTask = task
        showTaskDetail = true
    }

    func selectActivity(_ activity: Activity) {
        selectedActivity = activity
    }

    func clearSelection() {
        selectedTask = nil
        selectedActivity = nil
    }
}
```

---

### **4.2 App-Level Navigation (iPhone)**

Create `DispatchApp.swift`:

```swift
import SwiftUI
import SwiftData
@main
struct DispatchApp: App {
    @StateObject private var navigationState = NavigationState()
    @StateObject private var syncManager: SyncManager
    @Environment(\.modelContext) var modelContext

        WindowGroup {
            ContentView()
                .environmentObject(navigationState)
                .environmentObject(syncManager)
                .onAppear {
                    // Trigger initial sync
                    Task {
                        await syncManager.syncDown()
                        syncManager.listenForRealtimeChanges()
                    }
                }
        }
    }
}

// MAIN CONTENT VIEW (Tab navigation)
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TaskListContainer()
                .tabItem {
                    Label("Tasks", systemImage: "
```

---

### **4.3 App-Level Navigation (iPad)**

Create `DispatchApp_iPad.swift`:

```swift
import SwiftUI
struct ContentView_iPad: View {
    @State private var selectedTab = 0
    @EnvironmentObject var navigationState: NavigationState

        NavigationSplitView {
            // SIDEBAR: Tab picker
            VStack {
                List(selection: $selectedTab) {
                    NavigationLink(value: 0) {
                        Label("Tasks", systemImage: "
```

**Acceptance Criteria**:

- [ ]  iPhone: NavigationStack pushes to detail view on row tap
- [ ]  iPad: NavigationSplitView shows list on left, detail on right
- [ ]  Selection syncs between list and detail view
- [ ]  Back button returns to list

---

## **SECTION 5: DESIGN SYSTEM TOKENS & EXAMPLES**

### **5.1 Typography Tokens**

Create `DispatchKit/Foundation/Typography.swift`:

```swift
import SwiftUI
struct DispatchFont {
    // Large displays
    static let titleLarge = Font.system(size: 32, weight: .bold, design: .default)
    static let titleMedium = Font.system(size: 20, weight: .semibold, design: .default)
    static let titleSmall = Font.system(size: 18, weight: .semibold, design: .default)

    static let body = Font.system(size: 16, weight: .regular, design: .default)
    static let bodyBold = Font.system(size: 16, weight: .semibold, design: .default)
    static let bodySmall = Font.system(size: 14, weight: .regular, design: .default)

    // Captions
    static let captionBold = Font.system(size: 12, weight: .semibold, design: .default)
}
```

### **5.2 Color Tokens**

Create `DispatchKit/Foundation/ColorSystem.swift`:

```swift
import SwiftUI
struct DispatchColor {
    // Semantic background
    static let background = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1)
            : UIColor(red: 0.98, green: 0.98, blue: 0.96, alpha: 1)
    })

        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.15, green: 0.15, blue: 0.16, alpha: 1)
            : UIColor.white
    })

    // Text
    static let textSecondary = Color.secondary

    // Priority colors
    static let priorityLow = Color.gray
    static let priorityHigh = 
```

### **5.3 Component Examples Using Tokens**

Create `DispatchKit/Components/WorkItemRow.swift`:

```swift
import SwiftUI
struct WorkItemRow<T: WorkItemProtocol>: View {
    let item: T
    @EnvironmentObject var navigationState: NavigationState

        HStack(alignment: .top, spacing: 12) {
            // CHECKBOX
            Button(action: { /* toggle completion */ }) {
                Image(systemName: item.completed ? "
```

**Acceptance Criteria**:

- [ ]  All components use `DispatchFont` and `DispatchColor` tokens
- [ ]  No hardcoded colors or font sizes in views
- [ ]  Tokens update globally when changed

---

## **SECTION 6: EDGE CASES & RULES**

Create `DispatchKit/Documentation/[EdgeCases.md](http://EdgeCases.md)`:

```markdown
# Edge Cases & Implementation Rules
## Sync Failures

- **Expected**: Note saves locally, marked `isDirty = true`, `syncStatus = .pending`
- **UI Feedback**: Show cloud icon with arrow (pending) next to note
- **Retry**: On next sync (app opened), automatically push
- **User Action**: If sync fails 3x, show error banner with "Retry" button

**Scenario**: Sync push fails (network timeout).
- **User Awareness**: Badge on tab shows "!" if items pending
- **Recovery**: Automatic retry on scenePhase .active

## Offline Behavior

- ✅ Create task/activity
- ✅ Edit task/activity
- ✅ Complete task/activity
- ✅ Claim task/activity (optimistic update locally)

**Disallowed Offline**:
- ❌ Delete task (server-side cascades notes/subtasks)
- ❌ Delete listing (complex cascade)

1. Sync down (fetch latest from server)
2. Check for conflicts
3. Sync up (push local changes)
4. Realtime subscribe
## Claim Conflicts

**Scenario**: Two staff members claim same task simultaneously.

- **Resolution**: Last-write-wins (compare `updated_at` timestamps)
- **Server-side**: RLS policy ensures only one can claim (unique constraint)
- **UX**: If current user loses claim mid-edit, show modal: "This task was claimed by [Name]. Review?"

**Scenario**: Two realtors add notes to same task.
- **Expected**: Both notes appear, sorted by `createdAt DESC`
- **Realtime**: New note from other user appears in 1-2 seconds
- **Conflict**: None—notes are independent rows

**Scenario**: Realtor edits a note while another realtor reads it.
- **Expected**: Edited note marked with `editedAt` timestamp, badge shows "edited"
- **Realtime**: List of notes refreshes to show edit
## Permissions

1. Declared
2. That belong to their owned listings

**Rule**: Staff can see tasks/activities they:
2. That belong to their assigned listings

**Rule**: Admin/Exec can see all tasks (RLS enforced server-side)

Track last sync time per entity type per realtor:
- On `syncDown()` call, query only rows where `updated_at > sync_metadata.last_sync_*`
- This avoids fetching the entire table every sync

## Conflict Resolution: Last-Write-Wins Algorithm
Given:
localTask.updatedAt = 2025-11-29 16:00:00
remoteTask.updatedAt = 2025-11-29 16:05:00

→ Discard all local changes to this field
→ Adopt remote value

If times are equal (within 1 second):
```

---

## **SECTION 7: CONCRETE NOTESTACK & NOTEINPUT IMPLEMENTATIONS**

### **7.1 NoteCard Component**

Create `DispatchKit/Components/NoteCard.swift`:

```swift
import SwiftUI
struct NoteCard: View {
    let note: Note
    @State private var showEditOptions = false
    let onDelete: () -> Void
    let onEdit: () -> Void

        VStack(alignment: .leading, spacing: 8) {
            // HEADER: Timestamp + User + Actions
            HStack {
                // User badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(
```

---

### **7.2 NoteStack Component**

Create `DispatchKit/Components/NoteStack.swift`:

```swift
import SwiftUI
struct NoteStack<T: WorkItemProtocol>: View {
    let item: T
    let onDeleteNote: (UUID) -> Void

        ZStack(alignment: .top) {
            // NOTES CONTAINER (clipped at 140pt)
            VStack(spacing: 12) {
                ForEach(Array(item.notes.sorted { $0.createdAt > $1.createdAt }.enumerated()),
                         id: \.
```

---

### **7.3 NoteInputArea Component**

Create `DispatchKit/Components/NoteInputArea.swift`:

```swift
import SwiftUI
struct NoteInputArea<T: WorkItemProtocol>: View {
    let item: T
    let currentUser: User
    @State private var noteText = ""
    @State private var isSaving = false
    let onSave: (String) -> Void

        VStack(alignment: .leading, spacing: 12) {
            // TEXT EDITOR
            TextEditor(text: $noteText)
                .frame(minHeight: 80, maxHeight: 200)
                .padding(12)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
                .border(Color.gray.opacity(0.2), width: 1)
                .scrollContentBackground(.hidden)

            // USER CONTEXT
                HStack(spacing: 6) {
                    Circle()
                        .fill(
```

---

### **7.4 Parent ScrollView Context**

Create `DispatchKit/Components/ScrollableDetailView.swift`:

```swift
import SwiftUI
struct ScrollableDetailView<T: WorkItemProtocol>: View {
    @State var item: T

        ScrollView {
            VStack(spacing: 0) {
                // COLLAPSING HEADER
                DetailHeader(
                    item: item
                )
                .frame(height: 200)
                .background(
```

**Acceptance Criteria**:

- [ ]  NoteCard shows: User badge, timestamp, content (2-line truncated), sync status
- [ ]  NoteStack clips at 140pt with shadow gradient overlay
- [ ]  NoteInputArea always visible, TextEditor minHeight 80pt
- [ ]  Buttons properly styled with DispatchFont tokens
- [ ]  Edit/Delete menu on NoteCard functional

---

## **SECTION 8: TICKET BREAKDOWN FOR JR DEV**

### **Phase 1 Tickets (Weeks 1-2)**

| Ticket | Title | Acceptance Criteria | Est. Hours |
| --- | --- | --- | --- |
| **D-01** | Implement Priority, ActivityType, ListingStatus, ConflictStrategy enums | All enums compile, conform to Codable, have `.displayName` computed properties | 2 |
| **D-02** | Implement SwiftData @Model classes (Task, Activity, Listing, Note, Subtask) | Models compile, relationships use `@Relationship(deleteRule: .cascade)`, conform to WorkItemProtocol | 4 |
| **D-03** | Set up Supabase project + PostgreSQL schema | Schema created, RLS policies active, can query from Xcode | 3 |
| **D-04** | Implement DTOs + Codable mappings (SupabaseTaskDTO, etc.) | DTOs decode from Supabase JSON, `toTask()` conversion works, unit tests pass | 3 |
| **D-05** | Implement SyncManager.syncDown() for Tasks only (stubbed) | Can fetch tasks from Supabase, upsert to local SwiftData, test with mock data | 5 |
| **D-06** | Implement SyncManager.syncUp() for Tasks only | Can push dirty tasks to Supabase, mark clean, handle errors | 5 |
| **D-07** | Create ConflictResolver with last-write-wins logic | Resolves conflicts by comparing `updatedAt`, unit tests pass | 3 |

**Phase 1 Total: ~25 hours (1 week for 1 full-time dev)**

---

### **Phase 2 Tickets (Weeks 2-3)**

| Ticket | Title | Acceptance Criteria | Est. Hours |
| --- | --- | --- | --- |
| **D-08** | Implement NavigationState + App-level composition | Selection state works, iPhone NavigationStack works, tabs navigate correctly | 4 |
| **D-09** | Implement DispatchFont + DispatchColor tokens | Tokens defined, no hardcoded colors/fonts, used in 3+ components | 2 |
| **D-10** | Implement WorkItemRow<T> generic component | Row displays for both Task and Activity, tap selects item, styling uses tokens | 4 |
| **D-11** | Implement NoteCard + NoteStack components | NoteCard shows 2-line preview, NoteStack clips at 140pt, shadow gradient visible | 5 |
| **D-12** | Implement NoteInputArea component | TextEditor works, buttons functional, UX smooth | 3 |
| **D-13** | Implement TaskListView with SegmentedFilter | List shows My/Others/Unclaimed segments, WorkItemRow<Task> used, Magic Plus button visible | 5 |
| **D-14** | Implement ActivityListView (identical to TaskListView) | Reuse QuickEntrySheet logic, same structure, WorkItemRow<Activity> | 3 |

**Phase 2 Total: ~26 hours (1.5 weeks)**

---

### **Phase 3 Tickets (Weeks 3-4)**

| Ticket | Title | Acceptance Criteria | Est. Hours |
| --- | --- | --- | --- |
| **D-15** | Implement WorkItemDetailView<T> generic detail screen | Collapses header on scroll, shows metadata, notes, subtasks; works for Task and Activity | 8 |
| **D-16** | Implement ListingDetailView with tabs | Address display, assigned realtor, Tasks tab, Activities tab, Notes tab | 6 |
| **D-17** | Implement QuickEntrySheet | Modal opens from + button, creates Task/Activity/Listing, closes on save | 4 |
| **D-18** | Implement ClaimButton + ClaimConfirmationSheet | Shows state (Unclaimed/Claimed/ClaimedByOther), claim/release functional | 3 |
| **D-19** | iPad support: NavigationSplitView | Master-detail layout works on iPad, selection syncs between list and detail | 5 |

**Phase 3 Total: ~26 hours (1.5 weeks)**

---

### **Phase 4 Tickets (Weeks 4-5)**

| Ticket | Title | Acceptance Criteria | Est. Hours |
| --- | --- | --- | --- |
| **D-20** | Implement Realtime listener (syncManager.listenForRealtimeChanges) | Subscribes to Supabase channel, new notes appear live in UI | 5 |
| **D-21** | Implement retry logic + exponential backoff | Sync failures retry with 1s, 2s, 4s delays; show "X" badge on failed syncs | 4 |
| **D-22** | Implement offline detection | App works offline, marks items as pending, retries on reconnect | 3 |
| **D-23** | End-to-end testing: Create task → Edit → Add note → Sync → Verify in Supabase | Full flow works, no data loss, UI updates correctly | 4 |

**Phase 4 Total: ~16 hours (1 week)**

---

## **SECTION 9: TESTING & TOOLING**

### **9.1 Unit Tests (Example: ConflictResolver)**

Create `Tests/ConflictResolverTests.swift`:

```swift
import XCTest
@testable import DispatchKit
class ConflictResolverTests: XCTestCase {

        let local = Task(title: "Old", createdBy: UUID())
        local.updatedAt = Date(timeIntervalSince1970: 1000)

        let remote = Task(title: "New", createdBy: UUID())

        let merged = ConflictResolver.resolveTaskConflict(
            local: local,
            strategy: .lastWriteWins
        )

        XCTAssertEqual(merged.title, "New")
    }

        let local = Task(title: "New", createdBy: UUID())
        local.updatedAt = Date(timeIntervalSince1970: 3000)

        remote.updatedAt = Date(timeIntervalSince1970: 2000)

        let merged = ConflictResolver.resolveTaskConflict(
            local: local,
            strategy: .lastWriteWins
        )

    }
}
```

### **9.2 UI Tests (Example: NoteCard)**

Create `Tests/NoteCardUITests.swift`:

```swift
import XCTest
class NoteCardUITests: XCTestCase {

        let app = XCUIApplication()
        app.launch()

        // Navigate to task with notes

        // Verify note card visible
        let noteCard = app.staticTexts["note-preview"]

        // Verify truncation (2 lines max)
        let noteHeight = noteCard.frame.height
        XCTAssert(noteHeight < 60) // Roughly 2 lines of text
}
```

### **9.3 Local Dev Setup**

Create `LOCAL_DEV_[SETUP.md](http://SETUP.md)`:

```markdown
# Local Development Setup
## Prerequisites
- Xcode 15.1+
- Swift 5.9+
- Docker (for local Supabase)

```

git clone <repo>

cd dispatch

[xcode-build.sh](http://xcode-build.sh)

```jsx
## Step 2: Set Up Local Supabase
```

# Install supabase CLI (<https://supabase.com/docs/guides/cli/getting-started>)

supabase init

supabase start

```jsx
This spins up:
- PostgreSQL on 
```

supabase db pull # Or manually import supabase/schema.sql

```jsx
## Step 4: Configure Xcode
Set environment variable in scheme:
- `SUPABASE_URL = 
```

xcodebuild test -scheme Dispatch

```jsx
## Step 6: Run App
⌘R in Xcode (select iPhone 15 Pro simulator)

- View PostgreSQL logs: `supabase logs --debug`
- View API requests: Check Supabase Studio Network tab
- Reset database: `supabase db reset`
```

### **9.4 Minimum Support**

- **iOS**: 17.0+ (SwiftData requirement)
- **iPadOS**: 17.0+
- **macOS**: 14.0+ (future)

---

## **FINAL CHECKLIST FOR JR DEV TO START**

Before beginning Phase 1, confirm:

- [ ]  Xcode 15.1+ installed
- [ ]  Swift package manager working (can add Supabase)
- [ ]  Understand SwiftUI `@State`, `@Binding`, `@Observable`
- [ ]  Familiar with `Codable` protocol
- [ ]  SwiftData `@Model` and `@Relationship` basics understood
- [ ]  Read Apple's SwiftData docs: https://developer.apple.com/documentation/swiftdata
- [ ]  Supabase project created, PostgreSQL access confirmed
- [ ]  Git repo initialized with `.gitignore`
- [ ]  This entire guide downloaded and bookmarked

---

This guide should give a jr dev everything they need to start coding without getting stuck. Each ticket is ~3-5 hours, compilable, and testable independently.

```jsx

```