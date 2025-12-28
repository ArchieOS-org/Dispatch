//
//  EditRealtorSheet.swift
//  Dispatch
//
//  Created by Dispatch AI on 2025-12-28.
//

import SwiftUI
import SwiftData
import PhotosUI

struct EditRealtorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let userToEdit: User?
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarData: Data?
    
    init(user: User? = nil) {
        self.userToEdit = user
        _name = State(initialValue: user?.name ?? "")
        _email = State(initialValue: user?.email ?? "")
        _avatarData = State(initialValue: user?.avatar)
    }
    
    var body: some View {
        NavigationStack {
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
            .navigationTitle(userToEdit == nil ? "New Realtor" : "Edit Realtor")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
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
    
    private func save() {
        if let user = userToEdit {
            user.name = name
            user.email = email
            user.avatar = avatarData
            // Ensure type is realtor if editing existing user who might have been something else? 
            // Or just trust the entry point. For now, we enforce it.
            user.userType = .realtor 
        } else {
            let newUser = User(
                name: name,
                email: email,
                userType: .realtor,
                avatar: avatarData
            )
            modelContext.insert(newUser)
        }
        
        // TODO: Handle Supabase Upload Logic if we decide to store URL remotely
        // For now, storing Data locally in SwiftData which syncs via CloudKit/Supabase automatically if configured.
        
        dismiss()
    }
}
