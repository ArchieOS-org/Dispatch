# Dispatch Product Roadmap

---

## Stage 0 — Dispatch Core (Implemented)

**Goal:** One trusted home for each listing: what it is, where it stands, what's missing.

### Core screens

- **My Workspace** — Dashboard with work items grouped by date (Overdue, Today, Tomorrow, Upcoming, No Due Date)
- **Listings** — Stage-based view (Pending, Working On, Live, Sold, Re-List, Done)
- **Listing Detail** — Overview with address, price, MLS#, linked tasks/activities, notes, stage history
- **Properties** — Property directory grouping addresses with unit support
- **Realtors** — Team member directory with profiles, linked listings, work items
- **Settings** — Admin configuration for listing types and activity templates

### Core features

- **Create listing manually** (admin/realtor)
- **6-stage listing lifecycle** — Pending → Working On → Live → Sold → Re-List → Done
- **Listing metadata** — Address, city, province, postal code, price, MLS number
- **Listing types** — Sale, Lease, Pre-Listing, Rental, Other (extensible via admin)
- **Listing status** — Draft, Active, Pending, Closed, Deleted (soft delete)
- **Property grouping** — Multiple listings can reference same physical address
- **Notes** — On listings with edit tracking (edited_by, edited_at)
- **Status history** — Audit trail of all status changes with reason and timestamp

### Admin controls

- **User roles:** Realtor, Admin, Marketing, Operator, Exec
- **Permissions by role:**
  - Admin/Marketing/Operator — Full access, can claim work, can configure settings
  - Realtor — Own listings only, cannot claim work items
  - Exec — Read-only access to all content
- **Audit log:** Status changes, claim events with timestamps and user attribution
- **Row-Level Security:** PostgreSQL RLS policies enforce access control

### Integrations

- **Supabase Auth** — Google OAuth sign-in
- **Real-time sync** — Bidirectional sync with conflict resolution (last-write-wins)
- **Broadcast subscriptions** — Instant updates when others make changes

### "Done when"

- [x] Core listing management functional
- [x] Multi-platform support (iOS, iPadOS, macOS)
- [x] Real-time sync operational
- [x] Role-based access enforced

---

## Stage 0.5 — Work Items + Claim System (Implemented)

**Goal:** Structured task and activity tracking with clear ownership and accountability.

### Work item features

- **Tasks** — Work items with title, description, due date, priority, status
- **Activities** — Typed work items (Call, Email, Meeting, Show Property, Follow Up, Other)
- **Priority levels** — Low, Medium, High, Urgent (color-coded)
- **Status tracking** — Open, In Progress, Completed, Deleted
- **Due date management** — Automatic grouping by date section
- **Subtasks/checklists** — Hierarchical breakdown within tasks/activities
- **Notes** — Comments with edit tracking and creator attribution
- **Audience targeting** — Role-based visibility (Admin-only, Marketing-only)

### Claim system

- **Claim/Release** — Staff members claim ownership of work items
- **Claim history** — Full audit trail of claim/release actions with timestamps
- **Claim state UI** — Visual indicators:
  - Unclaimed (available)
  - Claimed by me (I own it)
  - Claimed by other (shows claimer name)
- **Staff-only claiming** — Only Admin, Marketing, Operator roles can claim

### Admin (Settings tab)

- **Listing type definitions** — Create custom listing types
- **Activity templates** — Auto-generated activities per listing type
  - Position ordering
  - Audience targeting
  - Default assignee assignment
  - Template descriptions

### Search & filtering

- **Global search** — Pull-to-search overlay (iOS/iPad)
- **Multi-entity search** — Tasks, activities, listings, properties, realtors
- **Audience filter** — Cycle through All → Admin → Marketing
- **Content kind filter** — All → Tasks → Activities

### System behavior

- **Bidirectional sync** — Local-first with server reconciliation
- **Real-time broadcasts** — Instant updates via Supabase channels
- **Sync state tracking** — Per-entity: synced | pending | failed
- **Conflict resolution** — Last-write-wins with local-authoritative guard
- **Delta sync optimization** — Only sync changes since last sync timestamp

