//
//  FormSheetContainer.swift
//  Dispatch
//
//  Platform-adaptive form container for entity creation sheets.
//  Provides consistent layout across iOS (Form) and macOS (VStack + LabeledContent).
//

import SwiftUI

// MARK: - FormSheetContainer

/// A platform-adaptive container for form sheets (creation/editing).
///
/// **iOS/iPadOS**: Uses SwiftUI `Form` with grouped style
/// **macOS**: Uses `VStack` with `LabeledContent` for proper alignment
///
/// Usage:
/// ```swift
/// FormSheetContainer {
///   FormSheetRow("Address") {
///     TextField("Property address", text: $address)
///   }
///   FormSheetRow("City") {
///     TextField("City", text: $city)
///   }
/// }
/// ```
///
/// For sections with headers (iOS only - macOS shows inline):
/// ```swift
/// FormSheetContainer {
///   FormSheetSection("Location") {
///     FormSheetRow("Address") { TextField("", text: $address) }
///     FormSheetRow("City") { TextField("", text: $city) }
///   }
/// }
/// ```
struct FormSheetContainer<Content: View>: View {

  // MARK: Lifecycle

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  // MARK: Internal

  var body: some View {
    #if os(macOS)
    macOSLayout
    #else
    iOSLayout
    #endif
  }

  // MARK: Private

  private let content: Content

  #if os(macOS)
  private var macOSLayout: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DS.Spacing.lg) {
        content
      }
      .padding(DS.Spacing.xl)
    }
  }
  #endif

  #if !os(macOS)
  private var iOSLayout: some View {
    Form {
      content
    }
  }
  #endif
}

// MARK: - FormSheetRow

/// A single labeled row within a FormSheetContainer.
///
/// On iOS: Renders as a simple row (label handled by Section or implicit)
/// On macOS: Renders as LabeledContent with proper label alignment
///
/// Usage:
/// ```swift
/// FormSheetRow("Address") {
///   TextField("Property address", text: $address)
/// }
/// ```
struct FormSheetRow<Content: View>: View {

  // MARK: Lifecycle

  init(_ label: LocalizedStringKey, @ViewBuilder content: () -> Content) {
    self.label = label
    self.content = content()
  }

  init(_ label: String, @ViewBuilder content: () -> Content) {
    self.label = LocalizedStringKey(label)
    self.content = content()
  }

  // MARK: Internal

  var body: some View {
    #if os(macOS)
    LabeledContent(label) {
      content
        .textFieldStyle(.roundedBorder)
        .labelsHidden()
    }
    #else
    content
    #endif
  }

  // MARK: Private

  private let label: LocalizedStringKey
  private let content: Content
}

// MARK: - FormSheetSection

/// A section wrapper for FormSheetContainer.
///
/// On iOS: Creates a Form Section with header
/// On macOS: Creates a VStack with section title
///
/// Usage:
/// ```swift
/// FormSheetSection("Location") {
///   FormSheetRow("City") { TextField("City", text: $city) }
///   FormSheetRow("Province") { TextField("Province", text: $province) }
/// }
/// ```
struct FormSheetSection<Content: View>: View {

  // MARK: Lifecycle

  init(_ title: LocalizedStringKey, footer: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
    self.title = title
    self.footer = footer
    self.content = content()
  }

  init(_ title: String, footer: String? = nil, @ViewBuilder content: () -> Content) {
    self.title = LocalizedStringKey(title)
    self.footer = footer.map { LocalizedStringKey($0) }
    self.content = content()
  }

  // MARK: Internal

  var body: some View {
    #if os(macOS)
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      Text(title)
        .font(DS.Typography.headline)
        .foregroundStyle(DS.Colors.Text.primary)
      content
      if let footer {
        Text(footer)
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.Text.secondary)
      }
    }
    #else
    if let footer {
      Section {
        content
      } header: {
        Text(title)
      } footer: {
        Text(footer)
      }
    } else {
      Section(title) {
        content
      }
    }
    #endif
  }

  // MARK: Private

  private let title: LocalizedStringKey
  private let footer: LocalizedStringKey?
  private let content: Content
}

// MARK: - FormSheetPickerRow

/// A picker row with consistent styling across platforms.
///
/// On macOS: Uses menu picker style with proper spacing
/// On iOS: Uses default Form picker behavior
struct FormSheetPickerRow<SelectionValue: Hashable, Content: View>: View {

  // MARK: Lifecycle

  init(
    _ label: LocalizedStringKey,
    selection: Binding<SelectionValue>,
    @ViewBuilder content: () -> Content
  ) {
    self.label = label
    _selection = selection
    self.content = content()
  }

  init(
    _ label: String,
    selection: Binding<SelectionValue>,
    @ViewBuilder content: () -> Content
  ) {
    self.label = LocalizedStringKey(label)
    _selection = selection
    self.content = content()
  }

  // MARK: Internal

