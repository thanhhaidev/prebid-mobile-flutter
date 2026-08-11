import '../models/demo_ad_format.dart';
import '../models/test_case.dart';

/// Registry of all In-App (Prebid Rendering) test cases.
///
/// Mirrors the `in_app` section of the Prebid Mobile Android
/// `PrebidInternalTestApp` (`DemoItemProvider.kt`) — the same configIds run
/// against the community server at `prebid-server-test-j.prebid.org`.
///
/// Scope: this plugin wraps the **Prebid Rendering / in-app bidding** API only,
/// so only the reference's `in_app` (PPM) cases are reproduced. GAM / AdMob /
/// AppLovin-MAX mediation, custom ad renderers, and Android-only view
/// integration patterns (RecyclerView, scrollable, feed, reusable, in-layout)
/// have no Flutter equivalent and are intentionally omitted.
///
/// `storedResponse` is left null so every case runs a live auction.
class TestCaseRegistry {
  static const allCases = [
    // =========================================================================
    // Display Banner
    // =========================================================================
    TestCase(
      title: 'Banner 320x50',
      configId: 'prebid-demo-banner-320-50',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'Banner 320x50 (No Bids)',
      configId: 'prebid-demo-no-bids',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'Banner 320x50 (Incorrect VAST)',
      configId: 'prebid-demo-banner-incorrect-vast',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'Banner 320x50 (Deeplink+)',
      configId: 'prebid-demo-banner-deeplink',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'Banner 300x250',
      configId: 'prebid-demo-banner-300-250',
      format: DemoAdFormat.displayBanner,
      width: 300,
      height: 250,
    ),
    TestCase(
      title: 'Banner 728x90',
      configId: 'prebid-demo-banner-728-90',
      format: DemoAdFormat.displayBanner,
      width: 728,
      height: 90,
    ),
    TestCase(
      title: 'Banner Multisize',
      configId: 'prebid-demo-banner-multisize',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),

    // =========================================================================
    // MRAID (rendered as display banners)
    // =========================================================================
    TestCase(
      title: 'MRAID 2.0: Expand — 1 Part',
      configId: 'prebid-demo-mraid-expand-1-part',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'MRAID 2.0: Expand — 2 Part',
      configId: 'prebid-demo-mraid-expand-2-part',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'MRAID 2.0: Resize',
      configId: 'prebid-demo-mraid-resize',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'MRAID 2.0: Resize With Errors',
      configId: 'prebid-demo-mraid-resize-with-errors',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'MRAID 2.0: Resize (Expandable)',
      configId: 'prebid-demo-mraid-resize-expandable',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'MRAID 3.0: Viewability Compliance',
      configId: 'prebid-demo-mraid-viewability-compliance',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'MRAID 3.0: Resize Negative Test',
      configId: 'prebid-demo-mraid-resize-negative-test',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'MRAID 3.0: Load And Events',
      configId: 'prebid-demo-mraid-load-and-events',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'MRAID 3.0: Test Properties',
      configId: 'prebid-demo-mraid-test-properties-3',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),
    TestCase(
      title: 'MRAID 3.0: Test Methods',
      configId: 'prebid-demo-mraid-test-methods-3',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),

    // =========================================================================
    // Video Banner (Outstream)
    // =========================================================================
    TestCase(
      title: 'Video Outstream',
      configId: 'prebid-demo-video-outstream',
      format: DemoAdFormat.videoBanner,
      width: 300,
      height: 250,
    ),
    TestCase(
      title: 'Video Outstream (No Bids)',
      configId: 'prebid-demo-no-bids',
      format: DemoAdFormat.videoBanner,
      width: 300,
      height: 250,
    ),
    TestCase(
      title: 'Video Outstream with End Card',
      configId: 'prebid-demo-video-outstream-with-end-card',
      format: DemoAdFormat.videoBanner,
      width: 300,
      height: 250,
    ),

    // =========================================================================
    // Display Interstitial
    // =========================================================================
    TestCase(
      title: 'Display Interstitial 320x480',
      configId: 'prebid-demo-display-interstitial-320-480',
      format: DemoAdFormat.displayInterstitial,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Display Interstitial 320x480 (No Bids)',
      configId: 'prebid-demo-no-bids',
      format: DemoAdFormat.displayInterstitial,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'MRAID 2.0: Fullscreen',
      configId: 'prebid-demo-mraid-fullscreen',
      format: DemoAdFormat.displayInterstitial,
      width: 320,
      height: 480,
    ),

    // =========================================================================
    // Video Interstitial
    // =========================================================================
    TestCase(
      title: 'Video Interstitial 320x480',
      configId: 'prebid-demo-video-interstitial-320-480',
      format: DemoAdFormat.videoInterstitial,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Interstitial 320x480 (No Bids)',
      configId: 'prebid-demo-no-bids',
      format: DemoAdFormat.videoInterstitial,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Interstitial 320x480 With End Card',
      configId: 'prebid-demo-video-interstitial-320-480-with-end-card',
      format: DemoAdFormat.videoInterstitial,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Interstitial 320x480 SkipOffset',
      configId: 'prebid-demo-video-interstitial-320-480-skip-offset',
      format: DemoAdFormat.videoInterstitial,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Interstitial 320x480 Deeplink+',
      configId: 'prebid-demo-video-interstitial-320-480-deeplink',
      format: DemoAdFormat.videoInterstitial,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Interstitial MRAID End Card',
      configId: 'prebid-demo-video-interstitial-mraid-end-card',
      format: DemoAdFormat.videoInterstitial,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Interstitial Vertical With End Card',
      configId: 'prebid-demo-video-interstitial-vertical-with-end-card',
      format: DemoAdFormat.videoInterstitial,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Interstitial With Ad Configuration',
      configId: 'prebid-demo-video-interstitial-320-480-with-ad-configuration',
      format: DemoAdFormat.videoInterstitial,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Interstitial End Card With Ad Configuration',
      configId:
          'prebid-demo-video-interstitial-320-480-with-end-card-with-ad-configuration',
      format: DemoAdFormat.videoInterstitial,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'MRAID: Video Interstitial',
      configId: 'prebid-demo-mraid-video-interstitial',
      format: DemoAdFormat.videoInterstitial,
      width: 320,
      height: 480,
    ),

    // =========================================================================
    // Display Rewarded
    // =========================================================================
    TestCase(
      title: 'Display Rewarded (Default)',
      configId: 'prebid-demo-banner-rewarded-default',
      format: DemoAdFormat.displayRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Display Rewarded (Time + autoclose)',
      configId: 'prebid-demo-banner-rewarded-time',
      format: DemoAdFormat.displayRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Display Rewarded (Event + close)',
      configId: 'prebid-demo-banner-rewarded-event',
      format: DemoAdFormat.displayRewarded,
      width: 320,
      height: 480,
    ),

    // =========================================================================
    // Video Rewarded
    // =========================================================================
    TestCase(
      title: 'Video Rewarded (Default)',
      configId: 'prebid-demo-video-rewarded-default',
      format: DemoAdFormat.videoRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Rewarded (Time + autoclose)',
      configId: 'prebid-demo-video-rewarded-time',
      format: DemoAdFormat.videoRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Rewarded (Playback Event)',
      configId: 'prebid-demo-video-rewarded-playbackevent',
      format: DemoAdFormat.videoRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Rewarded 320x480 (With End Card)',
      configId: 'prebid-demo-video-rewarded-320-480',
      format: DemoAdFormat.videoRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Rewarded 320x480 (No End Card)',
      configId: 'prebid-demo-video-rewarded-320-480-without-end-card',
      format: DemoAdFormat.videoRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Rewarded 320x480 (No Bids)',
      configId: 'prebid-demo-no-bids',
      format: DemoAdFormat.videoRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Rewarded With Ad Configuration',
      configId: 'prebid-demo-video-rewarded-320-480-with-ad-configuration',
      format: DemoAdFormat.videoRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Rewarded Endcard (Default)',
      configId: 'prebid-demo-video-rewarded-endcard-default',
      format: DemoAdFormat.videoRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Rewarded Endcard (Time + autoclose)',
      configId: 'prebid-demo-video-rewarded-endcard-time',
      format: DemoAdFormat.videoRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Rewarded Endcard (Event + close)',
      configId: 'prebid-demo-video-rewarded-endcard-event',
      format: DemoAdFormat.videoRewarded,
      width: 320,
      height: 480,
    ),

    // =========================================================================
    // Native
    // =========================================================================
    TestCase(
      title: 'Native Ad',
      configId: 'prebid-demo-banner-native-styles',
      format: DemoAdFormat.native,
    ),
    TestCase(
      title: 'Native Ad Links',
      configId: 'prebid-demo-native-links',
      format: DemoAdFormat.native,
    ),

    // =========================================================================
    // Multiformat (Banner + Video + Native in one request)
    // =========================================================================
    TestCase(
      title: 'Multiformat (Banner+Video+Native)',
      configId: 'prebid-demo-banner-320-50',
      format: DemoAdFormat.multiformat,
      width: 320,
      height: 50,
    ),

    // =========================================================================
    // In-Stream Video (fetch demand only)
    // =========================================================================
    TestCase(
      // The reference uses configId "1001-1", but that targets the legacy
      // original-API server, not prebid-server-test-j. A real VAST video
      // config on this server is used so fetchDemand returns keywords.
      title: 'Video In-Stream',
      configId: 'prebid-demo-video-outstream',
      format: DemoAdFormat.videoInstream,
      width: 640,
      height: 480,
    ),
  ];
}
