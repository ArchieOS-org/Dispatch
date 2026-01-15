//
//  DescriptionOutputView.swift
//  Dispatch
//
//  Screen 2 of the Description Generator: Result display.
//  Shows generated description, status, and action buttons.
//

import SwiftUI

// MARK: - DescriptionOutputView

/// Second screen of the description generator flow.
/// Displays the generated description with status and actions.
struct DescriptionOutputView: View {

  // MARK: Internal

  @Bindable var state: DescriptionGeneratorState
  let onDismiss: () -> Void

  var body: some View {
    ScrollView {
      VStack(spacing: DS.Spacing.sectionSpacing) {
        // Property header
        propertyHeader

        // Description content
        descriptionContent

        // Actions
        actionsSection
      }
      .padding(DS.Spacing.lg)
    }
  }

  // MARK: Private

  @State private var showCopiedFeedback = false

  @ViewBuilder
  private var propertyHeader: some View {
    HStack {
      VStack(alignment: .leading, spacing: DS.Spacing.xs) {
        Text(state.propertyTitle)
          .font(DS.Typography.headline)
          .foregroundStyle(DS.Colors.Text.primary)
          .lineLimit(1)

        if state.inputMode == .existingListing, let listing = state.selectedListing {
          HStack(spacing: DS.Spacing.sm) {
            if !listing.city.isEmpty {
              Text(listing.city)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.Text.secondary)
            }
            ListingTypePill(type: listing.listingType)
          }
        }
      }

      Spacer()

      DescriptionStatusChip(status: state.status)
    }
    .padding(DS.Spacing.md)
    .background(DS.Colors.Background.card)
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusMedium))
  }

  @ViewBuilder
  private var descriptionContent: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.md) {
      HStack {
        Text("Generated Description")
          .font(DS.Typography.headline)
          .foregroundStyle(DS.Colors.Text.primary)

        Spacer()

        copyButton
      }

      Text(state.generatedDescription)
        .font(DS.Typography.body)
        .foregroundStyle(DS.Colors.Text.primary)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(DS.Spacing.lg)
    .background(DS.Colors.Background.card)
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusMedium))
  }

  @ViewBuilder
  private var copyButton: some View {
    Button {
      state.copyToClipboard()
      withAnimation {
        showCopiedFeedback = true
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        withAnimation {
          showCopiedFeedback = false
        }
      }
    } label: {
      HStack(spacing: DS.Spacing.xs) {
        Image(systemName: showCopiedFeedback ? DS.Icons.Alert.success : "doc.on.doc")
        Text(showCopiedFeedback ? "Copied" : "Copy")
      }
      .font(DS.Typography.caption)
      .foregroundStyle(showCopiedFeedback ? DS.Colors.success : DS.Colors.accent)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(showCopiedFeedback ? "Copied to clipboard" : "Copy description")
    .accessibilityHint("Copies the generated description to your clipboard")
  }

  @ViewBuilder
  private var actionsSection: some View {
    VStack(spacing: DS.Spacing.md) {
      switch state.status {
      case .draft:
        sendToAgentButton
        regenerateButton

      case .sent:
        waitingForApprovalView

      case .ready:
        markAsPostedButton
        regenerateButton

      case .posted:
        completedView
      }
    }
  }

  @ViewBuilder
  private var sendToAgentButton: some View {
    Button {
      state.sendToAgent()
    } label: {
      HStack(spacing: DS.Spacing.sm) {
        Image(systemName: "paperplane.fill")
        Text("Send to Agent")
      }
      .font(DS.Typography.headline)
      .frame(maxWidth: .infinity)
      .frame(height: DS.Spacing.minTouchTarget)
    }
    .buttonStyle(.borderedProminent)
  }

  @ViewBuilder
  private var regenerateButton: some View {
    Button {
      state.reset()
    } label: {
      HStack(spacing: DS.Spacing.sm) {
        Image(systemName: DS.Icons.Action.refresh)
        Text("Start Over")
      }
      .font(DS.Typography.body)
      .frame(maxWidth: .infinity)
      .frame(height: DS.Spacing.minTouchTarget)
    }
    .buttonStyle(.bordered)
  }

  @ViewBuilder
  private var waitingForApprovalView: some View {
    VStack(spacing: DS.Spacing.md) {
      HStack(spacing: DS.Spacing.sm) {
        ProgressView()
          .progressViewStyle(.circular)

        Text("Waiting for agent approval...")
          .font(DS.Typography.body)
          .foregroundStyle(DS.Colors.Text.secondary)
      }
      .padding(DS.Spacing.md)
      .frame(maxWidth: .infinity)
      .background(DS.Colors.info.opacity(0.1))
      .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusMedium))

      // PHASE 3: Real agent approval workflow
      Text("The agent will review and approve your description")
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.Text.tertiary)
    }
  }

  @ViewBuilder
  private var markAsPostedButton: some View {
    Button {
      state.markAsPosted()
    } label: {
      HStack(spacing: DS.Spacing.sm) {
        Image(systemName: "checkmark.seal.fill")
        Text("Mark as Posted")
      }
      .font(DS.Typography.headline)
      .frame(maxWidth: .infinity)
      .frame(height: DS.Spacing.minTouchTarget)
    }
    .buttonStyle(.borderedProminent)
    .tint(DS.Colors.success)
  }

  @ViewBuilder
  private var completedView: some View {
    VStack(spacing: DS.Spacing.md) {
      HStack(spacing: DS.Spacing.sm) {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(DS.Colors.success)

        Text("Description posted successfully")
          .font(DS.Typography.body)
          .foregroundStyle(DS.Colors.Text.primary)
      }
      .padding(DS.Spacing.md)
      .frame(maxWidth: .infinity)
      .background(DS.Colors.success.opacity(0.1))
      .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusMedium))

      Button {
        onDismiss()
      } label: {
        Text("Done")
          .font(DS.Typography.headline)
          .frame(maxWidth: .infinity)
          .frame(height: DS.Spacing.minTouchTarget)
      }
      .buttonStyle(.borderedProminent)
    }
  }
}

// MARK: - Preview

#Preview("Output View - Draft") {
  PreviewShell { _ in
    let state = DescriptionGeneratorState()
    state.generatedDescription = """
      Welcome to 123 Main Street, a stunning residence in the heart of downtown that perfectly blends modern elegance with timeless comfort.

      Step inside to discover an open-concept living space bathed in natural light, featuring hardwood floors throughout and designer finishes at every turn.
      """
    state.showingOutput = true
    state.status = .draft

    return DescriptionOutputView(state: state, onDismiss: { })
  }
}

#Preview("Output View - Ready") {
  PreviewShell { _ in
    let state = DescriptionGeneratorState()
    state.generatedDescription = "Sample description text..."
    state.showingOutput = true
    state.status = .ready

    return DescriptionOutputView(state: state, onDismiss: { })
  }
}

#Preview("Output View - Posted") {
  PreviewShell { _ in
    let state = DescriptionGeneratorState()
    state.generatedDescription = "Sample description text..."
    state.showingOutput = true
    state.status = .posted

    return DescriptionOutputView(state: state, onDismiss: { })
  }
}
