//
//  CreationSource.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

enum CreationSource: String, Codable, CaseIterable {
    case dispatch
    case slack
    case realtorApp = "realtor_app"
    case api
    case `import`
}