### Integrations

- **Slack** — `createdVia: slack` source tracking, `sourceSlackMessages` field
- **Realtor App** — `createdVia: realtorApp` source tracking
- **External API** — `createdVia: api` for programmatic access

### "Done when"

- [x] Tasks and activities fully CRUD functional
- [x] Claim system operational with audit trail
- [x] Activity templates auto-generate on listing creation
- [x] Real-time sync across all clients
- [x] Search functional across all entities

---

## Stage 1 — Notifications + Calendar (Planned)

**Goal:** Proactive reminders and external calendar integration.

### Notification features

- Push notifications for:
  - Work item assigned/claimed
  - Due date approaching
  - Status changes on owned items
  - New items requiring attention
- In-app notification center
- Notification preferences per user

### Calendar integration

- Export due dates to system calendar (EventKit)
- Two-way sync for key dates
- Calendar view of upcoming work

### Admin controls

- Notification preferences by role
- SLA defaults (per activity type)
- Reminder timing configuration

### Integrations

- **Apple Push Notifications** — iOS/macOS native push
- **EventKit** — Calendar integration
- **Notification scheduling** — Server-side scheduled reminders

### "Done when"

- [ ] Users receive push notifications for key events
- [ ] Due dates appear in device calendar
- [ ] Configurable reminder preferences

---

## Stage 2 — Document Management (Planned)

**Goal:** Centralized document storage with version tracking.

### Document features

- Document upload to listings/work items
- Version history with diff tracking
- Required-docs checklist per listing type
- Document status (draft, final, signed)
- Photo/attachment support from camera/files

### Document organization

- Auto-organized folder structure per listing
- Document tagging and categorization
- Quick access to recent/pending documents

### Admin controls

- Required document templates per listing type
- Document approval workflows
- Retention policies

### Integrations

- **CloudKit/iCloud Drive** — Native Apple storage
- **Google Drive** — External storage option
- **E-sign (read-only)** — DocuSign/dotloop status visibility

### "Done when"

- [ ] Documents upload and attach to listings
- [ ] Required-docs checklist enforced
- [ ] Version history accessible

---

## Stage 3 — Messaging (Planned)

**Goal:** Deal-scoped communication replacing external chat apps.

### Messaging features

- Listing-scoped threads (all communication in context)
- Agent ↔ Admin threads
- Admin ↔ Admin threads (internal coordination)
- @mention notifications
- Attach photos/docs to messages
- Message search within listings

### System behavior

- Messages linked to specific listings
- Audit trail of all communications
- Read receipts and delivery status

### Admin controls

- Messaging permissions by role
- Message retention policies
- Audit log export for messages

### "Done when"

- [ ] Agent ↔ Admin communication happens in-app
- [ ] Admin ↔ Admin handoffs occur in listing context
- [ ] Reduction in external chat app usage

---

## Stage 4 — Automation + Playbooks (Future)

**Goal:** The system generates and executes work plans automatically.

### Playbook features

