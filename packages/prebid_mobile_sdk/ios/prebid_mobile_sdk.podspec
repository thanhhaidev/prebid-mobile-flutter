#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint prebid_mobile_sdk.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'prebid_mobile_sdk'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin for Prebid Mobile SDK.'
  s.description      = <<-DESC
A Flutter plugin that wraps the Prebid Mobile SDK for Android and iOS,
providing banner, interstitial, and rewarded ad formats.
                       DESC
  s.homepage         = 'https://github.com/thanhhaidev/prebid-mobile-flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'thanhhaidev' => 'hai2571998@gmail.com' }
  s.source           = { :path => '.' }
  # Shared with the Swift Package (ios/prebid_mobile_sdk/) so CocoaPods and SPM
  # build the same sources.
  s.source_files = 'prebid_mobile_sdk/Sources/prebid_mobile_sdk/**/*.swift'
  s.resource_bundles = {
    'prebid_mobile_sdk_privacy' => ['prebid_mobile_sdk/Sources/prebid_mobile_sdk/Resources/PrivacyInfo.xcprivacy']
  }
  s.dependency 'Flutter'
  s.dependency 'PrebidMobile', '~> 3.1'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
