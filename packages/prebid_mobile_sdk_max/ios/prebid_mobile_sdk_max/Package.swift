// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "prebid_mobile_sdk_max",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(name: "prebid-mobile-sdk-max", targets: ["prebid_mobile_sdk_max"])
  ],
  dependencies: [
    .package(url: "https://github.com/prebid/prebid-mobile-ios.git", from: "3.4.1"),
    .package(
      url: "https://github.com/AppLovin/AppLovin-MAX-Swift-Package.git",
      from: "13.0.0"
    ),
  ],
  targets: [
    .target(
      name: "prebid_mobile_sdk_max",
      dependencies: [
        .product(name: "PrebidMobile", package: "prebid-mobile-ios"),
        .product(name: "PrebidMobileMAXAdapters", package: "prebid-mobile-ios"),
        .product(name: "AppLovinSDK", package: "AppLovin-MAX-Swift-Package"),
      ]
    )
  ]
)
