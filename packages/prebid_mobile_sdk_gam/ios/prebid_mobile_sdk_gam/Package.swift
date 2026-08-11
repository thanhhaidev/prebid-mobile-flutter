// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "prebid_mobile_sdk_gam",
  platforms: [
    .iOS("13.0")
  ],
  products: [
    .library(name: "prebid-mobile-sdk-gam", targets: ["prebid_mobile_sdk_gam"])
  ],
  dependencies: [
    .package(url: "https://github.com/prebid/prebid-mobile-ios.git", from: "3.3.3"),
    .package(
      url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
      from: "13.0.0"
    ),
  ],
  targets: [
    .target(
      name: "prebid_mobile_sdk_gam",
      dependencies: [
        .product(name: "PrebidMobile", package: "prebid-mobile-ios"),
        .product(name: "PrebidMobileGAMEventHandlers", package: "prebid-mobile-ios"),
        .product(
          name: "GoogleMobileAds",
          package: "swift-package-manager-google-mobile-ads"
        ),
      ]
    )
  ]
)
