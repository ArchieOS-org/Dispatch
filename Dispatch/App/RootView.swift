import SwiftUI

struct RootView: View {
  var body: some View {
    #if os(macOS)
    MacRootView()
    #elseif os(iOS)
    if UIDevice.current.userInterfaceIdiom == .pad {
      iPadRootView()
    } else {
      iPhoneRootView()
    }
    #endif
  }
}
