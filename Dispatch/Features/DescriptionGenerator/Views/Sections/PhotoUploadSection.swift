//
//  PhotoUploadSection.swift
//  Dispatch
//
//  Photo upload and management section for the description generator.
//  Features grid display, drag-to-reorder, and hero photo designation.
//

import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

// MARK: - PhotoUploadSection

/// Section for managing uploaded photos.
/// Supports PhotosPicker on iOS and file importer on both platforms.
struct PhotoUploadSection: View {

  // MARK: Internal

  @Binding var photos: [UploadedPhoto]
  let onAdd: (UploadedPhoto) -> Void
  let onRemove: (UUID) -> Void
  let onReorder: (IndexSet, Int) -> Void
  let onSetHero: (UUID) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.md) {
      // Section header
      sectionHeader

      // Content
      if photos.isEmpty {
        emptyState
      } else {
        photoGrid
      }
    }
    .padding(DS.Spacing.cardPadding)
    .background(DS.Colors.Background.card)
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusCard))
  }

  // MARK: Private

  @State private var showingPhotoPicker = false
  @State private var showingFileImporter = false
  @State private var selectedPhotoItems: [PhotosPickerItem] = []
  @State private var draggingPhoto: UploadedPhoto?

  private let gridColumns = [
    GridItem(.adaptive(minimum: 100, maximum: 150), spacing: DS.Spacing.sm)
  ]

  @ViewBuilder
  private var sectionHeader: some View {
    HStack {
      VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
        Text("Photos")
          .font(DS.Typography.headline)
          .foregroundStyle(DS.Colors.Text.primary)

        Text("\(photos.count) photo\(photos.count == 1 ? "" : "s")")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.Text.secondary)
      }

      Spacer()

      // Upload button
      uploadButton
    }
  }

  @ViewBuilder
  private var uploadButton: some View {
    #if os(iOS)
    PhotosPicker(
      selection: $selectedPhotoItems,
      maxSelectionCount: 20,
      matching: .images,
      photoLibrary: .shared()
    ) {
      uploadButtonLabel
    }
    .onChange(of: selectedPhotoItems) { _, newItems in
      Task {
        await processSelectedPhotos(newItems)
        selectedPhotoItems = []
      }
    }
    #else
    Button(action: { showingFileImporter = true }) {
      uploadButtonLabel
    }
    .fileImporter(
      isPresented: $showingFileImporter,
      allowedContentTypes: [.image],
      allowsMultipleSelection: true
    ) { result in
      processImportedFiles(result)
    }
    #endif
  }

  @ViewBuilder
  private var uploadButtonLabel: some View {
    Label("Add Photos", systemImage: "plus.circle.fill")
      .font(DS.Typography.caption)
      .fontWeight(.semibold)
  }

  @ViewBuilder
  private var emptyState: some View {
    VStack(spacing: DS.Spacing.md) {
      Image(systemName: "photo.on.rectangle.angled")
        .font(.system(size: 36))
        .foregroundStyle(DS.Colors.Text.tertiary)

      Text("Add photos to help generate a better description")
        .font(DS.Typography.body)
        .foregroundStyle(DS.Colors.Text.secondary)
        .multilineTextAlignment(.center)

      #if os(iOS)
      PhotosPicker(
        selection: $selectedPhotoItems,
        maxSelectionCount: 20,
        matching: .images,
        photoLibrary: .shared()
      ) {
        Text("Select Photos")
          .font(DS.Typography.headline)
          .frame(maxWidth: .infinity)
          .frame(height: DS.Spacing.minTouchTarget)
      }
      .buttonStyle(.bordered)
      .onChange(of: selectedPhotoItems) { _, newItems in
        Task {
          await processSelectedPhotos(newItems)
          selectedPhotoItems = []
        }
      }
      #else
      Button(action: { showingFileImporter = true }) {
        Text("Select Photos")
          .font(DS.Typography.headline)
          .frame(maxWidth: .infinity)
          .frame(height: DS.Spacing.minTouchTarget)
      }
      .buttonStyle(.bordered)
      .fileImporter(
        isPresented: $showingFileImporter,
        allowedContentTypes: [.image],
        allowsMultipleSelection: true
      ) { result in
        processImportedFiles(result)
      }
      #endif
    }
    .padding(.vertical, DS.Spacing.xl)
    .frame(maxWidth: .infinity)
  }

  @ViewBuilder
  private var photoGrid: some View {
    LazyVGrid(columns: gridColumns, spacing: DS.Spacing.sm) {
      ForEach(photos) { photo in
        PhotoThumbnail(
          photo: photo,
          onDelete: { onRemove(photo.id) },
          onSetHero: { onSetHero(photo.id) }
        )
        .aspectRatio(1, contentMode: .fit)
        .opacity(draggingPhoto?.id == photo.id ? 0.5 : 1.0)
        .draggable(photo.id.uuidString) {
          // Drag preview
          PhotoThumbnail(
            photo: photo,
            onDelete: { },
            onSetHero: { }
          )
          .frame(width: 80, height: 80)
          .onAppear { draggingPhoto = photo }
        }
        .dropDestination(for: String.self) { items, _ in
          guard let droppedIdString = items.first,
                let droppedId = UUID(uuidString: droppedIdString),
                let sourceIndex = photos.firstIndex(where: { $0.id == droppedId }),
                let destinationIndex = photos.firstIndex(where: { $0.id == photo.id }),
                sourceIndex != destinationIndex
          else { return false }

          withAnimation(.easeInOut(duration: 0.2)) {
            onReorder(IndexSet(integer: sourceIndex), destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex)
          }
          draggingPhoto = nil
          return true
        }
      }
    }
    .onDrop(of: [.text], isTargeted: nil) { _ in
      draggingPhoto = nil
      return false
    }
  }

  // MARK: - Photo Processing

  #if os(iOS)
  @MainActor
  private func processSelectedPhotos(_ items: [PhotosPickerItem]) async {
    for item in items {
      if let data = try? await item.loadTransferable(type: Data.self) {
        let filename = "photo_\(UUID().uuidString.prefix(8)).jpg"
        let photo = UploadedPhoto(
          imageData: data,
          filename: filename,
          sortOrder: photos.count
        )
        onAdd(photo)
      }
    }
  }
  #endif

  private func processImportedFiles(_ result: Result<[URL], Error>) {
    guard case .success(let urls) = result else { return }

    for url in urls {
      guard url.startAccessingSecurityScopedResource() else { continue }
      defer { url.stopAccessingSecurityScopedResource() }

      if let data = try? Data(contentsOf: url) {
        let filename = url.lastPathComponent
        let photo = UploadedPhoto(
          imageData: data,
          filename: filename,
          sortOrder: photos.count
        )
        onAdd(photo)
      }
    }
  }
}

