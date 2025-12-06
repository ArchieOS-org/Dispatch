# DISPATCH: Foundations IMPLEMENTATION PLAN

## *With Supabase Live Sync + SwiftData + Multi-Platform Support*

---

## **PHASE 1: FOUNDATION (Weeks 1-2)**

### *Build the persistence layer first—this defines everything else*

### **1.1 Data Models + Supabase Schema**

**Models (SwiftData on-device)**:

```
REALTOR (User)
  ├─ id: UUID
  ├─ name: String
  ├─ email: String
  ├─ avatar: [PLACEHOLDER: URL or local asset]
  ├─ listings: [Listing]
  ├─ claimedTasks: [Task]
  ├─ claimedActivities: [Activity]
  └─ [PLACEHOLDER: permissions/roles for admin features]

TASK (WorkItem)
  ├─ id: UUID
  ├─ title: String
  ├─ description: String
  ├─ dueDate: Date?
  ├─ priority: Priority (Low, Medium, High, Urgent)
  ├─ completed: Bool
  ├─ claimedBy: UUID? (FK to Realtor)
  ├─ createdBy: UUID (FK to Realtor)
  ├─ listing: UUID? (FK to Listing, optional)
  ├─ notes: [Note]
  ├─ subtasks: [Subtask]
  ├─ createdAt: Date
  ├─ updatedAt: Date
  ├─ syncedAt: Date? (for sync tracking)
  └─ [PLACEHOLDER: tags, custom fields, reminder frequency]

ACTIVITY (WorkItem)
  ├─ id: UUID
  ├─ title: String
  ├─ description: String
  ├─ type: ActivityType (Call, Email, Meeting, ShowProperty, FollowUp) [PLACEHOLDER]
  ├─ dueDate: Date?
  ├─ completed: Bool
  ├─ claimedBy: UUID? (FK to Realtor)
  ├─ createdBy: UUID (FK to Realtor)
  ├─ listing: UUID? (FK to Listing, optional)
  ├─ notes: [Note]
  ├─ subtasks: [Subtask]
  ├─ duration: TimeInterval? [PLACEHOLDER: for call/meeting tracking]
  ├─ createdAt: Date
  ├─ updatedAt: Date
  ├─ syncedAt: Date?
  └─ [PLACEHOLDER: attendees, location, recording link]

LISTING (Entity)
  ├─ id: UUID
  ├─ address: String
  ├─ [PLACEHOLDER: city, state, zip, coordinates]
  ├─ assignedRealtor: UUID (FK to Realtor)
  ├─ [PLACEHOLDER: price, bedrooms, bathrooms, mls_number]
  ├─ tasks: [Task] (filtered by listing.id)
  ├─ activities: [Activity] (filtered by listing.id)
  ├─ notes: [Note] (listing-level notes)
  ├─ status: ListingStatus (Active, Pending, Closed, Draft) [PLACEHOLDER]
  ├─ createdAt: Date
  ├─ updatedAt: Date
  ├─ syncedAt: Date?
  └─ [PLACEHOLDER: listing_photos, description, open_houses]

NOTE (Sub-entity)
  ├─ id: UUID
  ├─ content: String
  ├─ createdBy: UUID (FK to Realtor)
  ├─ parentType: ParentType (Task, Activity, Listing)
  ├─ parentId: UUID (FK to Task/Activity/Listing)
  ├─ createdAt: Date
  ├─ [PLACEHOLDER: edited/editedBy for edit history]
  └─ [PLACEHOLDER: mentions (@realtor_name), attachments]

SUBTASK (Sub-entity)
  ├─ id: UUID
  ├─ title: String
  ├─ completed: Bool
  ├─ parentId: UUID (FK to Task or Activity)
  ├─ [PLACEHOLDER: assignedTo, dueDate]
  └─ createdAt: Date

CLAIMSTATE (Tracking)
  ├─ itemId: UUID
  ├─ itemType: ItemType (Task, Activity)
  ├─ claimedBy: UUID? (null = unclaimed)
  ├─ claimedAt: Date?
  └─ releasedAt: Date? (for audit)

```

---

### **1.2 Supabase Schema (PostgreSQL)**

Create tables matching SwiftData models:

- `realtors` table
- `tasks` table (with RLS policies)
- `activities` table (with RLS policies)
- `listings` table (with RLS policies)
- `notes` table
- `subtasks` table
- `sync_metadata` table (tracks `last_sync_timestamp` per realtor)

**Row-Level Security (RLS) Example**:

```sql
-- A realtor can only see tasks/activities:
-- 1. They created
-- 2. They claimed
-- 3. That belong to their listings
-- 4. (If enabled) That are on shared listings

```

---

### **1.3 SyncManager Service** (The Orchestrator)

```
SyncManager (Singleton)
  ├─ Properties:
  │  ├─ supabaseClient: SupabaseClient
  │  ├─ modelContext: ModelContext (SwiftData)
  │  ├─ lastSyncTime: Date
  │  └─ isSyncing: @Published Bool
  │
  ├─ Methods:
  │  ├─ syncDown() async → Fetch Supabase changes, merge into SwiftData
  │  ├─ syncUp() async → Push local changes to Supabase
  │  ├─ listenForRealtimeChanges() → Supabase channel subscriptions
  │  ├─ handleConflict() → If two realtors modify same item
  │  └─ [PLACEHOLDER: retryFailedSync(), offlineQueueManager()]
  │
  └─ Triggers:
     ├─ App becomes active (scenePhase == .active)
     ├─ Data saved locally (after user action)
     ├─ Realtime update received from Supabase channel
     └─ [PLACEHOLDER: Silent push notification received]

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
  ├─ completed: Bool
  ├─ claimedBy: UUID?
  ├─ createdBy: UUID
  ├─ listing: UUID?
  ├─ notes: [Note]
  ├─ subtasks: [Subtask]
  ├─ createdAt: Date
  ├─ updatedAt: Date
  ├─ syncedAt: Date?
  └─ [PLACEHOLDER: custom properties per type]

ClaimableProtocol
  ├─ canBeClaimed: Bool
  ├─ claimedBy: UUID?
  ├─ claim(by: Realtor) async
  ├─ release() async
  └─ [PLACEHOLDER: claimExpiresAt, autoRelease logic]

NotableProtocol
  ├─ notes: [Note]
  ├─ addNote(content: String, by: Realtor) async
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

### **2.1 Foundation Layer (Design Tokens)**

```
DispatchKit/Foundation/
├─ Typography.swift
│  └─ [PLACEHOLDER: Additional font variants for multiplatform]
├─ ColorSystem.swift
│  └─ Semantic colors + dark mode support
├─ Spacing.swift
│  └─ [PLACEHOLDER: iPad/Mac responsive spacing]
├─ Shadows.swift
└─ IconSystem.swift [NEW]
   └─ [PLACEHOLDER: SF Symbols mappings for claim state, sync status]

