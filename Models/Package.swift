// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "Models",
  platforms: [
    .iOS(.v17),
    .watchOS(.v10),
  ],
  products: [
    .library(
      name: "Models",
      targets: ["Models"]
    )
  ],
  dependencies: [
    .package(path: "../API")
  ],
  targets: [
    .target(
      name: "Models",
      dependencies: [
        .product(name: "API", package: "API")
      ]
    )
  ]
)
