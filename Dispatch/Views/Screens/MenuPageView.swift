//
//  MenuPageView.swift
//  Dispatch
//
//  Things 3-style menu page for iPhone navigation.
//  Large cards for each section with item counts.
//

import SwiftUI
import SwiftData

/// Menu page home screen for iPhone navigation.
/// Displays large, full-width cards for each section (Tasks, Activities, Listings).
/// Users tap a card to push-navigate into that section.
///
/// Supports pull-down-to-search via `PullToSearchModifier` (iOS 18+).
struct MenuPageView: View {
    // MARK: - Queries

    @Query private var allTasksRaw: [TaskItem]
    @Query private var allActivitiesRaw: [Activity]
    @Query private var allListingsRaw: [Listing]

    // MARK: - Filtered Computed Properties (SwiftData predicates can't compare enums directly)

    /// Open tasks (not completed, not deleted)
    private var openTasks: [TaskItem] {
        allTasksRaw.filter { $0.status != .completed && $0.status != .deleted }
    }

    /// Open activities (not completed, not deleted)
    private var openActivities: [Activity] {
        allActivitiesRaw.filter { $0.status != .completed && $0.status != .deleted }
    }

    /// Active listings (not deleted)
    private var activeListings: [Listing] {
        allListingsRaw.filter { $0.status != .deleted }
    }

    // MARK: - Environment

    @EnvironmentObject private var syncManager: SyncManager
    @EnvironmentObject private var lensState: LensState
    @EnvironmentObject private var dynamicSearchState: DynamicSearchState

    // MARK: - Computed Properties

    /// Get count for each section
    private func count(for section: MenuSection) -> Int {
        switch section {
        case .tasks: return openTasks.count
        case .activities: return openActivities.count
        case .listings: return activeListings.count
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            // Main content with dynamic top padding
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    ForEach(MenuSection.allCases) { section in
                        NavigationLink(value: section) {
                            MenuSectionCard(
                                section: section,
                                count: count(for: section)
                            )
                        }
                        .buttonStyle(MenuCardButtonStyle())
                    }
                }
                .padding(DS.Spacing.lg)
                .padding(.top, dynamicSearchBoxTopPadding)
            }
            .pullToSearch()
            .dynamicSearchScroll()
            .background(DS.Colors.Background.grouped)
            
            // Dynamic search box overlay
            VStack {
                DynamicSearchBox()
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.dynamicSearchTopPadding)
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            lensState.currentScreen = .menu
        }
        .onDisappear {
            // Reset search state when leaving the view
            dynamicSearchState.reset()
        }
    }
    
    // MARK: - Computed Properties
    
    /// Dynamic top padding for content based on search box state
    private var dynamicSearchBoxTopPadding: CGFloat {
        let baseHeight = DS.Spacing.dynamicSearchBoxHeight + DS.Spacing.dynamicSearchTopPadding * 2
        let arrowHeight = dynamicSearchState.showArrow ? (DS.Spacing.dynamicSearchArrowSize + DS.Spacing.dynamicSearchArrowSpacing) : 0
        let offsetHeight = dynamicSearchState.searchBoxOffset
        
        return baseHeight + arrowHeight + offsetHeight
    }
}

// MARK: - Menu Section Card

/// A large card representing a section in the menu.
/// Displays icon, title, count, and chevron.
private struct MenuSectionCard: View {
    let section: MenuSection
    let count: Int

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Icon in colored circle (44pt)
            Circle()
                .fill(section.accentColor.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: section.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(section.accentColor)
                }

            // Title + count
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(section.title)
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.Text.primary)
                Text("\(count) open")
                    .font(DS.Typography.bodySecondary)
                    .foregroundColor(DS.Colors.Text.secondary)
            }

            Spacer()

            // Chevron
            Image(systemName: DS.Icons.Navigation.forward)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DS.Colors.Text.tertiary)
        }
        .padding(DS.Spacing.cardPadding)
        .background(DS.Colors.Background.card)
        .cornerRadius(DS.Spacing.radiusCard)
        .dsShadow(DS.Shadows.card)
    }
}

// MARK: - Menu Card Button Style

/// Button style for menu cards with press animation.
/// Respects accessibility Reduce Motion preference.
private struct MenuCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Previews

#Preview("Menu Page View") {
    let container = try! ModelContainer(
        for: TaskItem.self, Activity.self, Listing.self, User.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let context = container.mainContext

    // Add some sample data
    let user = User(name: "Test User", email: "test@dispatch.ca", userType: .admin)
    context.insert(user)

    for i in 1...5 {
        let task = TaskItem(title: "Task \(i)", priority: .medium, declaredBy: user.id)
        context.insert(task)
    }

    for i in 1...3 {
        let activity = Activity(title: "Activity \(i)", type: .call, priority: .medium, declaredBy: user.id)
        context.insert(activity)
    }

    for i in 1...2 {
        let listing = Listing(address: "\(i) Main Street", city: "Toronto", province: "ON", postalCode: "M5V 1A1", ownedBy: user.id)
        context.insert(listing)
    }

    return NavigationStack {
        MenuPageView()
    }
    .modelContainer(container)
    .environmentObject(SyncManager.shared)
    .environmentObject(SearchPresentationManager())
    .environmentObject(DynamicSearchState())
    .environmentObject(LensState())
}

#Preview("Menu Page View - Empty") {
    let container = try! ModelContainer(
        for: TaskItem.self, Activity.self, Listing.self, User.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    return NavigationStack {
        MenuPageView()
    }
    .modelContainer(container)
    .environmentObject(SyncManager.shared)
    .environmentObject(SearchPresentationManager())
    .environmentObject(DynamicSearchState())
    .environmentObject(LensState())
}
