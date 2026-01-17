//
//  PhotoThumbnail.swift
//  Dispatch
//
//  Draggable photo tile component for the description generator.
//  Displays image with hero badge overlay and delete button.
//

import SwiftUI

// MARK: - PhotoThumbnail

/// A single photo tile for the photo grid.
/// Supports drag-to-reorder, hero badge for first photo, and delete action.
struct PhotoThumbnail: View {

  // MARK: Internal

  let photo: UploadedPhoto
  let onDelete: () -> Void
  let onSetHero: () -> Void

  var body: some View {
    ZStack(alignment: .topTrailing) {
      // Image content
      imageContent

      // Delete button overlay
      deleteButton
    }
    .overlay(alignment: .bottomLeading) {
      // Hero badge
      if photo.isHero {
        heroBadge
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall))
    .dsShadow(DS.Shadows.subtle)
    .contextMenu {
      contextMenuItems
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityHint("Use context menu for more options")
    .accessibilityAddTraits(photo.isHero ? .isHeader : [])
    .accessibilityAction(named: "Set as Hero") {
      onSetHero()
    }
    .accessibilityAction(named: "Delete") {
      onDelete()
    }
  }

  // MARK: Private

  @ViewBuilder
  private var imageContent: some View {
    if let image = photo.image {
      image
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(minHeight: 0, maxHeight: .infinity)
        .clipped()
    } else {
      // Fallback for failed image decode
      Rectangle()
        .fill(DS.Colors.Background.secondary)
        .overlay {
          VStack(spacing: DS.Spacing.xs) {
            Image(systemName: "photo")
              .font(.system(size: 24))
              .foregroundStyle(DS.Colors.Text.tertiary)
            Text("Unable to load")
              .font(DS.Typography.captionSecondary)
              .foregroundStyle(DS.Colors.Text.tertiary)
          }
        }
    }
  }

  @ViewBuilder
  private var deleteButton: some View {
    Button(action: onDelete) {
      Image(systemName: "xmark.circle.fill")
        .font(.system(size: 22))
        .foregroundStyle(.white)
        .background(
          Circle()
            .fill(Color.black.opacity(0.5))
            .frame(width: 24, height: 24)
        )
    }
    .buttonStyle(.plain)
    .frame(width: DS.Spacing.minTouchTarget, height: DS.Spacing.minTouchTarget)
    .contentShape(Rectangle())
    .accessibilityLabel("Delete photo")
    .accessibilityHint("Double tap to remove this photo")
  }

  @ViewBuilder
  private var heroBadge: some View {
    HStack(spacing: DS.Spacing.xxs) {
      Image(systemName: "star.fill")
        .font(.system(size: 10))
      Text("Hero")
        .font(DS.Typography.captionSecondary)
        .fontWeight(.semibold)
    }
    .foregroundStyle(.white)
    .padding(.horizontal, DS.Spacing.sm)
    .padding(.vertical, DS.Spacing.xxs)
    .background(
      Capsule()
        .fill(DS.Colors.accent)
    )
    .padding(DS.Spacing.xs)
  }

  @ViewBuilder
  private var contextMenuItems: some View {
    if !photo.isHero {
      Button {
        onSetHero()
      } label: {
        Label("Set as Hero Photo", systemImage: "star")
      }
    }

    Button(role: .destructive) {
      onDelete()
    } label: {
      Label("Delete Photo", systemImage: "trash")
    }
  }

  private var accessibilityLabel: String {
    var label = photo.filename
    if photo.isHero {
      label = "Hero photo: \(label)"
    }
    return label
  }
}

// MARK: - Preview

#Preview("Photo Thumbnails") {
  let sampleData = createSampleImageData()

  HStack(spacing: DS.Spacing.md) {
    // Hero photo
    PhotoThumbnail(
      photo: UploadedPhoto(
        imageData: sampleData,
        filename: "living_room.jpg",
        sortOrder: 0
      ),
      onDelete: { },
      onSetHero: { }
    )
    .frame(width: 120, height: 120)

    // Regular photo
    PhotoThumbnail(
      photo: UploadedPhoto(
        imageData: sampleData,
        filename: "bedroom.jpg",
        sortOrder: 1
      ),
      onDelete: { },
      onSetHero: { }
    )
    .frame(width: 120, height: 120)
  }
  .padding()
}

// MARK: - Helper

private func createSampleImageData() -> Data {
  // Create a simple colored rectangle as sample image data
  #if os(iOS)
  let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200))
  let image = renderer.image { ctx in
    UIColor.systemBlue.setFill()
    ctx.fill(CGRect(origin: .zero, size: CGSize(width: 200, height: 200)))
  }
  return image.jpegData(compressionQuality: 0.8) ?? Data()
  #elseif os(macOS)
  let image = NSImage(size: NSSize(width: 200, height: 200))
  image.lockFocus()
  NSColor.systemBlue.setFill()
  NSRect(origin: .zero, size: NSSize(width: 200, height: 200)).fill()
  image.unlockFocus()
  return image.tiffRepresentation ?? Data()
  #endif
}
