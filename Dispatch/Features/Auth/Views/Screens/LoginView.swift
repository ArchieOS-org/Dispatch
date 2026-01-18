//
//  LoginView.swift
//  Dispatch
//
//  Created by DispatchAI on 2025-12-28.
//

import SwiftUI

// MARK: - LoginView

struct LoginView: View {

  // MARK: Internal

  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    ZStack {
      // Minimalist Background
      DS.Colors.Background.primary
        .ignoresSafeArea()

      VStack(spacing: DS.Spacing.lg) {
        Spacer()

        // MARK: - Brand Identity
        VStack(spacing: DS.Spacing.md) {
          // Logo (Placeholder for now, using System Image gracefully)
          Image(systemName: "command") // Abstract symbol commonly associated with pro workflows
            .font(.system(size: logoIconSize, weight: .light))
            .foregroundStyle(DS.Colors.Text.primary)
            .padding(.bottom, DS.Spacing.sm)

          Text("Dispatch")
            .font(.system(size: brandNameSize, weight: .semibold, design: .default))
            .tracking(-1.0) // Tight tracking for premium feel
            .foregroundStyle(DS.Colors.Text.primary)

          Text("The operating system for your operations.")
            .font(DS.Typography.body)
            .foregroundStyle(DS.Colors.Text.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, DS.Spacing.sectionSpacing)
        }
        .padding(.bottom, 60) // Visual breathing room

        // MARK: - Actions
        VStack(spacing: DS.Spacing.md) {
          if authManager.isLoading {
            ProgressView()
              .controlSize(.regular)
          } else {
            GoogleSignInButton {
              Task {
                await authManager.signInWithGoogle()
              }
            }
          }

          if let error = authManager.error {
            Text(error.localizedDescription)
              .font(DS.Typography.caption)
              .foregroundStyle(DS.Colors.destructive)
              .multilineTextAlignment(.center)
              .padding(.top, DS.Spacing.sm)
              .transition(.opacity)
          }
        }
        .padding(.horizontal, DS.Spacing.sectionSpacing)
        // Constrain width for iPad/Mac elegance
        .frame(maxWidth: 400)

        Spacer()

        // Footer
        Text("Version 1.0")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.Text.tertiary)
          .padding(.bottom, DS.Spacing.lg)
      }
      .padding(DS.Spacing.lg)
    }
    .tint(DS.Colors.accent)
  }

  // MARK: Private

  /// Scaled icon size for Dynamic Type support (base: 64pt)
  @ScaledMetric(relativeTo: .largeTitle)
  private var logoIconSize: CGFloat = 64

  /// Scaled brand name font size for Dynamic Type support (base: 40pt)
  @ScaledMetric(relativeTo: .largeTitle)
  private var brandNameSize: CGFloat = 40

  @EnvironmentObject private var authManager: AuthManager

}

// MARK: - GoogleSignInButton

private struct GoogleSignInButton: View {
  @Environment(\.colorScheme) var colorScheme

  /// Scaled icon size for Dynamic Type support (base: 20pt)
  @ScaledMetric(relativeTo: .body)
  private var iconSize: CGFloat = 20

  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        // Approximate the Google 'G' using text/shapes if asset missing
        // In production, use the official SVG asset.
        Image(systemName: "g.circle.fill") // Fallback
          .symbolRenderingMode(.multicolor)
          .font(.system(size: iconSize))

        Text("Continue with Google")
          .font(DS.Typography.body)
          .fontWeight(.medium)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 50)
      .background(
        RoundedRectangle(cornerRadius: DS.Spacing.radiusMedium, style: .continuous)
          .fill(colorScheme == .dark ? Color.white : Color.black)
      )
      .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
      .overlay(
        RoundedRectangle(cornerRadius: DS.Spacing.radiusMedium, style: .continuous)
          .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
      )
      .dsShadow(DS.Shadows.small)
    }
    .buttonStyle(PressableButtonStyle())

    Text("No account needed. One will be created automatically.")
      .font(DS.Typography.caption)
      .foregroundStyle(DS.Colors.Text.tertiary)
      .padding(.top, 12)
  }
}

// MARK: - PressableButtonStyle

private struct PressableButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
      .animation(.snappy(duration: 0.2), value: configuration.isPressed)
      .opacity(configuration.isPressed ? 0.9 : 1)
  }
}
