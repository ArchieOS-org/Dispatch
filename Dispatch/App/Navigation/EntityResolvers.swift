//
//  EntityResolvers.swift
//  Dispatch
//
//  Resolver views that fetch entities by ID for navigation.
//  These decouple navigation state from SwiftData model lifecycle.
//

import SwiftData
import SwiftUI

// MARK: - RealtorResolver

/// Resolves a realtor by UUID and displays their profile.
/// Shows ContentUnavailableView if the realtor no longer exists.
struct RealtorResolver: View {
  let id: UUID

  @Query private var users: [User]

  init(id: UUID) {
    self.id = id
    _users = Query(filter: #Predicate<User> { $0.id == id })
  }

  var body: some View {
    if let user = users.first {
      RealtorProfileView(user: user)
    } else {
      ContentUnavailableView(
        "Realtor Not Found",
        systemImage: "person.slash",
        description: Text("This realtor may have been removed.")
      )
    }
  }
}

// MARK: - ListingResolver

/// Resolves a listing by UUID and displays its detail view.
/// Shows ContentUnavailableView if the listing no longer exists.
struct ListingResolver: View {
  let id: UUID

  @Query private var listings: [Listing]
  @EnvironmentObject private var actions: WorkItemActions

  init(id: UUID) {
    self.id = id
    _listings = Query(filter: #Predicate<Listing> { $0.id == id })
  }

  var body: some View {
    if let listing = listings.first {
      ListingDetailView(listing: listing, userLookup: actions.userLookup)
    } else {
      ContentUnavailableView(
        "Listing Not Found",
        systemImage: "doc.slash",
        description: Text("This listing may have been removed.")
      )
    }
  }
}

// MARK: - PropertyResolver

/// Resolves a property by UUID and displays its detail view.
/// Shows ContentUnavailableView if the property no longer exists.
struct PropertyResolver: View {
  let id: UUID

  @Query private var properties: [Property]
  @EnvironmentObject private var actions: WorkItemActions

  init(id: UUID) {
    self.id = id
    _properties = Query(filter: #Predicate<Property> { $0.id == id })
  }

  var body: some View {
    if let property = properties.first {
      PropertyDetailView(property: property, userLookup: actions.userLookup)
    } else {
      ContentUnavailableView(
        "Property Not Found",
        systemImage: "house.slash",
        description: Text("This property may have been removed.")
      )
    }
  }
}

// MARK: - ListingTypeResolver

/// Resolves a listing type definition by UUID and displays its detail view.
/// Shows ContentUnavailableView if the listing type no longer exists.
struct ListingTypeResolver: View {
  let id: UUID

  @Query private var types: [ListingTypeDefinition]

  init(id: UUID) {
    self.id = id
    _types = Query(filter: #Predicate<ListingTypeDefinition> { $0.id == id })
  }

  var body: some View {
    if let listingType = types.first {
      ListingTypeDetailView(listingType: listingType)
    } else {
      ContentUnavailableView(
        "Listing Type Not Found",
        systemImage: "tag.slash",
        description: Text("This listing type may have been removed.")
      )
    }
  }
}
