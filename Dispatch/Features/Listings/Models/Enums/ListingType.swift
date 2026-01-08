//
//  ListingType.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

enum ListingType: String, Codable, CaseIterable {
  case sale
  case lease
  case preListing = "pre_listing"
  case rental
  case other
}
