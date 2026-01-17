// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "SharedBackend",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
  ],
  products: [
    .library(
      name: "SharedBackend",
      targets: ["SharedBackend"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
  ],
  targets: [
    .target(
      name: "SharedBackend",
      dependencies: [
        .product(name: "Supabase", package: "supabase-swift"),
      ]
    ),
  ]
)
