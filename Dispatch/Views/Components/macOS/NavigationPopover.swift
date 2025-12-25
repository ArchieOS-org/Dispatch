
import SwiftUI

/// The entire dropdown panel containing search + navigation list.
struct NavigationPopover: View {
    @Binding var searchText: String
    @Binding var isPresented: Bool
    let currentTab: ContentView.Tab
    let onNavigate: (ContentView.Tab) -> Void
    
    // Hardcoded counts for MVP demo
    let inboxCount = 4
    let todayCount = 8

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search Field
            QuickFindField(text: $searchText, isFocused: $isFieldFocused)
                .padding(10)

            Divider()

            // Scrollable List
            ScrollView {
                VStack(spacing: 2) {
                    // Smart Lists
                    Group {
                        NavigationListItem(
                            title: "Inbox",
                            icon: "tray",
                            badgeCount: inboxCount,
                            isSelected: currentTab == .tasks, // Simplified logic for demo
                            action: { onNavigate(.tasks) }
                        )
                        
                        NavigationListItem(
                            title: "Today",
                            icon: "star.fill",
                            badgeCount: todayCount,
                            isSelected: false,
                            action: { onNavigate(.tasks) } // In real map, would map to specific filter
                        )
                    }

                    Divider().padding(.vertical, 4)

                    // Areas (e.g. Listings)
                    NavigationListItem(
                        title: "Listings",
                        icon: "building.2",
                        badgeCount: nil,
                        isSelected: currentTab == .listings,
                        action: { onNavigate(.listings) }
                    )
                    
                    NavigationListItem(
                        title: "Activities",
                        icon: "list.bullet.clipboard",
                        badgeCount: nil,
                        isSelected: currentTab == .activities,
                        action: { onNavigate(.activities) }
                    )
                }
                .padding(6)
            }
            .frame(maxHeight: 400)
        }
        .frame(width: 260)
        .onAppear {
            isFieldFocused = true
        }
    }
}
