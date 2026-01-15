//
//  DescriptionGeneratorSheet.swift
//  Dispatch
//
//  Main sheet container for the AI Listing Description Generator.
//  Orchestrates the two-screen flow: Input -> Output
//

import SwiftData
import SwiftUI

// MARK: - DescriptionGeneratorSheet

/// Sheet container for generating AI-powered listing descriptions.
/// Supports two-screen flow with NavigationStack and handles all states.
struct DescriptionGeneratorSheet: View {

  // MARK: Lifecycle

  /// Initialize with an optional preselected listing.
  /// - Parameter preselectedListing: Listing to use for generation (optional)
  init(preselectedListing: Listing? = nil) {
    _state = State(initialValue: DescriptionGeneratorState(preselectedListing: preselectedListing))
  }

  // MARK: Internal

  var body: some View {
    NavigationStack {
      Group {
        if state.showingOutput {
          DescriptionOutputView(state: state, onDismiss: { dismiss() })
            .navigationTitle("Description")
            .toolbar {
              ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                  dismiss()
                }
              }
            }
        } else {
          DescriptionInputView(
            state: state,
            listings: listings,
            onGenerate: {
              Task {
                await state.generateDescription()
              }
            }
          )
          .navigationTitle("Generate")
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("Cancel") {
                dismiss()
              }
            }
          }
        }
      }
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
    }
    #if os(iOS)
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
    #endif
    #if os(macOS)
    .frame(minWidth: 500, idealWidth: 600, minHeight: 500, idealHeight: 700)
    #endif
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @Query(sort: \Listing.address) private var listings: [Listing]
  @State private var state: DescriptionGeneratorState
}

// MARK: - Preview

#Preview("Description Generator Sheet") {
  PreviewShell(withNavigation: false) { context in
    let listings = (try? context.fetch(FetchDescriptor<Listing>())) ?? []
    let preselected = listings.first

    return DescriptionGeneratorSheet(preselectedListing: preselected)
  }
}

#Preview("Description Generator - Empty") {
  DescriptionGeneratorSheet()
}
