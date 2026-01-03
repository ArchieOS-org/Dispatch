//
//  PlatformUtilities.swift
//  Dispatch
//
//  Created by Dispatch AI on 2025-12-28.
//

import SwiftUI

#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

extension Image {
    init(platformImage: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}

extension PlatformImage {
    static func from(data: Data) -> PlatformImage? {
        PlatformImage(data: data)
    }
}
