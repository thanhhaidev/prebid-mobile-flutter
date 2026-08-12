#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint prebid_mobile_sdk_max.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'prebid_mobile_sdk_max'
  s.version          = '0.0.1'
  s.summary          = 'AppLovin MAX mediation for the Prebid Mobile Flutter SDK.'
  s.description      = <<-DESC
Optional companion to prebid_mobile_sdk that competes Prebid demand inside the
AppLovin MAX mediation waterfall using Prebid's MAX adapters. Pulls in the
AppLovin MAX SDK.
                       DESC
  s.homepage         = 'https://github.com/thanhhaidev/prebid-mobile-flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'thanhhaidev' => 'hai2571998@gmail.com' }
  s.source           = { :path => '.' }
  # Shared with the Swift Package (ios/prebid_mobile_sdk_max/) so CocoaPods and
  # SPM build the same sources.
  s.source_files = 'prebid_mobile_sdk_max/Sources/prebid_mobile_sdk_max/**/*.swift'
  s.dependency 'Flutter'
  # Brings in PrebidMobile + AppLovinSDK transitively.
  s.dependency 'PrebidMobileMAXAdapters', '~> 3.1'
  s.platform = :ios, '13.0'

  # The AppLovin MAX SDK (pulled in transitively) ships as a static framework,
  # so this pod must be a static framework too — otherwise CocoaPods rejects the
  # transitive static binary under `use_frameworks!`.
  s.static_framework = true

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
