#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint prebid_mobile_sdk_gam.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'prebid_mobile_sdk_gam'
  s.version          = '0.0.1'
  s.summary          = 'Google Ad Manager rendering for the Prebid Mobile Flutter SDK.'
  s.description      = <<-DESC
Optional companion to prebid_mobile_sdk that renders Prebid demand through
Google Ad Manager using Prebid's GAM event handlers. Pulls in the Google
Mobile Ads SDK.
                       DESC
  s.homepage         = 'https://github.com/thanhhaidev/prebid-mobile-flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'thanhhaidev' => 'hai2571998@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  # Brings in PrebidMobile + Google-Mobile-Ads-SDK transitively.
  s.dependency 'PrebidMobileGAMEventHandlers', '~> 3.1'
  s.platform = :ios, '13.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
