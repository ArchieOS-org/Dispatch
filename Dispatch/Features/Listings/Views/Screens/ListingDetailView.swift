//
//  ListingDetailView.swift
//  Dispatch
//
//  Full detail view for a Listing
//  Refactored for Layout Unification (StandardScreen)
//

import SwiftData
import SwiftUI

struct ListingDetailView: View {

  // MARK: Internal

  let listing: Listing
  let userLookup: (UUID) -> User?

  var body: some View {
    StandardScreen(title: listing.address, layout: .column, scroll: .automatic) {
      content
    } toolbarContent: {
      ToolbarItem(placement: .primaryAction) {
        OverflowMenu(actions: listingActions)
      }
    }
    // Alerts
    .alert("Delete Listing?", isPresented: $showDeleteListingAlert) {
      Button("Cancel", role: .cancel) { }
      Button("Delete", role: .destructive) {
        deleteListing()
      }
    } message: {
      Text("This listing will be marked as deleted. Associated tasks and activities will remain.")
    }
    .alert("Delete Note?", isPresented: $showDeleteNoteAlert) {
      Button("Cancel", role: .cancel) {
        noteToDelete = nil
      }
      Button("Delete", role: .destructive) {
        confirmDeleteNote()
      }
    } message: {
      Text("This note will be permanently deleted.")
    }
    .task {
      // Refresh notes from server when viewing listing
      await syncManager.refreshNotesForParent(parentId: listing.id, parentType: .listing)
    }
    #if os(macOS)
    .onDeleteCommand {
      showDeleteListingAlert = true
    }
    #endif
  }

  // MARK: Private

  private static let unauthenticatedUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()

  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var syncManager: SyncManager
  @EnvironmentObject private var lensState: LensState
  @EnvironmentObject private var actions: WorkItemActions
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  // noteText removed - NotesContent uses internal state

  @State private var showDeleteNoteAlert = false
  @State private var noteToDelete: Note?
  @State private var showDeleteListingAlert = false

  private var currentUserId: UUID {
    syncManager.currentUserID ?? Self.unauthenticatedUserId
  }

  private var owner: User? {
    userLookup(listing.ownedBy)
  }

  private var activeTasks: [TaskItem] {
    listing.tasks.filter { $0.status != .deleted }
  }

  private var activeActivities: [Activity] {
    listing.activities.filter { $0.status != .deleted }
  }

  private var filteredTasks: [TaskItem] {
    activeTasks.filter { lensState.audience.matches(audiences: $0.audiences) }
  }

  private var currentUserType: UserType? {
    syncManager.currentUser?.userType
  }

  /// Only .marketing flips the order; all other roles default to Admin first.
  private var showAdminFirst: Bool {
    currentUserType != .marketing
  }

  private var isOverdue: Bool {
    guard let date = listing.dueDate else { return false }
    return date < Calendar.current.startOfDay(for: Date())
  }

  private var overdueText: String {
    guard let date = listing.dueDate else { return "" }
    let startToday = Calendar.current.startOfDay(for: Date())
    let startDue = Calendar.current.startOfDay(for: date)
    let days = Calendar.current.dateComponents([.day], from: startDue, to: startToday).day ?? 0

    if days < 7 {
      let formatter = DateFormatter()
      formatter.dateFormat = "EEE"
      return formatter.string(from: date)
    }

    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    return formatter.string(from: date)
  }

  private var listingActions: [OverflowMenu.Action] {
    [
      OverflowMenu.Action(id: "edit", title: "Edit Listing", icon: DS.Icons.Action.edit) {
        // Edit placeholder
      },
      OverflowMenu.Action(id: "delete", title: "Delete Listing", icon: DS.Icons.Action.delete, role: .destructive) {
        showDeleteListingAlert = true
      }
    ]
  }

