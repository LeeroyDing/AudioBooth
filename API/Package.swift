// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "API",
  platforms: [.iOS(.v17), .watchOS(.v10)],
  products: [
    .library(
      name: "API",
      targets: ["API"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "3.0.0"),
    .package(url: "https://github.com/kean/Nuke.git", from: "12.0.0"),
  ],
  targets: [
    .target(
      name: "API",
      dependencies: [
        .product(name: "KeychainAccess", package: "KeychainAccess"),
        .product(name: "NukeUI", package: "Nuke"),
      ],
    )
  ]
)