// MARK: - Preview

#Preview("Photo Upload - Empty") {
  PhotoUploadSection(
    photos: .constant([]),
    onAdd: { _ in },
    onRemove: { _ in },
    onReorder: { _, _ in },
    onSetHero: { _ in }
  )
  .padding()
  .background(DS.Colors.Background.grouped)
}

#Preview("Photo Upload - With Photos") {
  @Previewable @State var photos = createSamplePhotos()

  PhotoUploadSection(
    photos: $photos,
    onAdd: { photo in photos.append(photo) },
    onRemove: { id in photos.removeAll { $0.id == id } },
    onReorder: { source, dest in photos.move(fromOffsets: source, toOffset: dest) },
    onSetHero: { _ in }
  )
  .padding()
  .background(DS.Colors.Background.grouped)
}

// MARK: - Preview Helpers

private func createSamplePhotos() -> [UploadedPhoto] {
  (0..<5).map { index in
    UploadedPhoto(
      imageData: createSampleImageData(hue: Double(index) * 0.2),
      filename: "photo_\(index + 1).jpg",
      sortOrder: index
    )
  }
}

private func createSampleImageData(hue: Double) -> Data {
  #if os(iOS)
  let color = UIColor(hue: hue, saturation: 0.6, brightness: 0.8, alpha: 1.0)
  let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200))
  let image = renderer.image { ctx in
    color.setFill()
    ctx.fill(CGRect(origin: .zero, size: CGSize(width: 200, height: 200)))
  }
  return image.jpegData(compressionQuality: 0.8) ?? Data()
  #elseif os(macOS)
  let color = NSColor(hue: hue, saturation: 0.6, brightness: 0.8, alpha: 1.0)
  let image = NSImage(size: NSSize(width: 200, height: 200))
  image.lockFocus()
  color.setFill()
  NSRect(origin: .zero, size: NSSize(width: 200, height: 200)).fill()
  image.unlockFocus()
  return image.tiffRepresentation ?? Data()
  #endif
}