  private var content: some View {
    // Compute once per render to avoid repeated filtering
    // Uses existing lens predicate; do not change matching semantics.
    let adminActivities = activeActivities.filter {
      $0.audiences.contains(.admin) && lensState.audience.matches(audiences: $0.audiences)
    }
    let marketingActivities = activeActivities.filter {
      $0.audiences.contains(.marketing) && lensState.audience.matches(audiences: $0.audiences)
    }
    let hasAnyActivities = !adminActivities.isEmpty || !marketingActivities.isEmpty

    return VStack(alignment: .leading, spacing: 0) {
      stageSection
      Color.clear.frame(height: DS.Spacing.lg)

      metadataSection
      Color.clear.frame(height: DS.Spacing.lg)

      notesSection

      if !filteredTasks.isEmpty {
        VStack(alignment: .leading, spacing: 0) {
          tasksHeader
          Divider().padding(.vertical, DS.Spacing.sm)
          tasksSection
        }
      }

      // Activity sections - wrapped in container to prevent orphan spacing
      if hasAnyActivities {
        // Keep normal section spacing when Tasks exist; otherwise use the smaller Notes gap
        Color.clear.frame(height: filteredTasks.isEmpty ? DS.Spacing.sm : DS.Spacing.lg)
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
          if showAdminFirst {
            adminSection(activities: adminActivities)
            marketingSection(activities: marketingActivities)
          } else {
            marketingSection(activities: marketingActivities)
            adminSection(activities: adminActivities)
          }
        }
      }
    }
    .padding(.bottom, DS.Spacing.md)
  }

  private var stageSection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      // Location
      if !listing.city.isEmpty {
        Text("\(listing.city), \(listing.province) \(listing.postalCode)")
          .font(DS.Typography.body)
          .foregroundColor(DS.Colors.Text.secondary)
      }
      StagePicker(stage: .init(
        get: { listing.stage },
        set: { newStage in
          listing.stage = newStage
          listing.markPending()
          syncManager.requestSync()
        }
      ))
    }
  }

  private var metadataSection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      if owner != nil || listing.dueDate != nil {
        Divider().padding(.top, DS.Spacing.sm)

        HStack {
          if let owner {
            RealtorPill(realtorID: owner.id, realtorName: owner.name)
          }

          Spacer()

          if let date = listing.dueDate {
            if isOverdue {
              HStack(spacing: 4) {
                Image(systemName: "flag.fill")
                Text(overdueText)
              }
              .font(DS.Typography.caption)
              .foregroundStyle(DS.Colors.overdue)
            } else {
              DatePill(date: date)
            }
          }
        }
        .padding(.top, DS.Spacing.xs)
      }

      Divider().padding(.top, DS.Spacing.sm)

      // Listing type
      Text(listing.listingType.rawValue.capitalized)
        .font(DS.Typography.body)
        .foregroundColor(DS.Colors.Text.primary)

      Divider().padding(.top, DS.Spacing.sm)
    }
  }

  private var tasksHeader: some View {
    HStack {
      Text("Tasks")
        .font(DS.Typography.headline)
        .foregroundColor(DS.Colors.Text.primary)
      Text("(\(filteredTasks.count))")
        .font(DS.Typography.bodySecondary)
        .foregroundColor(DS.Colors.Text.secondary)
      Spacer()
    }
  }

  private var tasksSection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      if filteredTasks.isEmpty {
        emptyStateView(icon: DS.Icons.Entity.task, title: "No Tasks", message: "Tasks for this listing will appear here")
      } else {
        VStack(spacing: 0) {
          ForEach(filteredTasks) { task in
            NavigationLink(value: AppRoute.workItem(.task(task))) {
              WorkItemRow(
                item: .task(task),
                userLookup: actions.userLookupDict,
                onComplete: { actions.onComplete(.task(task)) },
                onEdit: { },
                onDelete: { },
                hideDueDate: true
              )
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }

  private var notesSection: some View {
    NotesContent(
      notes: listing.notes,
      userLookup: userLookup,
      onSave: { content in addNote(content: content) },
      onDelete: { note in
        noteToDelete = note
        showDeleteNoteAlert = true
      }
    )
  }

  private func sectionHeader(title: String, count: Int) -> some View {
    HStack {
      Text(title)
        .font(DS.Typography.headline)
        .foregroundColor(DS.Colors.Text.primary)
      Text("(\(count))")
        .font(DS.Typography.bodySecondary)
        .foregroundColor(DS.Colors.Text.secondary)
      Spacer()
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(title), \(count)") // Avoid hardcoded pluralization
  }

  @ViewBuilder
  private func adminSection(activities: [Activity]) -> some View {
    if !activities.isEmpty {
      VStack(alignment: .leading, spacing: 0) {
        sectionHeader(title: NSLocalizedString("Admin", comment: "Section header for admin activities"), count: activities.count)
        Divider().padding(.vertical, DS.Spacing.sm)
        activitiesContent(activities)
      }
    }
  }

  @ViewBuilder
  private func marketingSection(activities: [Activity]) -> some View {
    if !activities.isEmpty {
      VStack(alignment: .leading, spacing: 0) {
        sectionHeader(
          title: NSLocalizedString("Marketing", comment: "Section header for marketing activities"),
          count: activities.count
        )
        Divider().padding(.vertical, DS.Spacing.sm)
        activitiesContent(activities)
      }
    }
  }

  private func activitiesContent(_ activities: [Activity]) -> some View {
    VStack(spacing: 0) {
      ForEach(activities) { activity in
        NavigationLink(value: AppRoute.workItem(.activity(activity))) {
          WorkItemRow(
            item: .activity(activity),
            userLookup: actions.userLookupDict,
            onComplete: { actions.onComplete(.activity(activity)) },
            onEdit: { },
            onDelete: { },
            hideDueDate: true
          )
        }
        .buttonStyle(.plain)
      }
    }
  }

  private func emptyStateView(icon: String, title: String, message: String) -> some View {
    VStack(spacing: DS.Spacing.sm) {
      Image(systemName: icon)
        .font(.system(size: 32))
        .foregroundColor(DS.Colors.Text.tertiary)
      Text(title)
        .font(DS.Typography.headline)
        .foregroundColor(DS.Colors.Text.secondary)
      Text(message)
        .font(DS.Typography.caption)
        .foregroundColor(DS.Colors.Text.tertiary)
    }
    .padding(.vertical, DS.Spacing.xl)
  }

  private func addNote(content: String) {
    let note = Note(content: content, createdBy: currentUserId, parentType: .listing, parentId: listing.id)
    listing.notes.append(note)
    // No need to mark listing pending, Note is first-class syncable now
    syncManager.requestSync()
  }

  private func confirmDeleteNote() {
    guard let note = noteToDelete else { return }
    note.softDelete(by: currentUserId)
    noteToDelete = nil
    syncManager.requestSync()
  }

  private func deleteListing() {
    listing.status = .deleted
    listing.deletedAt = Date()
    listing.markPending()
    syncManager.requestSync()
    dismiss()
    // Clean up navigation path to prevent navigating back to deleted listing
    appState.dispatch(.removeRoute(.listing(listing.id)))
  }

}

// MARK: - Previews

#Preview("Pure Content") {
  PreviewShell(
    // Force Lens Match
    lensState: {
      let l = LensState()
      l.audience = .all
      return l
    }(),
    setup: { context in
      PreviewDataFactory.seed(context)

      // Preview-only: populate location fields so the metadata section renders
      let listingID = PreviewDataFactory.listingID
      let listingDescriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingID })
      if let listing = try? context.fetch(listingDescriptor).first {
        listing.city = "Toronto"
        listing.province = "ON"
        listing.postalCode = "M5V 2T6"
      }
    }
  ) { context in
    // O(1) Lookup covering all users (owner + others)
    let users = (try? context.fetch(FetchDescriptor<User>())) ?? []
    let usersById = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })

    // Deterministic Fetch
    let listingID = PreviewDataFactory.listingID
    let listingDescriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingID })
    if let listing = try? context.fetch(listingDescriptor).first {
      ListingDetailView(
        listing: listing,
        userLookup: { id in usersById[id] }
      )
      .environmentObject(WorkItemActions(
        currentUserId: PreviewDataFactory.aliceID,
        userLookupDict: usersById
      ))
    } else {
      Text("Missing preview data")
    }
  }
}

