// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "prebid_mobile_sdk",
  platforms: [
    .iOS("13.0")
  ],
  products: [
    .library(name: "prebid-mobile-sdk", targets: ["prebid_mobile_sdk"])
  ],
  dependencies: [
    .package(url: "https://github.com/prebid/prebid-mobile-ios.git", from: "3.3.3")
  ],
  targets: [
    .target(
      name: "prebid_mobile_sdk",
      dependencies: [
        .product(name: "PrebidMobile", package: "prebid-mobile-ios")
      ],
      resources: [
        .process("Resources")
      ]
    )
  ]
)
