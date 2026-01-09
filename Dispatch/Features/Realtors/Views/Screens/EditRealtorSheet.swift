//
//  EditRealtorSheet.swift
//  Dispatch
//
//  Created by Dispatch AI on 2025-12-28.
//  Refactored for Layout Unification (StandardScreen)
//

import PhotosUI
import SwiftData
import SwiftUI

struct EditRealtorSheet: View {

  // MARK: Lifecycle

  init(user: User? = nil) {
    userToEdit = user
    _name = State(initialValue: user?.name ?? "")
    _email = State(initialValue: user?.email ?? "")
    _avatarData = State(initialValue: user?.avatar)
  }

  // MARK: Internal

  let userToEdit: User?

  var body: some View {
    NavigationStack {
      StandardScreen(
        title: userToEdit == nil ? "New Realtor" : "Edit Realtor",
        layout: .column,
        scroll: .disabled
      ) {
        Form {
          Section {
            HStack {
              Spacer()
              VStack {
                ZStack {
                  Circle()
                    .fill(DS.Colors.Background.secondary)
                    .frame(width: 100, height: 100)

                  if let avatarData, let pImage = PlatformImage.from(data: avatarData) {
                    Image(platformImage: pImage)
                      .resizable()
                      .aspectRatio(contentMode: .fill)
                      .frame(width: 100, height: 100)
                      .clipShape(Circle())
                  } else {
                    Image(systemName: "person.crop.circle.badge.plus")
                      .font(.system(size: 40))
                      .foregroundStyle(DS.Colors.Text.secondary)
                  }
                }

                PhotosPicker(selection: $avatarItem, matching: .images) {
                  Text(avatarData == nil ? "Add Photo" : "Change Photo")
                    .font(DS.Typography.bodySecondary)
                }
              }
              Spacer()
            }
            .listRowBackground(Color.clear)
          }

          Section("Contact Info") {
            TextField("Name", text: $name)
            TextField("Email", text: $email)
              .textContentType(.emailAddress)
            #if os(iOS)
              .keyboardType(.emailAddress)
            #endif
          }
        }
        .formStyle(.grouped)
      } toolbarContent: {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { save() }
            .disabled(name.isEmpty || email.isEmpty)
        }
      }
      .onChange(of: avatarItem) { _, newItem in
        Task {
          if let data = try? await newItem?.loadTransferable(type: Data.self) {
            avatarData = data
          }
        }
      }
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject private var syncManager: SyncManager

  @State private var name = ""
  @State private var email = ""
  @State private var avatarItem: PhotosPickerItem?
  @State private var avatarData: Data?

  private func save() {
    if let user = userToEdit {
      user.name = name
      user.email = email
      user.avatar = avatarData
      user.userType = .realtor

      // Mark dirty to trigger sync
      user.markPending()
    } else {
      let newUser = User(
        name: name,
        email: email,
        avatar: avatarData,
        userType: .realtor
      )
      modelContext.insert(newUser)

      // Mark dirty to trigger sync
      newUser.markPending()
    }

    // Trigger immediate sync attempt (offline first)
    syncManager.requestSync()

    dismiss()
  }
}