#Preview("With Two Notes") {
  PreviewShell(
    // Force Lens Match
    lensState: {
      let l = LensState()
      l.audience = .all
      return l
    }(),
    setup: { context in
      PreviewDataFactory.seed(context)

      // Preview-only: populate location fields so the metadata section renders
      let listingID = PreviewDataFactory.listingID
      let listingDescriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingID })
      if let listing = try? context.fetch(listingDescriptor).first {
        listing.city = "Toronto"
        listing.province = "ON"
        listing.postalCode = "M5V 2T6"

        // Preview-only: ensure there are exactly two notes
        let previewUserId = UUID()
        listing.notes = [
          Note(content: "First note for preview", createdBy: previewUserId, parentType: .listing, parentId: listing.id),
          Note(content: "Second note for preview", createdBy: previewUserId, parentType: .listing, parentId: listing.id)
        ]
      }
    }
  ) { context in
    // O(1) Lookup covering all users (owner + others)
    let users = (try? context.fetch(FetchDescriptor<User>())) ?? []
    let usersById = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })

    // Deterministic Fetch
    let listingID = PreviewDataFactory.listingID
    let listingDescriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingID })
    if let listing = try? context.fetch(listingDescriptor).first {
      ListingDetailView(
        listing: listing,
        userLookup: { id in usersById[id] }
      )
      .environmentObject(WorkItemActions(
        currentUserId: PreviewDataFactory.aliceID,
        userLookupDict: usersById
      ))
    } else {
      Text("Missing preview data")
    }
  }
}