- Deal type selection triggers auto-generated task plan
- Dependencies between tasks (can't complete X until Y exists)
- "Missing items" detector based on playbook vs. actual state
- Standard templates for communications
- Compliance packet auto-assembly

### Automation features

- Auto-send request sequences for missing items
- Auto-generate messages from listing context
- Auto-flag risk:
  - Missing doc after milestone
  - Deadline approaching with prerequisites missing
- Suggested next actions (one-tap to execute)

### Admin UX

- "Today" view across all listings
- "Blocked" view (waiting on agent/client)
- "At risk" view (deadline approaching, prerequisites missing)

### "Done when"

- [ ] New admin can run a listing correctly by following playbook
- [ ] Measurable reduction in "last-minute scramble" items
- [ ] Auto-generated compliance packages

---

## Stage 5 — Brokerage Control Center (Future)

**Goal:** Standardized operations and visibility across entire brokerage.

### Leadership features

- Pipeline overview by stage
- Bottleneck map (where listings stall)
- Compliance dashboard (exceptions + risk)
- Staffing view (admin load, aging work items)
- Playbook performance (which steps cause delays)

### Operational features

- Brokerage templates library
- Onboarding mode for new admins
- Permissioned reporting for teams/branches
- Performance analytics by user/role

### Integrations

- Reporting exports (CSV, scheduled)
- Commission/accounting systems
- Transaction management sync (SkySlope, dotloop)

### "Done when"

- [ ] Leadership uses Dispatch as operational "truth"
- [ ] Playbooks become standard operating procedure

---

## Stage 6 — External System Sync (Future)

**Goal:** No double entry. Dispatch is the work layer, official systems stay correct.

### Sync scope

- Create/update listing metadata in transaction systems
- Sync listing status bidirectionally
- Push documents to official deal record
- Keep link back to Dispatch as "work view"

### Data safety controls

- Tenant isolation per brokerage
- Role-based access control
- Full audit trail export
- Data ownership + deletion policy
- Admin control over data usage/learning

### Integrations

- **Transaction management:** SkySlope OR dotloop
- **E-sign deep sync:** DocuSign OR dotloop (executed docs filed automatically)
- **Calendar:** Two-way for key dates

### "Done when"

- [ ] Admins stop updating two systems
- [ ] Official record always matches Dispatch state

---

# Cross-cutting Platform Requirements

### Security & Trust (Implemented)

- [x] Brokerage data isolation (RLS policies)
- [x] Encryption in transit (HTTPS/TLS)
- [x] Audit logs (status changes, claim events)
- [x] Role-based access control
- [x] Soft delete (data recoverable)

### Reliability (Implemented)

- [x] Offline-tolerant local-first architecture (SwiftData)
- [x] Bidirectional sync with conflict resolution
- [x] Sync state tracking (synced/pending/failed)
- [x] Delta sync optimization (only changed records)
- [x] Real-time broadcast subscriptions

### Multi-Platform Support (Implemented)

- [x] iOS 18+ (iPhone)
- [x] iPadOS 18+ (iPad with split view)
- [x] macOS 15+ (multi-window support)
- [x] Platform-specific UI adaptations
- [x] Shared codebase with conditional compilation

### Analytics Infrastructure (Partial)

- [x] Creation source tracking (dispatch, slack, realtor_app, api, import)
- [x] Status change history with timestamps
- [x] Claim event history with timestamps
- [ ] Time-to-complete metrics
- [ ] Drop-off and bottleneck detection
- [ ] Performance dashboards

---

# Technical Architecture Summary

| Layer | Technology |
|-------|------------|
| UI Framework | SwiftUI |
| Local Persistence | SwiftData |
| Backend | Supabase (PostgreSQL + Auth + Realtime) |
| Authentication | Google OAuth via Supabase Auth |
| Real-time | Supabase Broadcast Channels |
| Sync Strategy | Local-first with bidirectional delta sync |

### Data Models

| Entity | Description |
|--------|-------------|
| User | Team members (Realtor, Admin, Marketing, Operator, Exec) |
| Listing | Property listing with 6-stage lifecycle |
| Property | Physical address grouping multiple listings |
| TaskItem | Work item with priority, status, due date |
| Activity | Typed work item (call, email, meeting, etc.) |
| Note | Comments on listings/tasks/activities |
| Subtask | Checklist items within tasks/activities |
| StatusChange | Audit trail of status transitions |
| ClaimEvent | Audit trail of claim/release actions |
| ListingTypeDefinition | Custom listing types with activity templates |
| ActivityTemplate | Auto-generated activities per listing type |

---

# Current Integration Points

| Integration | Status | Notes |
|-------------|--------|-------|
| Google OAuth | Implemented | Supabase Auth |
| Slack | Source tracking | `createdVia: slack`, `sourceSlackMessages` field |
| Realtor App | Source tracking | `createdVia: realtorApp` |
| External API | Source tracking | `createdVia: api` |
| Push Notifications | Not implemented | Infrastructure ready |
| Calendar (EventKit) | Not implemented | Planned |
| Document Storage | Not implemented | Planned |
| E-sign (DocuSign/dotloop) | Not implemented | Future |
| Transaction Systems | Not implemented | Future |