```

---

### **2.2 Tier 4: Shared Components**

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
[1] Fix Clipping Issues in SwiftUI ScrollView [[https://fatbobman.com/en/snippet/preventing-scrollview-content-clipping-in-swiftui/](https://fatbobman.com/en/snippet/preventing-scrollview-content-clipping-in-swiftui/)](https://fatbobman.com/en/snippet/preventing-scrollview-content-clipping-in-swiftui/](https://fatbobman.com/en/snippet/preventing-scrollview-content-clipping-in-swiftui/))
[2] SwiftUI: Why are my shadows clipped?? [[https://www.bam.tech/en/article/swiftui-why-are-my-shadows-clipped](https://www.bam.tech/en/article/swiftui-why-are-my-shadows-clipped)](https://www.bam.tech/en/article/swiftui-why-are-my-shadows-clipped](https://www.bam.tech/en/article/swiftui-why-are-my-shadows-clipped))
[3] shadow will cut by ScrollView #25703 - facebook/react-native [[https://github.com/facebook/react-native/issues/25703](https://github.com/facebook/react-native/issues/25703)](https://github.com/facebook/react-native/issues/25703](https://github.com/facebook/react-native/issues/25703))
[4] SwiftUI Live: Peek Scrolling Concept using GeometryReader [[https://www.youtube.com/watch?v=onc2xwzjggU](https://www.youtube.com/watch?v=onc2xwzjggU)](https://www.youtube.com/watch?v=onc2xwzjggU](https://www.youtube.com/watch?v=onc2xwzjggU))
[5] Shadows clipped by ScrollView [[https://stackoverflow.com/questions/62157340/shadows-clipped-by-scrollview](https://stackoverflow.com/questions/62157340/shadows-clipped-by-scrollview)](https://stackoverflow.com/questions/62157340/shadows-clipped-by-scrollview](https://stackoverflow.com/questions/62157340/shadows-clipped-by-scrollview))
[6] Fix This Problem with SwiftUI Lists [[https://www.youtube.com/watch?v=cpT02OtOasE](https://www.youtube.com/watch?v=cpT02OtOasE)](https://www.youtube.com/watch?v=cpT02OtOasE](https://www.youtube.com/watch?v=cpT02OtOasE))
[7] Building a stack of cards – Flashzilla SwiftUI Tutorial 7/13 [[https://www.youtube.com/watch?v=KL1c5Mx3kek](https://www.youtube.com/watch?v=KL1c5Mx3kek)](https://www.youtube.com/watch?v=KL1c5Mx3kek](https://www.youtube.com/watch?v=KL1c5Mx3kek))
[8] SwiftUI Example: How to adjust the List View Styling with ... [[https://www.youtube.com/watch?v=tjR1hLg4-wc](https://www.youtube.com/watch?v=tjR1hLg4-wc)](https://www.youtube.com/watch?v=tjR1hLg4-wc](https://www.youtube.com/watch?v=tjR1hLg4-wc))
[9] SwiftUI Card flip with two views [[https://stackoverflow.com/questions/60805244/swiftui-card-flip-with-two-views](https://stackoverflow.com/questions/60805244/swiftui-card-flip-with-two-views)](https://stackoverflow.com/questions/60805244/swiftui-card-flip-with-two-views](https://stackoverflow.com/questions/60805244/swiftui-card-flip-with-two-views))
[10] Backgrounds and overlays in SwiftUI [[https://www.swiftbysundell.com/articles/backgrounds-and-overlays-in-swiftui](https://www.swiftbysundell.com/articles/backgrounds-and-overlays-in-swiftui)](https://www.swiftbysundell.com/articles/backgrounds-and-overlays-in-swiftui](https://www.swiftbysundell.com/articles/backgrounds-and-overlays-in-swiftui))
[11] Stacked Cards - Looping Cards - SwiftUI [[https://www.youtube.com/watch?v=mEwlTyTtsmE](https://www.youtube.com/watch?v=mEwlTyTtsmE)](https://www.youtube.com/watch?v=mEwlTyTtsmE](https://www.youtube.com/watch?v=mEwlTyTtsmE))
[12] SwiftUI: ScrollView clipping [[https://philip-trauner.me/blog/post/swiftui-scrollview-clips-to-bounds](https://philip-trauner.me/blog/post/swiftui-scrollview-clips-to-bounds)](https://philip-trauner.me/blog/post/swiftui-scrollview-clips-to-bounds](https://philip-trauner.me/blog/post/swiftui-scrollview-clips-to-bounds))
[13] Shadow is not visible with View() and List() [[https://stackoverflow.com/questions/76462407/shadow-is-not-visible-with-view-and-list](https://stackoverflow.com/questions/76462407/shadow-is-not-visible-with-view-and-list)](https://stackoverflow.com/questions/76462407/shadow-is-not-visible-with-view-and-list](https://stackoverflow.com/questions/76462407/shadow-is-not-visible-with-view-and-list))
[14] Imitating the Card Stack demonstrated by Apple at WWDC [[https://www.reddit.com/r/SwiftUI/comments/1dvb06n/imitating_the_card_stack_demonstrated_by_apple_at/](https://www.reddit.com/r/SwiftUI/comments/1dvb06n/imitating_the_card_stack_demonstrated_by_apple_at/)](https://www.reddit.com/r/SwiftUI/comments/1dvb06n/imitating_the_card_stack_demonstrated_by_apple_at/](https://www.reddit.com/r/SwiftUI/comments/1dvb06n/imitating_the_card_stack_demonstrated_by_apple_at/))
[15] How to Fix SwiftUI Clipped Images Overlapping Scroll Views [[https://www.youtube.com/watch?v=hSZsqWqg0IM](https://www.youtube.com/watch?v=hSZsqWqg0IM)](https://www.youtube.com/watch?v=hSZsqWqg0IM](https://www.youtube.com/watch?v=hSZsqWqg0IM))
[16] Creating a list in SwiftUI (4/7) [[https://www.cometchat.com/tutorials/creating-a-list-in-swiftui-3-7](https://www.cometchat.com/tutorials/creating-a-list-in-swiftui-3-7)](https://www.cometchat.com/tutorials/creating-a-list-in-swiftui-3-7](https://www.cometchat.com/tutorials/creating-a-list-in-swiftui-3-7))
[17] SwiftUI: Infinite Scrolling Slideshow/Image Carousel (The ... [[https://blog.stackademic.com/swiftui-infinite-scrolling-slideshow-image-carousel-739244177bef](https://blog.stackademic.com/swiftui-infinite-scrolling-slideshow-image-carousel-739244177bef)](https://blog.stackademic.com/swiftui-infinite-scrolling-slideshow-image-carousel-739244177bef](https://blog.stackademic.com/swiftui-infinite-scrolling-slideshow-image-carousel-739244177bef))
[18] Inner Shadow - SwiftUI Handbook [[https://designcode.io/swiftui-handbook-inner-shadow/](https://designcode.io/swiftui-handbook-inner-shadow/)](https://designcode.io/swiftui-handbook-inner-shadow/](https://designcode.io/swiftui-handbook-inner-shadow/))
[19] SwiftUI animation I made using a combination of materials, ... [[https://www.reddit.com/r/iOSProgramming/comments/1l4tx0m/swiftui_animation_i_made_using_a_combination_of/](https://www.reddit.com/r/iOSProgramming/comments/1l4tx0m/swiftui_animation_i_made_using_a_combination_of/)](https://www.reddit.com/r/iOSProgramming/comments/1l4tx0m/swiftui_animation_i_made_using_a_combination_of/](https://www.reddit.com/r/iOSProgramming/comments/1l4tx0m/swiftui_animation_i_made_using_a_combination_of/))
[20] notsobigcompany/CardStack: A SwiftUI view that arranges ... [[https://github.com/notsobigcompany/CardStack](https://github.com/notsobigcompany/CardStack)](https://github.com/notsobigcompany/CardStack](https://github.com/notsobigcompany/CardStack))
[21] Color Shadows and Opacity in SwiftUI [[https://www.youtube.com/watch?v=nGENKnaSWPM](https://www.youtube.com/watch?v=nGENKnaSWPM)](https://www.youtube.com/watch?v=nGENKnaSWPM](https://www.youtube.com/watch?v=nGENKnaSWPM))
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
  │  ├─ "Added by: [Current Realtor Name]"
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
  │  └─ .claimedByOther(realtor)
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
  │  ├─ "My Tasks" (claimedBy == currentRealtor)
  │  ├─ "Others'" (claimedBy != currentRealtor AND claimedBy != null)
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
  │  ├─ Grouped by assignedRealtor [PLACEHOLDER: Or searchable by address]
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
  │  ├─ Assigned Realtor badge
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
  │  ├─ Update task.claimedBy = currentRealtor.id
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
    let realtorID: UUID

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

            try modelContext.save()
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

            try modelContext.save()

        } catch {
            syncError = error.localizedDescription
            [PLACEHOLDER: retry logic]
        }

        isSyncing = false
    }

    // REALTIME LISTENER (Supabase → SwiftData, live)
    func listenForRealtimeChanges() {
        let channel = supabaseClient.channel("tasks")

        channel.on(
            .insert,
            handler: { message in
                // Decode and insert into SwiftData
                let task = try JSONDecoder().decode(Task.self, from: message.payload)
                self.modelContext.insert(task)
                try? self.modelContext.save()
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

- [ ]  ActivityType enum (Call, Email, Meeting, ShowProperty, etc.)
- [ ]  Custom field system (extensible metadata per listing)
- [ ]  Mention system (@realtor notifications)
- [ ]  File/image attachments in notes
- [ ]  Edit history for notes (show who edited what when)
- [ ]  Permission/role system (admin, agent, broker)
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

    var displayName: String {
        self.rawValue.capitalized
    }
}

// Parent type for notes/subtasks
enum ParentType: String, Codable {
    case task = "task"
    case activity = "activity"
    case listing = "listing"
}

// Claim state
enum ClaimState: Codable {
    case unclaimed
    case claimedBy(realtor: Realtor)
    case claimedByOther(realtor: Realtor)

    var isClaimed: Bool {
        switch self {
        case .unclaimed: return false
        case .claimedBy, .claimedByOther: return true
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
```

