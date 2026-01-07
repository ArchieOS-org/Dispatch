//
//  SettingsView.swift
//  Dispatch
//
//  Main Settings entry point for admin configuration.
//  Part of Listing Types & Activity Templates feature.
//

import SwiftUI
import SwiftData

/// Root Settings view for admins.
/// Access Control: Only visible to admin users.
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var syncManager: SyncManager
    
    var body: some View {
        StandardScreen(title: "Settings", layout: .column, scroll: .disabled) {
            StandardList([SettingsSection.listingTypes]) { section in
                NavigationLink(value: section) {
                    SettingsRow(section: section)
                }
            }
        }
    }
}

// MARK: - Settings Section

enum SettingsSection: String, Identifiable, CaseIterable {
    case listingTypes = "listing_types"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .listingTypes: return "Listing Types"
        }
    }
    
    var icon: String {
        switch self {
        case .listingTypes: return DS.Icons.Entity.listing
        }
    }
    
    var description: String {
        switch self {
        case .listingTypes: return "Configure listing types and auto-generated activities"
        }
    }
}

// MARK: - Settings Row

private struct SettingsRow: View {
    let section: SettingsSection
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Circle()
                .fill(DS.Colors.Background.secondary)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: section.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(DS.Colors.Text.primary)
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Colors.Text.primary)
                
                Text(section.description)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.Text.secondary)
            }
            
            Spacer()
            
            Image(systemName: DS.Icons.Navigation.forward)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.Colors.Text.tertiary)
        }
        .padding(.vertical, DS.Spacing.md)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview {
    PreviewShell { context in
        // Seed with a sample user
    } content: { _ in
        SettingsView()
    }
}
