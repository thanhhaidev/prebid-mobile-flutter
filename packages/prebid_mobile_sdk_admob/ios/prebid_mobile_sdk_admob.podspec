#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint prebid_mobile_sdk_admob.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'prebid_mobile_sdk_admob'
  s.version          = '1.0.0'
  s.summary          = 'Unofficial Google AdMob mediation for the prebid_mobile_sdk Flutter plugin.'
  s.description      = <<-DESC
Optional companion to prebid_mobile_sdk that competes Prebid demand inside the
Google AdMob mediation waterfall using Prebid's AdMob adapters. Pulls in the
Google Mobile Ads SDK.
                       DESC
  s.homepage         = 'https://github.com/thanhhaidev/prebid-mobile-flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'thanhhaidev' => 'https://github.com/thanhhaidev' }
  s.source           = { :path => '.' }
  # Shared with the Swift Package (ios/prebid_mobile_sdk_admob/) so CocoaPods and
  # SPM build the same sources.
  s.source_files = 'prebid_mobile_sdk_admob/Sources/prebid_mobile_sdk_admob/**/*.swift'
  s.dependency 'Flutter'
  # Brings in PrebidMobile + Google-Mobile-Ads-SDK transitively.
  s.dependency 'PrebidMobileAdMobAdapters', '~> 3.4', '>= 3.4.1'
  s.platform = :ios, '15.0'

  # The Google Mobile Ads SDK (pulled in transitively) ships as a static
  # framework, so this pod must be a static framework too — otherwise CocoaPods
  # rejects the transitive static binary under `use_frameworks!`. Same as the
  # google_mobile_ads plugin.
  s.static_framework = true

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
