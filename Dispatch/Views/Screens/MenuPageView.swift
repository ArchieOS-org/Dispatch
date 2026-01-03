//
//  MenuPageView.swift
//  Dispatch
//
//  Things 3-style menu page for iPhone navigation.
//

import SwiftUI
import SwiftData

struct MenuPageView: View {
    // MARK: - Queries

    @Query private var allTasksRaw: [TaskItem]
    @Query private var allActivitiesRaw: [Activity]
    @Query private var allPropertiesRaw: [Property]
    @Query private var allListingsRaw: [Listing]
    @Query private var allRealtors: [User]

    // MARK: - Filtered Properties

    private var openTasks: [TaskItem] {
        allTasksRaw.filter { $0.status != .completed && $0.status != .deleted }
    }

    private var openActivities: [Activity] {
        allActivitiesRaw.filter { $0.status != .completed && $0.status != .deleted }
    }

    private var activeProperties: [Property] {
        allPropertiesRaw.filter { $0.deletedAt == nil }
    }

    private var activeListings: [Listing] {
        allListingsRaw.filter { $0.status != .deleted }
    }

    private var activeRealtors: [User] {
        allRealtors.filter { $0.userType == .realtor }
    }

    // MARK: - Computed Counts

    private var overdueCount: Int {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let overdueTasks = openTasks.filter { ($0.dueDate ?? .distantFuture) < startOfToday }
        let overdueActivities = openActivities.filter { ($0.dueDate ?? .distantFuture) < startOfToday }
        return overdueTasks.count + overdueActivities.count
    }

    private func count(for section: MenuSection) -> Int {
        switch section {
        case .myWorkspace: return openTasks.count + openActivities.count
        case .properties: return activeProperties.count
        case .listings: return activeListings.count
        case .realtors: return activeRealtors.count
        case .settings: return 0
        }
    }

    // MARK: - Body

    var body: some View {
        List {
            ForEach(MenuSection.allCases) { section in
                NavigationLink(value: section) {
                    MenuSectionRow(
                        section: section,
                        count: count(for: section),
                        overdueCount: section == .myWorkspace ? overdueCount : 0
                    )
                }
                .listRowInsets(EdgeInsets(top: 0, leading: DS.Spacing.lg, bottom: 0, trailing: DS.Spacing.lg))
                .listRowBackground(DS.Colors.Background.primary)
                .listRowSeparator(.hidden)
                .padding(.top, section == .settings ? DS.Spacing.xl : 0)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(DS.Colors.Background.primary)
        .navigationTitle("Dispatch")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
}

// MARK: - Menu Section Row

private struct MenuSectionRow: View {
    let section: MenuSection
    let count: Int
    let overdueCount: Int

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: section.icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(section.accentColor)
                .frame(width: 28, alignment: .leading)

            Text(section.title)
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.Text.primary)
                .lineLimit(1)

            Spacer()

            rightSideContent
                .frame(minWidth: 28, alignment: .trailing)
        }
        .frame(minHeight: DS.Spacing.minTouchTarget)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
    }

    @ViewBuilder
    private var rightSideContent: some View {
        if section == .settings {
            EmptyView()
        } else if section == .myWorkspace && overdueCount > 0 {
            Text("\(overdueCount)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(DS.Colors.overdue)
                .clipShape(Capsule())
        } else if count > 0 {
            Text("\(count)")
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.Text.secondary)
        }
    }

    private var accessibilityLabelText: String {
        if section == .settings {
            return section.title
        } else if section == .myWorkspace && overdueCount > 0 {
            return "\(section.title), \(overdueCount) overdue"
        } else if count > 0 {
            return "\(section.title), \(count) open"
        } else {
            return section.title
        }
    }
}

// MARK: - Previews

#Preview("Menu Page View") {
    NavigationStack {
        MenuPageView()
    }
    .modelContainer(for: [TaskItem.self, Activity.self, Property.self, Listing.self, User.self], inMemory: true)
    .environmentObject(SyncManager(mode: .preview))
    .environmentObject(LensState())
}
