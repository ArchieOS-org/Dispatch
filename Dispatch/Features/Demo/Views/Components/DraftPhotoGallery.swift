//
//  DraftPhotoGallery.swift
//  Dispatch
//
//  Photo gallery component for draft listing editor.
//  Features hero image, grid layout, drag-to-reorder, and delete controls.
//

import SwiftUI

struct DraftPhotoGallery: View {

  // MARK: Internal

  @Binding var photos: [DemoPhoto]

  let onAddPhoto: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.md) {
      header
      heroSection
      gridSection
    }
  }

  // MARK: Private

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var gridColumns: [GridItem] {
    let count = horizontalSizeClass == .regular ? 4 : 3
    return Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.sm), count: count)
  }

  private var header: some View {
    HStack {
      Text("Photos")
        .font(DS.Typography.headline)
        .foregroundStyle(DS.Colors.Text.primary)

      Text("(\(photos.count))")
        .font(DS.Typography.bodySecondary)
        .foregroundStyle(DS.Colors.Text.secondary)

      Spacer()

      Button {
        onAddPhoto()
      } label: {
        Label("Add", systemImage: "plus")
          .font(DS.Typography.body)
      }
    }
  }

  @ViewBuilder
  private var heroSection: some View {
    if let heroPhoto = photos.first {
      DraftPhotoThumbnail(
        photo: heroPhoto,
        isHero: true,
        onDelete: {
          withAnimation {
            photos.removeAll { $0.id == heroPhoto.id }
          }
        }
      )
      .frame(maxWidth: .infinity)
      .frame(height: 220)
    } else {
      AddPhotoCell(isHero: true, onAdd: onAddPhoto)
        .frame(maxWidth: .infinity)
        .frame(height: 220)
    }
  }

  private var gridSection: some View {
    LazyVGrid(columns: gridColumns, spacing: DS.Spacing.sm) {
      // Show remaining photos (skip hero)
      ForEach(Array(photos.dropFirst().enumerated()), id: \.element.id) { offset, photo in
        DraftPhotoThumbnail(
          photo: photo,
          isHero: false,
          onDelete: {
            withAnimation {
              // Offset + 1 because we dropped the first
              let actualIndex = offset + 1
              if photos.indices.contains(actualIndex) {
                photos.remove(at: actualIndex)
              }
            }
          }
        )
        .frame(minHeight: 80)
      }
      .onMove { source, destination in
        // Adjust indices since we're showing dropFirst()
        let adjustedSource = IndexSet(source.map { $0 + 1 })
        let adjustedDestination = destination + 1
        photos.move(fromOffsets: adjustedSource, toOffset: adjustedDestination)
      }

      // Add photo cell at the end
      AddPhotoCell(isHero: false, onAdd: onAddPhoto)
        .frame(minHeight: 80)
    }
  }

}

// MARK: - Previews

#Preview("Photo Gallery - Full") {
  @Previewable @State var photos = DemoPhoto.allPhotos

  ScrollView {
    DraftPhotoGallery(
      photos: $photos,
      onAddPhoto: { }
    )
    .padding()
  }
}

#Preview("Photo Gallery - Few Photos") {
  @Previewable @State var photos = Array(DemoPhoto.allPhotos.prefix(5))

  ScrollView {
    DraftPhotoGallery(
      photos: $photos,
      onAddPhoto: { }
    )
    .padding()
  }
}

#Preview("Photo Gallery - Empty") {
  @Previewable @State var photos: [DemoPhoto] = []

  ScrollView {
    DraftPhotoGallery(
      photos: $photos,
      onAddPhoto: { }
    )
    .padding()
  }
}
