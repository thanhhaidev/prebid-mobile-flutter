import '../models/demo_ad_format.dart';
import '../models/demo_integration.dart';
import '../models/test_case.dart';

/// Registry of demo ad units, mirroring the Prebid `PrebidInternalTestApp`
/// (`DemoItemProvider.kt`). Labels, configIds and ad-unit ids are kept verbatim
/// so the list matches the reference app one-to-one.
///
/// Grouped by integration (In-App / GAM Rendering / GAM Original / AdMob / MAX)
/// then format. `storedResponse` is left null so every case runs a live auction
/// against the community server at `prebid-server-test-j.prebid.org`.
///
/// Ad-server ad units use the reference app's public Prebid demo units.
class TestCaseRegistry {
  // GAM ad unit path prefix (Prebid's public demo network).
  static const _gam = '/21808260008/';
  static const _gamRewarded = '${_gam}prebid_oxb_rewarded_video';
  static const _gamNative = '${_gam}prebid_oxb_native';

  // AdMob demo ad units (Prebid's public account).
  static const _admobBanner = 'ca-app-pub-1875909575462531/3793078260';
  static const _admobInterstitial = 'ca-app-pub-1875909575462531/6393291067';
  static const _admobRewarded = 'ca-app-pub-1875909575462531/1908212572';
  static const _admobNative = 'ca-app-pub-1875909575462531/9720985924';

  // AppLovin MAX demo ad units (Prebid's public account).
  static const _maxBanner = '2712409601eb0b64';
  static const _maxMrec = '0b831dee5ef00774';
  static const _maxInterstitial = '3c61bf5180526594';
  static const _maxRewarded = '4adc922f52679355';
  static const _maxNative = 'fa4a9d137e6f3dff';