---

### **1.2 Core Data Models**

Create `DispatchKit/Models/Models.swift`:

```swift
import Foundation
import SwiftData

// REALTOR (User)
@Model final class Realtor: Codable, Identifiable {
    var id: UUID
    var name: String
    var email: String
    var avatarURL: URL?
    @Relationship(deleteRule: .cascade) var listings: [Listing] = []

    enum CodingKeys: String, CodingKey {
        case id, name, email
        case avatarURL = "avatar_url"
    }

    init(id: UUID = UUID(), name: String, email: String, avatarURL: URL? = nil) {
        [self.id](http://self.id) = id
        [self.name](http://self.name) = name
        [self.email](http://self.email) = email
        self.avatarURL = avatarURL
    }
}

// SUBTASK (Embedded in Task/Activity)
@Model final class Subtask: Codable, Identifiable {
    var id: UUID
    var title: String
    var completed: Bool = false
    var createdAt: Date = Date()

    init(id: UUID = UUID(), title: String, completed: Bool = false) {
        [self.id](http://self.id) = id
        self.title = title
        self.completed = completed
    }
}

// NOTE (Embedded in Task/Activity/Listing)
@Model final class Note: Codable, Identifiable {
    var id: UUID
    var content: String
    var createdBy: Realtor
    var createdAt: Date = Date()
    var editedAt: Date?
    var syncStatus: SyncStatus = .pending

    enum CodingKeys: String, CodingKey {
        case id, content, createdAt, editedAt
        case createdBy = "created_by"
        case syncStatus = "sync_status"
    }

    init(id: UUID = UUID(), content: String, createdBy: Realtor) {
        [self.id](http://self.id) = id
        self.content = content
        self.createdBy = createdBy
    }
}

// TASK (WorkItem)
@Model final class Task: Codable, Identifiable {
    var id: UUID
    var title: String
    var description: String = ""
    var dueDate: Date?
    var priority: Priority = .medium
    var completed: Bool = false
    var claimedBy: UUID? // FK to Realtor
    var createdBy: UUID // FK to Realtor
    var listing: UUID? // FK to Listing (optional)
    @Relationship(deleteRule: .cascade) var notes: [Note] = []
    @Relationship(deleteRule: .cascade) var subtasks: [Subtask] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var syncedAt: Date?
    var isDirty: Bool = true // Mark for sync
    var syncStatus: SyncStatus = .pending
    var conflictStrategy: ConflictStrategy = .lastWriteWins

    enum CodingKeys: String, CodingKey {
        case id, title, description, dueDate, priority, completed
        case claimedBy = "claimed_by"
        case createdBy = "created_by"
        case listing, notes, subtasks, createdAt, updatedAt, syncedAt, isDirty
        case syncStatus = "sync_status"
        case conflictStrategy = "conflict_strategy"
    }

    init(id: UUID = UUID(), title: String, description: String = "",
         priority: Priority = .medium, createdBy: UUID, dueDate: Date? = nil) {
        [self.id](http://self.id) = id
        self.title = title
        self.description = description
        self.priority = priority
        self.createdBy = createdBy
        self.dueDate = dueDate
    }
}

// ACTIVITY (WorkItem)
@Model final class Activity: Codable, Identifiable {
    var id: UUID
    var title: String
    var description: String = ""
    var type: ActivityType = .other
    var dueDate: Date?
    var completed: Bool = false
    var duration: TimeInterval? // In minutes
    var claimedBy: UUID? // FK to Realtor
    var createdBy: UUID // FK to Realtor
    var listing: UUID? // FK to Listing (optional)
    @Relationship(deleteRule: .cascade) var notes: [Note] = []
    @Relationship(deleteRule: .cascade) var subtasks: [Subtask] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var syncedAt: Date?
    var isDirty: Bool = true
    var syncStatus: SyncStatus = .pending
    var conflictStrategy: ConflictStrategy = .lastWriteWins

    enum CodingKeys: String, CodingKey {
        case id, title, description, type, dueDate, completed, duration
        case claimedBy = "claimed_by"
        case createdBy = "created_by"
        case listing, notes, subtasks, createdAt, updatedAt, syncedAt, isDirty
        case syncStatus = "sync_status"
        case conflictStrategy = "conflict_strategy"
    }

    init(id: UUID = UUID(), title: String, type: ActivityType = .other,
         createdBy: UUID, dueDate: Date? = nil) {
        [self.id](http://self.id) = id
        self.title = title
        self.type = type
        self.createdBy = createdBy
        self.dueDate = dueDate
    }
}

// LISTING
@Model final class Listing: Codable, Identifiable {
    var id: UUID
    var address: String
    var city: String = ""
    var state: String = ""
    var zip: String = ""
    var assignedRealtor: UUID // FK to Realtor
    var status: ListingStatus = .draft
    @Relationship(deleteRule: .cascade) var tasks: [Task] = []
    @Relationship(deleteRule: .cascade) var activities: [Activity] = []
    @Relationship(deleteRule: .cascade) var notes: [Note] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var syncedAt: Date?
    var isDirty: Bool = true
    var syncStatus: SyncStatus = .pending

    enum CodingKeys: String, CodingKey {
        case id, address, city, state, zip, status
        case assignedRealtor = "assigned_realtor"
        case tasks, activities, notes, createdAt, updatedAt, syncedAt, isDirty
        case syncStatus = "sync_status"
    }

    init(id: UUID = UUID(), address: String, assignedRealtor: UUID) {
        [self.id](http://self.id) = id
        self.address = address
        self.assignedRealtor = assignedRealtor
    }
}

// Protocol conformance for reusability
protocol WorkItemProtocol: Identifiable {
    var id: UUID { get }
    var title: String { get set }
    var description: String { get set }
    var dueDate: Date? { get set }
    var priority: Priority { get set }
    var completed: Bool { get set }
    var claimedBy: UUID? { get set }
    var createdBy: UUID { get }
    var listing: UUID? { get set }
    var notes: [Note] { get set }
    var subtasks: [Subtask] { get set }
    var updatedAt: Date { get set }
    var isDirty: Bool { get set }
}

// Conformance for Task and Activity
extension Task: WorkItemProtocol {}
extension Activity: WorkItemProtocol {}
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
-- REALTORS
CREATE TABLE realtors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    avatar_url TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_realtors_email ON realtors(email);

-- LISTINGS
CREATE TABLE listings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    address TEXT NOT NULL,
    city TEXT DEFAULT '',
    state TEXT DEFAULT '',
    zip TEXT DEFAULT '',
    assigned_realtor UUID NOT NULL REFERENCES realtors(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'draft',
    created_by UUID NOT NULL REFERENCES realtors(id),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_listings_assigned_realtor ON listings(assigned_realtor);
CREATE INDEX idx_listings_created_by ON listings(created_by);
CREATE INDEX idx_listings_updated_at ON listings(updated_at);

-- TASKS
CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT DEFAULT '',
    due_date TIMESTAMP,
    priority TEXT DEFAULT 'medium',
    completed BOOLEAN DEFAULT FALSE,
    claimed_by UUID REFERENCES realtors(id) ON DELETE SET NULL,
    created_by UUID NOT NULL REFERENCES realtors(id),
    listing UUID REFERENCES listings(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_tasks_claimed_by ON tasks(claimed_by);
CREATE INDEX idx_tasks_created_by ON tasks(created_by);
CREATE INDEX idx_tasks_listing ON tasks(listing);
CREATE INDEX idx_tasks_updated_at ON tasks(updated_at);

-- ACTIVITIES
CREATE TABLE activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT DEFAULT '',
    type TEXT DEFAULT 'other',
    due_date TIMESTAMP,
    completed BOOLEAN DEFAULT FALSE,
    duration_minutes INTEGER,
    claimed_by UUID REFERENCES realtors(id) ON DELETE SET NULL,
    created_by UUID NOT NULL REFERENCES realtors(id),
    listing UUID REFERENCES listings(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_activities_claimed_by ON activities(claimed_by);
CREATE INDEX idx_activities_created_by ON activities(created_by);
CREATE INDEX idx_activities_listing ON activities(listing);
CREATE INDEX idx_activities_updated_at ON activities(updated_at);

-- NOTES
CREATE TABLE notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content TEXT NOT NULL,
    created_by UUID NOT NULL REFERENCES realtors(id),
    parent_type TEXT NOT NULL, -- 'task' | 'activity' | 'listing'
    parent_id UUID NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    edited_at TIMESTAMP
);

CREATE INDEX idx_notes_parent ON notes(parent_type, parent_id);
CREATE INDEX idx_notes_created_by ON notes(created_by);
CREATE INDEX idx_notes_created_at ON notes(created_at DESC);

-- SUBTASKS
CREATE TABLE subtasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    parent_type TEXT NOT NULL, -- 'task' | 'activity'
    parent_id UUID NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_subtasks_parent ON subtasks(parent_type, parent_id);

-- SYNC METADATA (Track last sync per realtor)
CREATE TABLE sync_metadata (
    realtor_id UUID PRIMARY KEY REFERENCES realtors(id) ON DELETE CASCADE,
    last_sync_tasks TIMESTAMP DEFAULT NOW(),
    last_sync_activities TIMESTAMP DEFAULT NOW(),
    last_sync_listings TIMESTAMP DEFAULT NOW(),
    last_sync_notes TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ROW-LEVEL SECURITY (RLS)
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;

-- Policy: Realtors can see tasks they created, claimed, or belong to their listings
CREATE POLICY task_access ON tasks
    FOR SELECT
    USING (
        created_by = auth.uid()
        OR claimed_by = auth.uid()
        OR listing IN (SELECT id FROM listings WHERE assigned_realtor = auth.uid())
    );

-- Similar policies for activities, listings, notes...
```

