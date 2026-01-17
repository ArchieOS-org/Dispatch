// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "DesignSystem",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
  ],
  products: [
    .library(
      name: "DesignSystem",
      targets: ["DesignSystem"]
    ),
  ],
  targets: [
    .target(
      name: "DesignSystem"
      // Resources can be added later when needed:
      // resources: [.process("Resources")]
    ),
  ]
)
