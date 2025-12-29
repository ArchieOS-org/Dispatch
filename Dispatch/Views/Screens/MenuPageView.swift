//
//  MenuPageView.swift
//  Dispatch
//
//  Things 3-style menu page for iPhone navigation.
//  Refactored for Layout Unification (StandardScreen)
//

import SwiftUI
import SwiftData

struct MenuPageView: View {
    // MARK: - Queries

    @Query private var allTasksRaw: [TaskItem]
    @Query private var allActivitiesRaw: [Activity]
    @Query private var allListingsRaw: [Listing]
    @Query private var allRealtors: [User]

    // MARK: - Filtered Properties

    private var openTasks: [TaskItem] {
        allTasksRaw.filter { $0.status != .completed && $0.status != .deleted }
    }

    private var openActivities: [Activity] {
        allActivitiesRaw.filter { $0.status != .completed && $0.status != .deleted }
    }

    private var activeListings: [Listing] {
        allListingsRaw.filter { $0.status != .deleted }
    }
    
    private var activeRealtors: [User] {
        allRealtors.filter { $0.userType == .realtor }
    }

    // MARK: - Environment

    @EnvironmentObject private var syncManager: SyncManager
    @EnvironmentObject private var lensState: LensState

    // MARK: - Helpers

    private func count(for section: MenuSection) -> Int {
        switch section {
        case .myWorkspace: return openTasks.count + openActivities.count
        case .listings: return activeListings.count
        case .realtors: return activeRealtors.count
        }
    }

    // MARK: - Body

    var body: some View {
        StandardScreen(title: "Dispatch", layout: .column, scroll: .disabled) {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    #if os(iOS)
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        PullToSearchSensor()
                    }
                    #endif

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
            }
            .pullToSearch()
            .background(DS.Colors.Background.grouped)
        }
        .onAppear {
            lensState.currentScreen = .menu
        }
    }
}

// MARK: - Menu Section Card

private struct MenuSectionCard: View {
    let section: MenuSection
    let count: Int

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Circle()
                .fill(section.accentColor.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: section.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(section.accentColor)
                }

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(section.title)
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.Text.primary)
                Text("\(count) open")
                    .font(DS.Typography.bodySecondary)
                    .foregroundColor(DS.Colors.Text.secondary)
            }

            Spacer()

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

// MARK: - Button Style

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
    MenuPageView()
        .modelContainer(for: [TaskItem.self, Activity.self, Listing.self, User.self], inMemory: true)
        .environmentObject(SyncManager.shared)
        .environmentObject(SearchPresentationManager())
        .environmentObject(LensState())
}
