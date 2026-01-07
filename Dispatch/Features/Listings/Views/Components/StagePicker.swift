//
//  StagePicker.swift
//  Dispatch
//
//  Horizontal scrolling picker for listing lifecycle stages
//

import SwiftUI

/// A horizontal scrollable picker for selecting listing stage.
/// Shows all 6 stages as capsule buttons with icon + label.
struct StagePicker: View {
    @Binding var stage: ListingStage
    let onChange: ((ListingStage) -> Void)?
    private let horizontalInset: CGFloat

    @Namespace private var animationNamespace

    init(
        stage: Binding<ListingStage>,
        horizontalInset: CGFloat = DS.Spacing.md,
        onChange: ((ListingStage) -> Void)? = nil
    ) {
        self._stage = stage
        self.horizontalInset = horizontalInset
        self.onChange = onChange
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(ListingStage.allCases, id: \.self) { stageOption in
                    stageButton(for: stageOption)
                }
            }
        }
        // Let the scroll view extend beyond a typical padded column,
        // but keep the first/last items aligned with surrounding content.
        .padding(.horizontal, -horizontalInset)
        .contentMargins(.horizontal, horizontalInset, for: .scrollContent)
        .scrollClipDisabled()
    }

    @ViewBuilder
    private func stageButton(for stageOption: ListingStage) -> some View {
        let isSelected = stage == stageOption
        let stageColor = DS.Colors.Stage.color(for: stageOption)

        Button {
            withAnimation(.snappy(duration: 0.2)) {
                stage = stageOption
                onChange?(stageOption)
            }
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: DS.Icons.Stage.icon(for: stageOption))
                    .font(.system(size: 12, weight: .medium))
                Text(stageOption.displayName)
                    .font(DS.Typography.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background {
            if isSelected {
                Capsule()
                    .fill(stageColor.opacity(0.2))
                    .matchedGeometryEffect(id: "stageSelection", in: animationNamespace)
            } else {
                Capsule()
                    .stroke(DS.Colors.border, lineWidth: 1)
            }
        }
        .foregroundStyle(isSelected ? stageColor : DS.Colors.Text.secondary)
    }
}

// MARK: - Preview

#Preview("Stage Picker") {
    struct PreviewWrapper: View {
        @State private var selectedStage: ListingStage = .pending

        var body: some View {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Text("Listing Stage")
                    .font(DS.Typography.headline)

                StagePicker(stage: $selectedStage) { newStage in
                    print("Stage changed to: \(newStage.displayName)")
                }

                Divider()

                Text("Selected: \(selectedStage.displayName)")
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    return PreviewWrapper()
}
