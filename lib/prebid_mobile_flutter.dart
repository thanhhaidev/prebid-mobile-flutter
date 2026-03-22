/// Prebid Mobile Flutter Plugin.
///
/// A comprehensive Flutter wrapper for the Prebid Mobile SDK,
/// supporting both Android and iOS platforms.
///
/// This plugin provides the **Prebid Rendered (In-App Bidding)** integration,
/// where the Prebid SDK manages both the auction and rendering directly.
///
/// ## Supported Ad Formats
///
/// - [PrebidBannerAd] — Inline display and video banner ads (PlatformView).
/// - [PrebidInterstitialAd] — Fullscreen interstitial ads (display or video).
/// - [PrebidRewardedAd] — Fullscreen rewarded ads with typed reward callbacks.
/// - [PrebidNativeAd] — Native ads with raw asset data for custom rendering.
/// - [PrebidMultiformatAd] — Multi-format demand (banner + video + native).
/// - [PrebidInstreamVideoAd] — In-stream VAST video demand.
///
/// ## Getting Started
///
/// ```dart
/// import 'package:prebid_mobile_flutter/prebid_mobile_flutter.dart';
///
/// // 1. Initialize the SDK
/// await PrebidMobile.initializeSdk(
///   prebidServerUrl: 'https://your-pbs.com/openrtb2/auction',
///   accountId: 'your-account-id',
/// );
///
/// // 2. Use ad widgets and ad controllers
/// PrebidBannerAd(configId: 'config-id', width: 320, height: 50);
/// ```
///
/// ## Configuration & Targeting
///
/// - [PrebidMobile] — SDK initialization and global configuration.
/// - [PrebidTargeting] — Privacy (GDPR/COPPA), user keywords, app data, ORTB config.
///
/// ## Error Handling
///
/// All SDK errors are encapsulated in [PrebidException] with a typed [PrebidErrorCode].
library;

export 'src/ad_enums.dart';
export 'src/ad_listener.dart';
export 'src/native_ad.dart';
export 'src/native_ad_enums.dart';
export 'src/prebid_exception.dart';
export 'src/prebid_mobile.dart';
export 'src/targeting.dart';
export 'src/banner_ad.dart';
export 'src/interstitial_ad.dart';
export 'src/multiformat_ad.dart';
export 'src/video_ad.dart';