---

### **2.2 DTOs (Codable Models for Supabase)**

Create `DispatchKit/API/DTOs.swift`:

```swift
import Foundation

// Supabase response wraps the model + metadata
struct SupabaseTaskDTO: Codable {
    let id: UUID
    let title: String
    let description: String
    let due_date: Date?
    let priority: String
    let completed: Bool
    let claimed_by: UUID?
    let created_by: UUID
    let listing: UUID?
    let created_at: Date
    let updated_at: Date

    // Convert from Supabase DTO to SwiftData Task
    func toTask() -> Task {
        let task = Task(
            id: id,
            title: title,
            description: description,
            priority: Priority(rawValue: priority) ?? .medium,
            createdBy: created_by,
            dueDate: due_date
        )
        task.claimedBy = claimed_by
        task.listing = listing
        task.createdAt = created_at
        task.updatedAt = updated_at
        task.isDirty = false
        return task
    }
}

struct SupabaseActivityDTO: Codable {
    let id: UUID
    let title: String
    let description: String
    let type: String
    let due_date: Date?
    let completed: Bool
    let duration_minutes: Int?
    let claimed_by: UUID?
    let created_by: UUID
    let listing: UUID?
    let created_at: Date
    let updated_at: Date

    func toActivity() -> Activity {
        let activity = Activity(
            id: id,
            title: title,
            type: ActivityType(rawValue: type) ?? .other,
            createdBy: created_by,
            dueDate: due_date
        )
        activity.claimedBy = claimed_by
        activity.listing = listing
        activity.duration = duration_[minutes.map](http://minutes.map) { TimeInterval($0 * 60) }
        activity.createdAt = created_at
        activity.updatedAt = updated_at
        activity.isDirty = false
        return activity
    }
}

// Push models (Task/Activity to JSON for Supabase)
extension Task {
    func toSupabaseJSON() -> [String: Any] {
        return [
            "id": id.uuidString,
            "title": title,
            "description": description,
            "due_date": dueDate?.ISO8601Format(),
            "priority": priority.rawValue,
            "completed": completed,
            "claimed_by": claimedBy?.uuidString,
            "created_by": createdBy.uuidString,
            "listing": listing?.uuidString,
            "created_at": createdAt.ISO8601Format(),
            "updated_at": updatedAt.ISO8601Format()
        ]
    }
}

extension Activity {
    func toSupabaseJSON() -> [String: Any] {
        return [
            "id": id.uuidString,
            "title": title,
            "description": description,
            "type": type.rawValue,
            "due_date": dueDate?.ISO8601Format(),
            "completed": completed,
            "duration_minutes": [duration.map](http://duration.map) { Int($0 / 60) },
            "claimed_by": claimedBy?.uuidString,
            "created_by": createdBy.uuidString,
            "listing": listing?.uuidString,
            "created_at": createdAt.ISO8601Format(),
            "updated_at": updatedAt.ISO8601Format()
        ]
    }
}
```

