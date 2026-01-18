//
//  MacOSSettingsView.swift
//  Dispatch
//
//  macOS Settings scene content for Cmd+, preferences
//

import SwiftUI

#if os(macOS)
/// Content view for the macOS Settings scene (Cmd+,)
/// Provides basic app preferences accessible via the standard Settings menu item.
struct MacOSSettingsView: View {

  // MARK: Internal

  var body: some View {
    TabView {
      generalTab
        .tabItem {
          Label("General", systemImage: "gearshape")
        }
        .tag(SettingsTab.general)

      aboutTab
        .tabItem {
          Label("About", systemImage: "info.circle")
        }
        .tag(SettingsTab.about)
    }
    .frame(width: 450, height: 250)
  }

  // MARK: Private

  private enum SettingsTab: Int {
    case general
    case about
  }

  /// Scaled icon size for Dynamic Type support (base: 48pt)
  @ScaledMetric(relativeTo: .largeTitle)
  private var buildingIconSize: CGFloat = 48

  private var generalTab: some View {
    Form {
      Section {
        Text("Dispatch preferences")
          .font(.headline)
          .foregroundStyle(.secondary)

        Text("Additional settings are available in the app under Settings.")
          .font(.subheadline)
          .foregroundStyle(.tertiary)
      }
    }
    .formStyle(.grouped)
    .padding()
  }

  private var aboutTab: some View {
    VStack(spacing: DS.Spacing.lg) {
      Image(systemName: "building.2")
        .font(.system(size: buildingIconSize))
        .foregroundStyle(.secondary)

      Text("Dispatch")
        .font(.title)
        .fontWeight(.semibold)

      if
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
      {
        Text("Version \(version) (\(build))")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      Text("Real estate transaction management")
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }

}

#Preview {
  MacOSSettingsView()
}
#endif
