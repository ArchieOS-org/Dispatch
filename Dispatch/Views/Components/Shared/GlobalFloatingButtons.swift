//
//  GlobalFloatingButtons.swift
//  Dispatch
//
//  Persistent floating buttons for filter and quick entry (iPhone only)
//

import SwiftUI

/// Global floating buttons that persist during navigation.
/// - Left: Filter button (tap to cycle audience, long-press for menu)
/// - Right: FAB for quick entry
///
/// Hides with animation when text input is focused or keyboard is visible.
struct GlobalFloatingButtons: View {
    @EnvironmentObject private var lensState: LensState
    @EnvironmentObject private var quickEntryState: QuickEntryState
    @EnvironmentObject private var overlayState: AppOverlayState

    var body: some View {
        #if os(iOS)
        GeometryReader { geo in
            // ALWAYS render - animate opacity/offset instead of conditional
            // Prevents transition bugs from subtree removal
            HStack {
                // Filter Button (left) with Menu for long-press
                filterButton

                Spacer()

                // FAB (right)
                FloatingActionButton {
                    quickEntryState.isPresenting = true
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, max(DS.Spacing.lg, geo.safeAreaInsets.bottom))
            .frame(maxHeight: .infinity, alignment: .bottom)
            // Animate visibility via opacity + offset (not conditional render)
            .opacity(overlayState.isOverlayHidden ? 0 : 1)
            .offset(y: overlayState.isOverlayHidden ? 12 : 0)
            .allowsHitTesting(!overlayState.isOverlayHidden)
            .animation(.easeInOut(duration: 0.2), value: overlayState.isOverlayHidden)
        }
        #endif
    }

    // MARK: - Filter Button

    #if os(iOS)
    @State private var bounceTrigger: Int = 0

    private var filterButton: some View {
        Menu {
            // Audience section - use Picker for automatic checkmarks
            Picker("Audience", selection: $lensState.audience) {
                ForEach(AudienceLens.allCases, id: \.self) { lens in
                    Label(lens.label, systemImage: lens.icon)
                        .tag(lens)
                }
            }

            // Show section - use Picker for automatic checkmarks
            Picker("Show", selection: $lensState.kind) {
                ForEach(ContentKind.allCases, id: \.self) { kind in
                    Text(kind.label)
                        .tag(kind)
                }
            }

            // Clear Filters (conditional)
            if lensState.isFiltered {
                Divider()
                Button("Clear Filters") {
                    lensState.reset()
                }
            }
        } label: {
            AudienceLensButton(
                lens: lensState.audience,
                isFiltered: lensState.isFiltered,
                bounceTrigger: bounceTrigger
            )
        } primaryAction: {
            // TAP = cycle lens + bounce
            lensState.cycleAudience()
            bounceTrigger += 1
        }
        .sensoryFeedback(.selection, trigger: lensState.audience)
    }
    #endif
}

// MARK: - Previews

#if os(iOS)
#Preview("Global Floating Buttons") {
    ZStack {
        DS.Colors.Background.grouped
            .ignoresSafeArea()

        GlobalFloatingButtons()
    }
    .environmentObject(LensState())
    .environmentObject(QuickEntryState())
    .environmentObject(AppOverlayState())
}

#Preview("Global Floating Buttons - Filtered") {
    let lensState = LensState()
    lensState.audience = .admin

    return ZStack {
        DS.Colors.Background.grouped
            .ignoresSafeArea()

        GlobalFloatingButtons()
    }
    .environmentObject(lensState)
    .environmentObject(QuickEntryState())
    .environmentObject(AppOverlayState())
}
#endif