  var body: some View {
    #if os(macOS)
    LabeledContent(label) {
      Picker(label, selection: $selection) {
        content
      }
      .pickerStyle(.menu)
      .labelsHidden()
    }
    #else
    Picker(label, selection: $selection) {
      content
    }
    .pickerStyle(.menu)
    #endif
  }

  // MARK: Private

  private let label: LocalizedStringKey
  @Binding private var selection: SelectionValue
  private let content: Content
}

// MARK: - FormSheetTextRow

/// A text field row with validation support.
///
/// Shows error styling and footer when validation fails.
struct FormSheetTextRow: View {

  // MARK: Lifecycle

  init(
    _ label: LocalizedStringKey,
    placeholder: LocalizedStringKey,
    text: Binding<String>,
    isRequired: Bool = false,
    errorMessage: LocalizedStringKey? = nil,
    axis: Axis = .horizontal,
    lineLimit: ClosedRange<Int>? = nil
  ) {
    self.label = label
    self.placeholder = placeholder
    _text = text
    self.isRequired = isRequired
    self.errorMessage = errorMessage
    self.axis = axis
    self.lineLimit = lineLimit
  }

  init(
    _ label: String,
    placeholder: String,
    text: Binding<String>,
    isRequired: Bool = false,
    errorMessage: String? = nil,
    axis: Axis = .horizontal,
    lineLimit: ClosedRange<Int>? = nil
  ) {
    self.label = LocalizedStringKey(label)
    self.placeholder = LocalizedStringKey(placeholder)
    _text = text
    self.isRequired = isRequired
    self.errorMessage = errorMessage.map { LocalizedStringKey($0) }
    self.axis = axis
    self.lineLimit = lineLimit
  }

  // MARK: Internal

  var body: some View {
    #if os(macOS)
    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
      LabeledContent(label) {
        textField
          .textFieldStyle(.roundedBorder)
          .labelsHidden()
      }
      if showError {
        Text(errorMessage ?? "Required")
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.destructive)
      }
    }
    #else
    if showError {
      Section {
        textField
      } header: {
        Text(label)
      } footer: {
        Text(errorMessage ?? "Required")
          .foregroundColor(DS.Colors.destructive)
      }
    } else {
      Section(label) {
        textField
      }
    }
    #endif
  }

  // MARK: Private

  private let label: LocalizedStringKey
  private let placeholder: LocalizedStringKey
  @Binding private var text: String
  private let isRequired: Bool
  private let errorMessage: LocalizedStringKey?
  private let axis: Axis
  private let lineLimit: ClosedRange<Int>?

  private var showError: Bool {
    isRequired && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  @ViewBuilder
  private var textField: some View {
    if axis == .vertical, let lineLimit {
      TextField(placeholder, text: $text, axis: .vertical)
        .lineLimit(lineLimit)
    } else {
      TextField(placeholder, text: $text)
    }
  }
}

// MARK: - FormSheetNavigationRow

/// A navigation-style row that shows a value and chevron, triggering an action on tap.
///
/// Used for drill-down selections (e.g., picking from a list sheet).
struct FormSheetNavigationRow<Value: View>: View {

  // MARK: Lifecycle

  init(
    _ label: LocalizedStringKey,
    action: @escaping () -> Void,
    @ViewBuilder value: () -> Value
  ) {
    self.label = label
    self.action = action
    self.value = value()
  }

  init(
    _ label: String,
    action: @escaping () -> Void,
    @ViewBuilder value: () -> Value
  ) {
    self.label = LocalizedStringKey(label)
    self.action = action
    self.value = value()
  }

  // MARK: Internal

  var body: some View {
    Button(action: action) {
      HStack {
        #if os(macOS)
        Text(label)
          .foregroundColor(DS.Colors.Text.primary)
        Spacer()
        #endif
        value
        #if !os(macOS)
        Spacer()
        #endif
        Image(systemName: DS.Icons.Navigation.forward)
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.Text.tertiary)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .frame(minHeight: DS.Spacing.minTouchTarget)
  }

  // MARK: Private

  private let label: LocalizedStringKey
  private let action: () -> Void
  private let value: Value
}

// MARK: - Preview

#Preview("FormSheetContainer - iOS Style") {
  NavigationStack {
    FormSheetContainer {
      FormSheetSection("Address") {
        FormSheetTextRow(
          "Street",
          placeholder: "Property address",
          text: .constant("123 Main St"),
          isRequired: true
        )
      }

      FormSheetSection("Location") {
        FormSheetRow("City") {
          TextField("City", text: .constant("Toronto"))
        }
        FormSheetRow("Province") {
          TextField("Province", text: .constant("ON"))
        }
      }

      FormSheetSection("Notes", footer: "Optional additional information") {
        FormSheetTextRow(
          "Notes",
          placeholder: "Add notes...",
          text: .constant(""),
          axis: .vertical,
          lineLimit: 1 ... 5
        )
      }
    }
    .navigationTitle("New Listing")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
  }
}
