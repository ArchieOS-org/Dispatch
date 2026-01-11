//
//  DraftPhotoThumbnail.swift
//  Dispatch
//
//  Individual photo cell for the draft photo gallery.
//  Displays photo with edit overlays (delete button, drag handle).
//

import SwiftUI

struct DraftPhotoThumbnail: View {

  // MARK: Internal

  let photo: DemoPhoto
  let isHero: Bool
  let onDelete: () -> Void

  var body: some View {
    ZStack(alignment: .topTrailing) {
      photoContent
        .aspectRatio(isHero ? 16 / 9 : 1, contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: isHero ? DS.Spacing.radiusMedium : DS.Spacing.radiusSmall))
        .dsShadow(DS.Shadows.card)

      // Delete button overlay
      deleteButton
    }
  }

  // MARK: Private

  @ViewBuilder
  private var photoContent: some View {
    // Try to load bundled image, fallback to gradient placeholder
    if hasImage(named: photo.imageName) {
      Image(photo.imageName)
        .resizable()
        .aspectRatio(contentMode: .fill)
    } else {
      placeholderView
    }
  }

  private var placeholderView: some View {
    ZStack {
      // Gradient background based on photo index
      LinearGradient(
        colors: [gradientColor, gradientColor.opacity(0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      VStack(spacing: DS.Spacing.xs) {
        Image(systemName: "photo.fill")
          .font(isHero ? .largeTitle : .title2)
          .foregroundStyle(.white.opacity(0.8))

        Text(photo.label)
          .font(isHero ? DS.Typography.headline : DS.Typography.caption)
          .foregroundStyle(.white)
          .lineLimit(1)
      }
      .padding(DS.Spacing.sm)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var deleteButton: some View {
    Button {
      onDelete()
    } label: {
      Image(systemName: "xmark.circle.fill")
        .font(.system(size: isHero ? 24 : 18))
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
    }
    .padding(DS.Spacing.sm)
    .contentShape(Rectangle())
  }

  private var gradientColor: Color {
    let colors: [Color] = [
      .blue, .purple, .pink, .red, .orange,
      .yellow, .green, .teal, .cyan, .indigo,
      .mint, .brown, .gray, .blue, .purple,
      .green, .orange, .teal, .pink, .indigo,
    ]
    let index = (photo.index - 1) % colors.count
    return colors[index]
  }

  private func hasImage(named name: String) -> Bool {
    #if os(iOS)
    return UIImage(named: name) != nil
    #elseif os(macOS)
    return NSImage(named: name) != nil
    #else
    return false
    #endif
  }

}

// MARK: - Add Photo Button Cell

struct AddPhotoCell: View {

  let isHero: Bool
  let onAdd: () -> Void

  var body: some View {
    Button {
      onAdd()
    } label: {
      ZStack {
        RoundedRectangle(cornerRadius: isHero ? DS.Spacing.radiusMedium : DS.Spacing.radiusSmall)
          .fill(DS.Colors.Background.secondary)
          .strokeBorder(
            DS.Colors.border.opacity(0.5),
            style: StrokeStyle(lineWidth: 2, dash: [6, 4])
          )

        VStack(spacing: DS.Spacing.xs) {
          Image(systemName: "plus.circle.fill")
            .font(isHero ? .largeTitle : .title2)
            .foregroundStyle(DS.Colors.accent)

          Text("Add Photo")
            .font(isHero ? DS.Typography.headline : DS.Typography.caption)
            .foregroundStyle(DS.Colors.Text.secondary)
        }
      }
      .aspectRatio(isHero ? 16 / 9 : 1, contentMode: .fill)
    }
    .buttonStyle(.plain)
  }

}

// MARK: - Previews

#Preview("Hero Photo") {
  DraftPhotoThumbnail(
    photo: DemoPhoto.allPhotos[0],
    isHero: true,
    onDelete: { }
  )
  .frame(height: 200)
  .padding()
}

#Preview("Grid Photo") {
  HStack(spacing: DS.Spacing.sm) {
    ForEach(DemoPhoto.allPhotos.prefix(3)) { photo in
      DraftPhotoThumbnail(
        photo: photo,
        isHero: false,
        onDelete: { }
      )
    }
  }
  .frame(height: 100)
  .padding()
}

#Preview("Add Photo Cell") {
  AddPhotoCell(isHero: false, onAdd: { })
    .frame(width: 100, height: 100)
    .padding()
}