**Acceptance Criteria**:

- [ ]  DTOs compile and `Codable` matches Postgres schema
- [ ]  `toTask()` and `toActivity()` correctly map DTO → SwiftData model
- [ ]  `toSupabaseJSON()` correctly serializes model → JSON for push

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
    try? [modelContext.save](http://modelContext.save)() // Save to local SwiftData

    // Async push to Supabase in background
    Task {
        await syncManager.syncUp()
    }
}

// IMPORTANT: When receiving from Supabase (syncDown), DO NOT mark dirty:
// DTO → Task conversion in syncDown() should set isDirty = false
```

---

### **3.2 Conflict Handling Example**

Create `DispatchKit/Services/ConflictResolver.swift`:

```swift
import Foundation

class ConflictResolver {

    // Resolve conflicting task updates
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
            // Always trust remote (server is source of truth)
            return remote

        case .manual:
            // Flag for manual review
            print("⚠️ Conflict detected for task: \([local.id](http://local.id))")
            print("Local version updated: \(local.updatedAt)")
            print("Remote version updated: \(remote.updatedAt)")
            // Return remote by default, but UI should prompt user
            return remote
        }
    }

    // Merge specific fields (e.g., if both sides modified different fields)
    static func mergeTaskFields(local: Task, remote: Task) -> Task {
        var merged = remote // Start with remote

        // If local has newer claim, keep it
        if let localClaim = local.claimedBy,
           local.updatedAt > remote.updatedAt {
            merged.claimedBy = localClaim
        }

        // Merge notes: combine unique notes
        let mergedNotes = Set([local.notes.map](http://local.notes.map) { $[0.id](http://0.id) })
            .union(Set([remote.notes.map](http://remote.notes.map) { $[0.id](http://0.id) }))
            .compactMap { id in local.notes.first { $[0.id](http://0.id) == id } ?? remote.notes.first { $[0.id](http://0.id) == id } }
        merged.notes = mergedNotes.sorted { $0.createdAt > $1.createdAt }

        return merged
    }
}
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

    let supabaseClient: SupabaseClient
    let modelContext: ModelContext
    let currentRealtorID: UUID

    private var realtimeChannel: RealtimeChannelV2?

    init(supabaseClient: SupabaseClient, modelContext: ModelContext, currentRealtorID: UUID) {
        self.supabaseClient = supabaseClient
        self.modelContext = modelContext
        self.currentRealtorID = currentRealtorID
    }

    // SYNC DOWN: Supabase → SwiftData
    func syncDown() async {
        await syncTasks()
        await syncActivities()
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
                .gt("updated_at", value: lastSync)
                .execute()

            let dtos = try JSONDecoder().decode([SupabaseTaskDTO].self, from: [response.data](http://response.data))

            for dto in dtos {
                let remoteTask = dto.toTask()

                // Check if exists locally
                let descriptor = FetchDescriptor<Task>(
                    predicate: #Predicate { $[0.id](http://0.id) == [dto.id](http://dto.id) }
                )
                let existingTasks = try modelContext.fetch(descriptor)

                if let existingTask = existingTasks.first {
                    // MERGE: apply conflict resolution
                    let merged = ConflictResolver.resolveTaskConflict(
                        local: existingTask,
                        remote: remoteTask,
                        strategy: existingTask.conflictStrategy
                    )

                    // Update existing
                    existingTask.title = merged.title
                    existingTask.description = merged.description
                    existingTask.dueDate = merged.dueDate
                    existingTask.priority = merged.priority
                    existingTask.completed = merged.completed
                    existingTask.claimedBy = merged.claimedBy
                    existingTask.updatedAt = merged.updatedAt
                    existingTask.isDirty = false
                    existingTask.syncedAt = Date()
                    existingTask.syncStatus = .synced
                } else {
                    // INSERT new
                    remoteTask.syncedAt = Date()
                    remoteTask.syncStatus = .synced
                    modelContext.insert(remoteTask)
                }
            }

            try [modelContext.save](http://modelContext.save)()
            syncStatus = .synced

        } catch {
            syncError = "Failed to sync tasks: \(error.localizedDescription)"
            syncStatus = .error
            print("❌ syncTasks error: \(error)")
        }

        isSyncing = false
    }

    private func syncActivities() async {
        // Identical pattern to syncTasks()
        // [PLACEHOLDER: Implement similarly]
    }

    private func syncListings() async {
        // Identical pattern
        // [PLACEHOLDER: Implement similarly]
    }

    private func syncNotes() async {
        // Fetch notes for all local tasks/activities/listings
        // [PLACEHOLDER: Implement similarly]
    }

    // SYNC UP: SwiftData → Supabase
    func syncUp() async {
        await syncUpTasks()
        await syncUpActivities()
    }

    private func syncUpTasks() async {
        do {
            isSyncing = true
            syncStatus = .syncing

            // Find all dirty tasks
            let descriptor = FetchDescriptor<Task>(
                predicate: #Predicate { $0.isDirty == true }
            )
            let dirtyTasks = try modelContext.fetch(descriptor)

            for task in dirtyTasks {
                // UPSERT: POST to Supabase
                let json = task.toSupabaseJSON()
                _ = try await supabaseClient
                    .from("tasks")
                    .upsert(json)
                    .execute()

                // Mark clean
                task.isDirty = false
                task.syncedAt = Date()
                task.syncStatus = .synced
            }

            try [modelContext.save](http://modelContext.save)()
            syncStatus = .synced

        } catch {
            syncError = "Failed to sync up tasks: \(error.localizedDescription)"
            syncStatus = .error
            print("❌ syncUpTasks error: \(error)")
        }

        isSyncing = false
    }

    private func syncUpActivities() async {
        // Identical pattern to syncUpTasks()
        // [PLACEHOLDER: Implement similarly]
    }

    // REALTIME LISTENER: Subscribe to Supabase changes
    func listenForRealtimeChanges() {
        // Subscribe to tasks table
        let channel = [supabaseClient.channel](http://supabaseClient.channel)("public:tasks")

        channel.on(
            .insert,
            handler: { [weak self] message in
                self?.handleRealtimeInsert(message, type: .task)
            }
        )

        channel.on(
            .update,
            handler: { [weak self] message in
                self?.handleRealtimeUpdate(message, type: .task)
            }
        )

        Task {
            try? await channel.subscribe()
        }

        self.realtimeChannel = channel
    }

    private func handleRealtimeInsert(_ message: Message, type: ItemType) {
        // Decode new item from message payload
        // Insert into SwiftData if not already present
        // [PLACEHOLDER: Implementation]
    }

    private func handleRealtimeUpdate(_ message: Message, type: ItemType) {
        // Decode updated item
        // Apply merge/conflict logic
        // Update in SwiftData
        // [PLACEHOLDER: Implementation]
    }
}

enum ItemType {
    case task
    case activity
}
```

**Acceptance Criteria**:

- [ ]  `syncDown()` fetches tasks with `updated_at > lastSyncTime`
- [ ]  Insert vs update logic works (checks local ID first)
- [ ]  `isDirty` correctly set to `false` on sync from server
- [ ]  Conflict resolution applied when both sides modified same field
- [ ]  `syncUp()` finds dirty tasks and pushes to Supabase
- [ ]  After sync, `isSyncing = false` and `syncStatus = .synced`

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

    @Published var showTaskDetail = false
    @Published var showActivityDetail = false
    @Published var showListingDetail = false

    // Select a task (used by list row tap)
    func selectTask(_ task: Task) {
        selectedTask = task
        showTaskDetail = true
    }

    func selectActivity(_ activity: Activity) {
        selectedActivity = activity
        showActivityDetail = true
    }

    func clearSelection() {
        selectedTask = nil
        selectedActivity = nil
        selectedListing = nil
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

    var body: some Scene {
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
struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Tasks
            TaskListContainer()
                .tabItem {
                    Label("Tasks", systemImage: "[checkmark.circle](http://checkmark.circle)")
                }
                .tag(0)

            // Tab 2: Activities
            ActivityListContainer()
                .tabItem {
                    Label("Activities", systemImage: "calendar")
                }
                .tag(1)

            // Tab 3: Listings
            ListingListContainer()
                .tabItem {
                    Label("Listings", systemImage: "house")
                }
                .tag(2)

            // Tab 4: Settings
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
    }
}

// TASK LIST CONTAINER (with navigation)
struct TaskListContainer: View {
    @EnvironmentObject var navigationState: NavigationState

    var body: some View {
        NavigationStack {
            TaskListView()
                .navigationDestination(isPresented: $navigationState.showTaskDetail) {
                    if let task = navigationState.selectedTask {
                        TaskDetailView(task: task)
                    }
                }
        }
    }
}

// ACTIVITY LIST CONTAINER (identical pattern)
struct ActivityListContainer: View {
    @EnvironmentObject var navigationState: NavigationState

    var body: some View {
        NavigationStack {
            ActivityListView()
                .navigationDestination(isPresented: $navigationState.showActivityDetail) {
                    if let activity = navigationState.selectedActivity {
                        ActivityDetailView(activity: activity)
                    }
                }
        }
    }
}
```

---

### **4.3 App-Level Navigation (iPad)**

Create `DispatchApp_iPad.swift`:

```swift
import SwiftUI

struct ContentView_iPad: View {
    @State private var selectedTab = 0
    @EnvironmentObject var navigationState: NavigationState

    var body: some View {
        NavigationSplitView {
            // SIDEBAR: Tab picker
            VStack {
                List(selection: $selectedTab) {
                    NavigationLink(value: 0) {
                        Label("Tasks", systemImage: "[checkmark.circle](http://checkmark.circle)")
                    }
                    NavigationLink(value: 1) {
                        Label("Activities", systemImage: "calendar")
                    }
                    NavigationLink(value: 2) {
                        Label("Listings", systemImage: "house")
                    }
                    NavigationLink(value: 3) {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
        } content: {
            // CONTENT: List based on tab
            Group {
                switch selectedTab {
                case 0:
                    TaskListView()
                case 1:
                    ActivityListView()
                case 2:
                    ListingListView()
                default:
                    SettingsView()
                }
            }
        } detail: {
            // DETAIL: Selected item
            Group {
                if let task = navigationState.selectedTask {
                    TaskDetailView(task: task)
                } else if let activity = navigationState.selectedActivity {
                    ActivityDetailView(activity: activity)
                } else if let listing = navigationState.selectedListing {
                    ListingDetailView(listing: listing)
                } else {
                    Text("Select an item")
                }
            }
        }
    }
}
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

    // Body text
    static let body = Font.system(size: 16, weight: .regular, design: .default)
    static let bodyBold = Font.system(size: 16, weight: .semibold, design: .default)
    static let bodySmall = Font.system(size: 14, weight: .regular, design: .default)

    // Captions
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
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

    static let surface = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.15, green: 0.15, blue: 0.16, alpha: 1)
            : UIColor.white
    })

    // Text
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary

    // Priority colors
    static let priorityLow = Color.gray
    static let priorityMedium = Color.yellow
    static let priorityHigh = [Color.orange](http://Color.orange)
    static let priorityUrgent = [Color.red](http://Color.red)

    // Status colors
    static let success = [Color.green](http://Color.green)
    static let error = [Color.red](http://Color.red)
    static let warning = [Color.orange](http://Color.orange)

    // Claim state
    static let claimed = [Color.blue](http://Color.blue)
    static let unclaimed = Color.gray
}

extension Priority {
    var color: Color {
        switch self {
        case .low: return DispatchColor.priorityLow
        case .medium: return DispatchColor.priorityMedium
        case .high: return DispatchColor.priorityHigh
        case .urgent: return DispatchColor.priorityUrgent
        }
    }
}
```

### **5.3 Component Examples Using Tokens**

Create `DispatchKit/Components/WorkItemRow.swift`:

```swift
import SwiftUI

struct WorkItemRow<T: WorkItemProtocol>: View {
    let item: T
    @EnvironmentObject var navigationState: NavigationState

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // CHECKBOX
            Button(action: { /* toggle completion */ }) {
                Image(systemName: item.completed ? "[checkmark.circle](http://checkmark.circle).fill" : "circle")
                    .resizable()
                    .frame(width: 22, height: 22)
                    .foregroundColor(item.completed ? .gray : .primary)
                    .font(.system(size: 22, weight: .thin))
            }
            .buttonStyle(.plain)

            // CONTENT
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(item.title)
                    .font(DispatchFont.bodyBold)
                    .foregroundColor(item.completed ? .gray : DispatchColor.textPrimary)
                    .strikethrough(item.completed)

                // Metadata row
                HStack(spacing: 8) {
                    // Priority dot
                    Circle()
                        .fill(item.priority.color)
                        .frame(width: 8, height: 8)

                    // Claimed by badge
                    if let _ = item.claimedBy {
                        Text("@Realtor")
                            .font(DispatchFont.caption)
                            .foregroundColor(DispatchColor.textSecondary)
                    }

                    // Due date
                    if let dueDate = item.dueDate {
                        Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                            .font(DispatchFont.caption)
                            .foregroundColor(DispatchColor.textSecondary)
                    }

                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            if let task = item as? Task {
                navigationState.selectTask(task)
            }
        }
    }
}
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

**Scenario**: User saves a note while offline.
- **Expected**: Note saves locally, marked `isDirty = true`, `syncStatus = .pending`
- **UI Feedback**: Show cloud icon with arrow (pending) next to note
- **Retry**: On next sync (app opened), automatically push
- **User Action**: If sync fails 3x, show error banner with "Retry" button

**Scenario**: Sync push fails (network timeout).
- **Retry Strategy**: Exponential backoff (1s, 2s, 4s, 8s, stop after 5 attempts)
- **User Awareness**: Badge on tab shows "!" if items pending
- **Recovery**: Automatic retry on scenePhase .active

## Offline Behavior

**Allowed Offline**:
- ✅ Create task/activity
- ✅ Edit task/activity
- ✅ Add note
- ✅ Complete task/activity
- ✅ Claim task/activity (optimistic update locally)

**Disallowed Offline**:
- ❌ Delete task (server-side cascades notes/subtasks)
- ❌ Delete listing (complex cascade)

**Sync On Return Online**:
1. Sync down (fetch latest from server)
2. Check for conflicts
3. Sync up (push local changes)
4. Realtime subscribe

## Claim Conflicts

**Scenario**: Two realtors claim same task simultaneously.

- **Resolution**: Last-write-wins (compare `updated_at` timestamps)
- **Server-side**: RLS policy ensures only one can claim (unique constraint)
- **Client-side**: If local claim loses, reload task from server, show toast "Task claimed by [Name]"
- **UX**: If current user loses claim mid-edit, show modal: "This task was claimed by [Name]. Review?"

## Multi-User Notes

**Scenario**: Two realtors add notes to same task.

- **Expected**: Both notes appear, sorted by `createdAt DESC`
- **Realtime**: New note from other user appears in 1-2 seconds
- **Conflict**: None—notes are independent rows

**Scenario**: Realtor edits a note while another realtor reads it.

- **Expected**: Edited note marked with `editedAt` timestamp, badge shows "edited"
- **Realtime**: List of notes refreshes to show edit

## Permissions

**Rule**: A realtor can only see tasks/activities they:
1. Created
2. Claimed
3. That belong to their listings (if they're the assigned realtor)

**Rule**: A realtor can only edit/delete their own notes, unless they're an admin

**Rule**: Admin can see/edit/delete anything (RLS enforced server-side)

## Sync Metadata

Track last sync time per entity type per realtor:
- On successful `syncDown()` for tasks, update `sync_metadata.last_sync_tasks = NOW()`
- On `syncDown()` call, query only rows where `updated_at > sync_metadata.last_sync_*`
- This avoids fetching the entire table every sync

## Conflict Resolution: Last-Write-Wins Algorithm

Given:
localTask.updatedAt = 2025-11-29 16:00:00
remoteTask.updatedAt = 2025-11-29 16:05:00

Result: Remote wins (16:05 > 16:00)
→ Discard all local changes to this field
→ Adopt remote value
→ Log: "Task sync: remote version applied (local: 16:00, remote: 16:05)"

If times are equal (within 1 second):
→ Manual review required, or use secondary sort (e.g., Realtor ID alphabetically)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // HEADER: Timestamp + User + Actions
            HStack {
                // User badge
                HStack(spacing: 6) {
                    Circle()
                        .fill([Color.blue](http://Color.blue).opacity(0.5))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text([note.createdBy.name](http://note.createdBy.name).prefix(1))
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                        )

                    Text([note.createdBy.name](http://note.createdBy.name))
                        .font(DispatchFont.bodySmall)
                        .foregroundColor(DispatchColor.textPrimary)
                }

                Spacer()

                // Timestamp
                VStack(alignment: .trailing, spacing: 2) {
                    Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(DispatchFont.caption)
                        .foregroundColor(DispatchColor.textSecondary)

                    if let editedAt = note.editedAt, editedAt > note.createdAt {
                        Text("edited")
                            .font(DispatchFont.caption)
                            .foregroundColor(.orange)
                    }
                }

                // Edit/Delete buttons
                Menu {
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(action: onDelete, role: .destructive) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(DispatchColor.textSecondary)
                }
            }

            // CONTENT: Truncated to 2 lines
            Text(note.content)
                .font(DispatchFont.body)
                .foregroundColor(DispatchColor.textPrimary)
                .lineLimit(2)
                .truncationMode(.tail)

            // SYNC STATUS
            HStack(spacing: 4) {
                switch note.syncStatus {
                case .synced:
                    Image(systemName: "[checkmark.circle](http://checkmark.circle).fill")
                        .foregroundColor(.green)
                case .pending:
                    Image(systemName: "[arrow.up.circle](http://arrow.up.circle)")
                        .foregroundColor(.orange)
                case .syncing:
                    ProgressView()
                        .scaleEffect(0.8)
                case .error:
                    Image(systemName: "[exclamationmark.circle](http://exclamationmark.circle).fill")
                        .foregroundColor(.red)
                }

                Text(note.syncStatus.rawValue.capitalized)
                    .font(DispatchFont.caption)
                    .foregroundColor(DispatchColor.textSecondary)
            }
        }
        .padding(12)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(10)
        .border(Color.gray.opacity(0.2), width: 1)
    }
}
```

---

### **7.2 NoteStack Component**

Create `DispatchKit/Components/NoteStack.swift`:

```swift
import SwiftUI

struct NoteStack<T: WorkItemProtocol>: View {
    let item: T
    let onDeleteNote: (UUID) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            // NOTES CONTAINER (clipped at 140pt)
            VStack(spacing: 12) {
                ForEach(Array(item.notes.sorted { $0.createdAt > $1.createdAt }.enumerated()),
                         id: \.[element.id](http://element.id)) { index, note in
                    NoteCard(
                        note: note,
                        onDelete: { onDeleteNote([note.id](http://note.id)) },
                        onEdit: { /* TODO: Edit mode */ }
                    )
                    .offset(y: CGFloat(index) * 8) // Cascade effect
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .clipped() // HARD CUTOFF at 140pt

            // SHADOW GRADIENT OVERLAY (indicates more notes above)
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
            .allowsHitTesting(false)
        }
    }
}
```

---

### **7.3 NoteInputArea Component**

Create `DispatchKit/Components/NoteInputArea.swift`:

```swift
import SwiftUI

struct NoteInputArea<T: WorkItemProtocol>: View {
    let item: T
    let currentRealtor: Realtor
    @State private var noteText = ""
    @State private var isSaving = false
    let onSave: (String) -> Void

    var body: some View {
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
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill([Color.blue](http://Color.blue).opacity(0.5))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Text([currentRealtor.name](http://currentRealtor.name).prefix(1))
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                        )

                    Text("Adding as \([currentRealtor.name](http://currentRealtor.name))")
                        .font(DispatchFont.caption)
                        .foregroundColor(DispatchColor.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, 4)

            // ACTION BUTTONS
            HStack(spacing: 12) {
                Button(action: { noteText = "" }) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                }

                Button(action: {
                    isSaving = true
                    onSave(noteText)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        noteText = ""
                        isSaving = false
                    }
                }) {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(10)
                    } else {
                        Text("Save Note")
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background([Color.blue](http://Color.blue))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .disabled(noteText.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            }
        }
        .padding(12)
    }
}
```

---

### **7.4 Parent ScrollView Context**

Create `DispatchKit/Components/ScrollableDetailView.swift`:

```swift
import SwiftUI

struct ScrollableDetailView<T: WorkItemProtocol>: View {
    @State var item: T

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // COLLAPSING HEADER
                DetailHeader(
                    item: item
                )
                .frame(height: 200)
                .background([Color.blue](http://Color.blue).opacity(0.1))

                // DETAILS SECTION
                DetailsSection(item: $item)
                    .padding(16)

                // METADATA SECTION
                MetadataSection(item: item)
                    .padding(16)

                // SUBTASKS SECTION
                SubtasksSection(item: $item)
                    .padding(16)

                // NOTES SECTION (Your unique feature)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Notes")
                        .font(DispatchFont.titleSmall)

                    NoteStack(
                        item: item,
                        onDeleteNote: { noteID in
                            item.notes.removeAll { $[0.id](http://0.id) == noteID }
                        }
                    )
                    .frame(height: 140)

                    NoteInputArea(
                        item: item,
                        currentRealtor: Realtor(name: "Me", email: "me@dispatch"),
                        onSave: { noteText in
                            let note = Note(
                                content: noteText,
                                createdBy: Realtor(name: "Me", email: "me@dispatch")
                            )
                            item.notes.append(note)
                        }
                    )
                }
                .padding(16)
            }
            .scrollClipDisabled(true) // iOS 17+: Prevent shadow clipping
            .background(DispatchColor.background)
        }
    }
}
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

    func testLastWriteWins_RemoteNewer() {
        let local = Task(title: "Old", createdBy: UUID())
        local.updatedAt = Date(timeIntervalSince1970: 1000)

        let remote = Task(title: "New", createdBy: UUID())
        remote.updatedAt = Date(timeIntervalSince1970: 2000)

        let merged = ConflictResolver.resolveTaskConflict(
            local: local,
            remote: remote,
            strategy: .lastWriteWins
        )

        XCTAssertEqual(merged.title, "New")
    }

    func testLastWriteWins_LocalNewer() {
        let local = Task(title: "New", createdBy: UUID())
        local.updatedAt = Date(timeIntervalSince1970: 3000)

        let remote = Task(title: "Old", createdBy: UUID())
        remote.updatedAt = Date(timeIntervalSince1970: 2000)

        let merged = ConflictResolver.resolveTaskConflict(
            local: local,
            remote: remote,
            strategy: .lastWriteWins
        )

        XCTAssertEqual(merged.title, "New")
    }
}
```

### **9.2 UI Tests (Example: NoteCard)**

Create `Tests/NoteCardUITests.swift`:

```swift
import XCTest

class NoteCardUITests: XCTestCase {

    func testNoteCardDisplay() {
        let app = XCUIApplication()
        app.launch()

        // Navigate to task with notes
        app.buttons["task-row-0"].tap()

        // Verify note card visible
        let noteCard = app.staticTexts["note-preview"]
        XCTAssertTrue(noteCard.exists)

        // Verify truncation (2 lines max)
        let noteHeight = noteCard.frame.height
        XCTAssert(noteHeight < 60) // Roughly 2 lines of text
    }
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

## Step 1: Clone & Install
```

git clone <repo>

cd dispatch

[xcode-build.sh](http://xcode-build.sh)

```

## Step 2: Set Up Local Supabase
```

# Install supabase CLI (<[https://supabase.com/docs/guides/cli/getting-started](https://supabase.com/docs/guides/cli/getting-started)>)

supabase init

supabase start

```

This spins up:
- PostgreSQL on [localhost:5432](http://localhost:5432)
- Supabase Studio on [localhost:54323](http://localhost:54323)
- API on [localhost:54321](http://localhost:54321)

## Step 3: Load Schema
```

supabase db pull # Or manually import supabase/schema.sql

```

## Step 4: Configure Xcode
Set environment variable in scheme:
- `SUPABASE_URL = [http://localhost:54321`](http://localhost:54321`)
- `SUPABASE_ANON_KEY = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` (from `supabase status`)

## Step 5: Run Tests
```

xcodebuild test -scheme Dispatch

```

## Step 6: Run App
⌘R in Xcode (select iPhone 15 Pro simulator)

## Debugging
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
- [ ]  Read Apple's SwiftData docs: [https://developer.apple.com/documentation/swiftdata](https://developer.apple.com/documentation/swiftdata)
- [ ]  Supabase project created, PostgreSQL access confirmed
- [ ]  Git repo initialized with `.gitignore`
- [ ]  This entire guide downloaded and bookmarked

---

This guide should give a jr dev everything they need to start coding without getting stuck. Each ticket is ~3-5 hours, compilable, and testable independently.

```

```