  static const allCases = [
    // =========================================================================
    // IN-APP (Prebid Rendering) — Banner
    // =========================================================================
    TestCase(
      title: 'Banner 320x50 (In-App)',
      configId: 'prebid-demo-banner-320-50',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'Banner 320x50 [noBids] (In-App)',
      configId: 'prebid-demo-no-bids',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'Banner 320x50 (In-App) [Incorrect VAST]',
      configId: 'prebid-demo-banner-incorrect-vast',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'Banner 320x50 (In-App) [DeepLink+]',
      configId: 'prebid-demo-banner-deeplink',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'Banner 300x250 (In-App)',
      configId: 'prebid-demo-banner-300-250',
      format: DemoAdFormat.displayBanner,
      width: 300,
      height: 250,
    ),
    TestCase(
      title: 'Banner 728x90 (In-App)',
      configId: 'prebid-demo-banner-728-90',
      format: DemoAdFormat.displayBanner,
      width: 728,
      height: 90,
    ),
    TestCase(
      title: 'Banner Multisize (In-App)',
      configId: 'prebid-demo-banner-multisize',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),

    // =========================================================================
    // IN-APP — MRAID (rendered as banners)
    // =========================================================================
    TestCase(
      title: 'MRAID 2.0: Expand - 1 Part (In-App)',
      configId: 'prebid-demo-mraid-expand-1-part',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'MRAID 2.0: Expand - 2 Part (In-App)',
      configId: 'prebid-demo-mraid-expand-2-part',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'MRAID 2.0: Resize (In-App)',
      configId: 'prebid-demo-mraid-resize',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'MRAID 2.0: Resize With Errors (In-App)',
      configId: 'prebid-demo-mraid-resize-with-errors',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'MRAID 2.0: Fullscreen (In-App)',
      configId: 'prebid-demo-mraid-fullscreen',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'MRAID 3.0: Viewability Compliance (In-App)',
      configId: 'prebid-demo-mraid-viewability-compliance',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'MRAID 3.0: Resize Negative Test (In-App)',
      configId: 'prebid-demo-mraid-resize-negative-test',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'MRAID 3.0: Load And Events (In-App)',
      configId: 'prebid-demo-mraid-load-and-events',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'MRAID OX: Test Properties 3.0 (In-App)',
      configId: 'prebid-demo-mraid-test-properties-3',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'MRAID OX: Test Methods 3.0 (In-App)',
      configId: 'prebid-demo-mraid-test-methods-3',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'MRAID OX: Resize (Expandable) (In-App)',
      configId: 'prebid-demo-mraid-resize-expandable',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),

    // =========================================================================
    // IN-APP — Display Interstitial
    // =========================================================================
    TestCase(
      title: 'Display Interstitial 320x480 (In-App)',
      configId: 'prebid-demo-display-interstitial-320-480',
      format: DemoAdFormat.displayInterstitial,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Display Interstitial 320x480 [noBids] (In-App)',
      configId: 'prebid-demo-no-bids',
      format: DemoAdFormat.displayInterstitial,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'MRAID 2.0: Video Interstitial (In-App)',
      configId: 'prebid-demo-mraid-video-interstitial',
      format: DemoAdFormat.videoInterstitial,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Interstitial 320x480 with MRAID End Card (In-App)',
      configId: 'prebid-demo-video-interstitial-mraid-end-card',
      format: DemoAdFormat.videoInterstitial,
      width: 320,
      height: 480,
    ),

    // =========================================================================
    // IN-APP — Video Interstitial
    // =========================================================================
    TestCase(
      title: 'Video Interstitial 320x480 (In-App)',
      configId: 'prebid-demo-video-interstitial-320-480',
      format: DemoAdFormat.videoInterstitial,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Interstitial 320x480 (In-App) [noBids]',
      configId: 'prebid-demo-no-bids',
      format: DemoAdFormat.videoInterstitial,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Interstitial 320x480 SkipOffset (In-App)',
      configId: 'prebid-demo-video-interstitial-320-480-skip-offset',
      format: DemoAdFormat.videoInterstitial,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Interstitial 320x480 Deeplink+ (In-App)',
      configId: 'prebid-demo-video-interstitial-320-480-deeplink',
      format: DemoAdFormat.videoInterstitial,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Interstitial 320x480 With End Card (In-App)',
      configId: 'prebid-demo-video-interstitial-320-480-with-end-card',
      format: DemoAdFormat.videoInterstitial,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Interstitial 320x480 With Ad Configuration (In-App)',
      configId: 'prebid-demo-video-interstitial-320-480-with-ad-configuration',
      format: DemoAdFormat.videoInterstitial,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Interstitial Vertical With End Card (In-App)',
      configId: 'prebid-demo-video-interstitial-vertical-with-end-card',
      format: DemoAdFormat.videoInterstitial,
      width: 320,
      height: 480,
    ),

    // =========================================================================
    // IN-APP — Video Outstream (banner-embedded video)
    // =========================================================================
    TestCase(
      title: 'Video Outstream (In-App)',
      configId: 'prebid-demo-video-outstream',
      format: DemoAdFormat.videoBanner,
      width: 300,
      height: 250,
    ),
    TestCase(
      title: 'Video Outstream [noBids] (In-App)',
      configId: 'prebid-demo-no-bids',
      format: DemoAdFormat.videoBanner,
      width: 300,
      height: 250,
    ),
    TestCase(
      title: 'Video Outstream with End Card (In-App)',
      configId: 'prebid-demo-video-outstream-with-end-card',
      format: DemoAdFormat.videoBanner,
      width: 300,
      height: 250,
    ),

    // =========================================================================
    // IN-APP — Rewarded
    // =========================================================================
    TestCase(
      title: 'Display Rewarded 320x480 (Default) (In-App)',
      configId: 'prebid-demo-banner-rewarded-default',
      format: DemoAdFormat.displayRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Display Rewarded 320x480 (Time + autoclose) (In-App)',
      configId: 'prebid-demo-banner-rewarded-time',
      format: DemoAdFormat.displayRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Display Rewarded 320x480 (Event + close) (In-App)',
      configId: 'prebid-demo-banner-rewarded-event',
      format: DemoAdFormat.displayRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Rewarded 320x480 (Default) (In-App)',
      configId: 'prebid-demo-video-rewarded-default',
      format: DemoAdFormat.videoRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Rewarded 320x480 (In-App)',
      configId: 'prebid-demo-video-rewarded-320-480',
      format: DemoAdFormat.videoRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Rewarded 320x480 without End Card (In-App)',
      configId: 'prebid-demo-video-rewarded-320-480-without-end-card',
      format: DemoAdFormat.videoRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Rewarded 320x480 (In-App) [noBids]',
      configId: 'prebid-demo-no-bids',
      format: DemoAdFormat.videoRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Rewarded 320x480 (Time + autoclose) (In-App)',
      configId: 'prebid-demo-video-rewarded-time',
      format: DemoAdFormat.videoRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Rewarded 320x480 (Playback Event) (In-App)',
      configId: 'prebid-demo-video-rewarded-playbackevent',
      format: DemoAdFormat.videoRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Rewarded Endcard 320x480 (Default) (In-App)',
      configId: 'prebid-demo-video-rewarded-endcard-default',
      format: DemoAdFormat.videoRewarded,
      width: 320,
      height: 480,
    ),

    // =========================================================================
    // IN-APP — Native
    // =========================================================================
    TestCase(
      title: 'Native Ad (In-App)',
      configId: 'prebid-demo-banner-native-styles',
      format: DemoAdFormat.native,
    ),
    TestCase(
      title: 'Native Ad Links (In-App)',
      configId: 'prebid-demo-native-links',
      format: DemoAdFormat.native,
    ),

    // =========================================================================
    // IN-APP — Multiformat
    // =========================================================================
    TestCase(
      title: 'Multiformat Interstitial 320x480 (In-App)',
      configId: 'prebid-demo-banner-320-50',
      format: DemoAdFormat.multiformat,
      width: 320,
      height: 480,
    ),

    // =========================================================================
    // GAM RENDERING — Banner
    // =========================================================================
    TestCase(
      title: 'Banner 320x50 (GAM) [OK, AppEvent]',
      configId: 'prebid-demo-banner-320-50',
      format: DemoAdFormat.displayBanner,
      integration: DemoIntegration.gam,
      adUnitId: '${_gam}prebid_oxb_320x50_banner',
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'Banner 320x50 (GAM) [OK, GAM Ad]',
      configId: 'prebid-demo-banner-320-50',
      format: DemoAdFormat.displayBanner,
      integration: DemoIntegration.gam,
      adUnitId: '${_gam}prebid_oxb_320x50_banner_static',
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'Banner 320x50 (GAM) [OK, Random]',
      configId: 'prebid-demo-banner-320-50',
      format: DemoAdFormat.displayBanner,
      integration: DemoIntegration.gam,
      adUnitId: '${_gam}prebid_oxb_320x50_banner_random',
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'Banner 300x250 (GAM)',
      configId: 'prebid-demo-banner-300-250',
      format: DemoAdFormat.displayBanner,
      integration: DemoIntegration.gam,
      adUnitId: '${_gam}prebid_oxb_300x250_banner',
      width: 300,
      height: 250,
    ),
    TestCase(
      title: 'Banner 728x90 (GAM)',
      configId: 'prebid-demo-banner-728-90',
      format: DemoAdFormat.displayBanner,
      integration: DemoIntegration.gam,
      adUnitId: '${_gam}prebid_oxb_728x90_banner',
      width: 728,
      height: 90,
    ),
    TestCase(
      title: 'Banner Multisize (GAM)',
      configId: 'prebid-demo-banner-multisize',
      format: DemoAdFormat.displayBanner,
      integration: DemoIntegration.gam,
      adUnitId: '${_gam}prebid_oxb_multisize_banner',
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'MRAID 2.0: Expand - 1 Part (GAM)',
      configId: 'prebid-demo-mraid-expand-1-part',
      format: DemoAdFormat.displayBanner,
      integration: DemoIntegration.gam,
      adUnitId: '${_gam}prebid_oxb_320x50_banner',
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'MRAID 2.0: Resize (GAM)',
      configId: 'prebid-demo-mraid-resize',
      format: DemoAdFormat.displayBanner,
      integration: DemoIntegration.gam,
      adUnitId: '${_gam}prebid_oxb_320x50_banner',
      width: 320,
      height: 50,
    ),

    // =========================================================================
    // GAM RENDERING — Interstitial
    // =========================================================================
    TestCase(
      title: 'Display Interstitial 320x480 (GAM) [OK, AppEvent]',
      configId: 'prebid-demo-display-interstitial-320-480',
      format: DemoAdFormat.displayInterstitial,
      integration: DemoIntegration.gam,
      adUnitId: '${_gam}prebid_oxb_html_interstitial',
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Display Interstitial 320x480 (GAM) [OK, Random]',
      configId: 'prebid-demo-display-interstitial-320-480',
      format: DemoAdFormat.displayInterstitial,
      integration: DemoIntegration.gam,
      adUnitId: '${_gam}prebid_oxb_html_interstitial_random',
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Interstitial 320x480 (GAM)',
      configId: 'prebid-demo-video-interstitial-320-480',
      format: DemoAdFormat.videoInterstitial,
      integration: DemoIntegration.gam,
      adUnitId: '${_gam}prebid_oxb_html_interstitial',
      width: 320,
      height: 480,
    ),

    // =========================================================================
    // GAM RENDERING — Video Outstream
    // =========================================================================
    TestCase(
      title: 'Video Outstream (GAM) [OK, AppEvent]',
      configId: 'prebid-demo-video-outstream',
      format: DemoAdFormat.videoBanner,
      integration: DemoIntegration.gam,
      adUnitId: '${_gam}prebid_oxb_300x250_banner',
      width: 300,
      height: 250,
    ),
    TestCase(
      title: 'Video Outstream [noBids] (GAM)',
      configId: 'prebid-demo-no-bids',
      format: DemoAdFormat.videoBanner,
      integration: DemoIntegration.gam,
      adUnitId: '${_gam}prebid_oxb_300x250_banner',
      width: 300,
      height: 250,
    ),
    TestCase(
      title: 'Video Outstream with End Card (GAM)',
      configId: 'prebid-demo-video-outstream-with-end-card',
      format: DemoAdFormat.videoBanner,
      integration: DemoIntegration.gam,
      adUnitId: '${_gam}prebid_oxb_300x250_banner',
      width: 300,
      height: 250,
    ),

    // =========================================================================
    // GAM RENDERING — Rewarded
    // =========================================================================
    TestCase(
      title: 'Display Rewarded 320x480 (Default) (GAM)',
      configId: 'prebid-demo-banner-rewarded-default',
      format: DemoAdFormat.displayRewarded,
      integration: DemoIntegration.gam,
      adUnitId: _gamRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Rewarded 320x480 (GAM)',
      configId: 'prebid-demo-video-rewarded-320-480',
      format: DemoAdFormat.videoRewarded,
      integration: DemoIntegration.gam,
      adUnitId: _gamRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Rewarded 320x480 without End Card (GAM)',
      configId: 'prebid-demo-video-rewarded-320-480-without-end-card',
      format: DemoAdFormat.videoRewarded,
      integration: DemoIntegration.gam,
      adUnitId: _gamRewarded,
      width: 320,
      height: 480,
    ),

    // =========================================================================
    // GAM RENDERING — Native
    // =========================================================================
    TestCase(
      title: 'Native Ad (GAM)',
      configId: 'prebid-demo-banner-native-styles',
      format: DemoAdFormat.native,
      integration: DemoIntegration.gam,
      adUnitId: _gamNative,
    ),
    TestCase(
      title: 'Native Ad Links (GAM)',
      configId: 'prebid-demo-native-links',
      format: DemoAdFormat.native,
      integration: DemoIntegration.gam,
      adUnitId: _gamNative,
    ),

    // =========================================================================
    // GAM ORIGINAL API — Banner
    // =========================================================================
    TestCase(
      title: 'Banner 320x50 (GAM Original) [OK, PUC]',
      configId: 'prebid-demo-banner-320-50',
      format: DemoAdFormat.displayBanner,
      integration: DemoIntegration.original,
      adUnitId: '${_gam}prebid_demo_app_original_api_banner',
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'Banner 300x250 (GAM Original) [OK, PUC]',
      configId: 'prebid-demo-banner-300-250',
      format: DemoAdFormat.displayBanner,
      integration: DemoIntegration.original,
      adUnitId: '${_gam}prebid_demo_app_original_api_banner_300x250_order',
      width: 300,
      height: 250,
    ),
    TestCase(
      title: 'Banner 728x90 (GAM Original) [OK, PUC]',
      configId: 'prebid-demo-banner-728-90',
      format: DemoAdFormat.displayBanner,
      integration: DemoIntegration.original,
      adUnitId: '${_gam}prebid_demo_app_original_api_banner_728x90',
      width: 728,
      height: 90,
    ),
    TestCase(
      title: 'Banner Multisize (GAM Original) [OK, PUC]',
      configId: 'prebid-demo-banner-multisize',
      format: DemoAdFormat.displayBanner,
      integration: DemoIntegration.original,
      adUnitId: '${_gam}prebid_demo_app_original_api_banner_multisize',
      width: 320,
      height: 50,
    ),

    // =========================================================================
    // ADMOB — Banner
    // =========================================================================
    TestCase(
      title: 'Banner 320x50 (AdMob) [OK, OXB Adapter]',
      configId: 'prebid-demo-banner-320-50',
      format: DemoAdFormat.displayBanner,
      integration: DemoIntegration.admob,
      adUnitId: _admobBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'Banner 320x50 (AdMob) [noBids, AdMob ad]',
      configId: 'prebid-demo-no-bids',
      format: DemoAdFormat.displayBanner,
      integration: DemoIntegration.admob,
      adUnitId: _admobBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'Banner 300x250 (AdMob) [OK, OXB Adapter]',
      configId: 'prebid-demo-banner-300-250',
      format: DemoAdFormat.displayBanner,
      integration: DemoIntegration.admob,
      adUnitId: _admobBanner,
      width: 300,
      height: 250,
    ),

    // =========================================================================
    // ADMOB — Interstitial
    // =========================================================================
    TestCase(
      title: 'Display Interstitial 320x480 (AdMob) [OK, OXB Adapter]',
      configId: 'prebid-demo-display-interstitial-320-480',
      format: DemoAdFormat.displayInterstitial,
      integration: DemoIntegration.admob,
      adUnitId: _admobInterstitial,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Interstitial 320x480 (AdMob) [OK, OXB Adapter]',
      configId: 'prebid-demo-video-interstitial-320-480',
      format: DemoAdFormat.videoInterstitial,
      integration: DemoIntegration.admob,
      adUnitId: _admobInterstitial,
      width: 320,
      height: 480,
    ),

    // =========================================================================
    // ADMOB — Rewarded
    // =========================================================================
    TestCase(
      title: 'Video Rewarded 320x480 (AdMob) [OK, OXB Adapter]',
      configId: 'prebid-demo-video-rewarded-320-480',
      format: DemoAdFormat.videoRewarded,
      integration: DemoIntegration.admob,
      adUnitId: _admobRewarded,
      width: 320,
      height: 480,
    ),

    // =========================================================================
    // ADMOB — Native
    // =========================================================================
    TestCase(
      title: 'Native Ad (AdMob) [OK, OXB Adapter]',
      configId: 'prebid-demo-banner-native-styles',
      format: DemoAdFormat.native,
      integration: DemoIntegration.admob,
      adUnitId: _admobNative,
    ),

    // =========================================================================
    // MAX — Banner
    // =========================================================================
    TestCase(
      title: 'Banner 320x50 (MAX) [OK, Adapter]',
      configId: 'prebid-demo-banner-320-50',
      format: DemoAdFormat.displayBanner,
      integration: DemoIntegration.max,
      adUnitId: _maxBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'Banner 320x50 (MAX) [noBids, MAX ad]',
      configId: 'prebid-demo-no-bids',
      format: DemoAdFormat.displayBanner,
      integration: DemoIntegration.max,
      adUnitId: _maxBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'Banner 300x250 (MAX) [OK, Adapter]',
      configId: 'prebid-demo-banner-300-250',
      format: DemoAdFormat.displayBanner,
      integration: DemoIntegration.max,
      adUnitId: _maxMrec,
      width: 300,
      height: 250,
    ),

    // =========================================================================
    // MAX — Interstitial
    // =========================================================================
    TestCase(
      title: 'Display Interstitial 320x480 (MAX) [OK, Adapter]',
      configId: 'prebid-demo-display-interstitial-320-480',
      format: DemoAdFormat.displayInterstitial,
      integration: DemoIntegration.max,
      adUnitId: _maxInterstitial,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Interstitial 320x480 (MAX) [OK, Adapter]',
      configId: 'prebid-demo-video-interstitial-320-480',
      format: DemoAdFormat.videoInterstitial,
      integration: DemoIntegration.max,
      adUnitId: _maxInterstitial,
      width: 320,
      height: 480,
    ),

    // =========================================================================
    // MAX — Rewarded
    // =========================================================================
    TestCase(
      title: 'Video Rewarded 320x480 (MAX) [OK, Adapter]',
      configId: 'prebid-demo-video-rewarded-320-480-without-end-card',
      format: DemoAdFormat.videoRewarded,
      integration: DemoIntegration.max,
      adUnitId: _maxRewarded,
      width: 320,
      height: 480,
    ),

    // =========================================================================
    // MAX — Native
    // =========================================================================
    TestCase(
      title: 'Native Ad (MAX) [OK, Adapter]',
      configId: 'prebid-demo-banner-native-styles',
      format: DemoAdFormat.native,
      integration: DemoIntegration.max,
      adUnitId: _maxNative,
    ),
  ];
}
