//
//  UploadedPhoto.swift
//  Dispatch
//
//  Photo model for the description generator.
//  Supports drag-to-reorder and hero photo designation.
//

import SwiftUI

// MARK: - UploadedPhoto

/// A photo uploaded for AI analysis and listing description generation.
/// Photos are stored in memory only (PHASE 3: Persist to Supabase Storage).
struct UploadedPhoto: Identifiable, Equatable {

  // MARK: - Properties

  /// Unique identifier for the photo
  let id: UUID

  /// Raw image data for persistence and display
  let imageData: Data

  /// Original filename of the uploaded photo
  let filename: String

  /// Sort order for drag-to-reorder (0 = hero photo)
  var sortOrder: Int

  // MARK: - Computed Properties

  /// Whether this is the hero (primary) photo
  var isHero: Bool { sortOrder == 0 }

  /// Computed image for display
  /// Returns nil if image data cannot be decoded
  var image: Image? {
    #if os(iOS)
    if let uiImage = UIImage(data: imageData) {
      return Image(uiImage: uiImage)
    }
    #elseif os(macOS)
    if let nsImage = NSImage(data: imageData) {
      return Image(nsImage: nsImage)
    }
    #endif
    return nil
  }

  // MARK: - Initialization

  init(
    id: UUID = UUID(),
    imageData: Data,
    filename: String,
    sortOrder: Int = 0
  ) {
    self.id = id
    self.imageData = imageData
    self.filename = filename
    self.sortOrder = sortOrder
  }

  // MARK: - Equatable

  static func == (lhs: UploadedPhoto, rhs: UploadedPhoto) -> Bool {
    lhs.id == rhs.id &&
    lhs.imageData == rhs.imageData &&
    lhs.filename == rhs.filename &&
    lhs.sortOrder == rhs.sortOrder
  }
}
