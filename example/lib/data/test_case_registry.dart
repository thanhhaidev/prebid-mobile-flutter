import '../models/demo_ad_format.dart';
import '../models/test_case.dart';

/// Registry of all In-App test cases.
///
/// Comprehensive list matching Prebid Android demo's `PrebidInternalTestApp`.
/// Test cases use configId directly against the Prebid Server — storedResponse
/// is omitted because the stored auction response IDs on the community test
/// server are not publicly documented.
class TestCaseRegistry {
  static const allCases = [
    // =========================================================================
    // Display Banner
    // =========================================================================
    TestCase(
      title: 'Banner 320x50 (In-App)',
      configId: 'prebid-demo-banner-320-50',
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
    // Video Banner (Outstream)
    // =========================================================================
    TestCase(
      title: 'Video Outstream (In-App)',
      configId: 'prebid-demo-video-outstream',
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
    // Display Interstitial
    // =========================================================================
    TestCase(
      title: 'Display Interstitial 320x480 (In-App)',
      configId: 'prebid-demo-display-interstitial-320-480',
      format: DemoAdFormat.displayInterstitial,
      width: 320,
      height: 480,
    ),

    // =========================================================================
    // Video Interstitial
    // =========================================================================
    TestCase(
      title: 'Video Interstitial 320x480 (In-App)',
      configId: 'prebid-demo-video-interstitial-320-480',
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
      title: 'Video Interstitial 320x480 Deeplink+ (In-App)',
      configId: 'prebid-demo-video-interstitial-320-480-deeplink',
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
      title: 'Video Interstitial MRAID End Card (In-App)',
      configId: 'prebid-demo-video-interstitial-mraid-end-card',
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
    // Display Rewarded
    // =========================================================================
    TestCase(
      title: 'Display Rewarded (Default) (In-App)',
      configId: 'prebid-demo-banner-rewarded-default',
      format: DemoAdFormat.displayRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Display Rewarded (5s + autoclose) (In-App)',
      configId: 'prebid-demo-banner-rewarded-time',
      format: DemoAdFormat.displayRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Display Rewarded (Event + close) (In-App)',
      configId: 'prebid-demo-banner-rewarded-event',
      format: DemoAdFormat.displayRewarded,
      width: 320,
      height: 480,
    ),

    // =========================================================================
    // Video Rewarded
    // =========================================================================
    TestCase(
      title: 'Video Rewarded (Default) (In-App)',
      configId: 'prebid-demo-video-rewarded-default',
      format: DemoAdFormat.videoRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Rewarded (3s + autoclose) (In-App)',
      configId: 'prebid-demo-video-rewarded-time',
      format: DemoAdFormat.videoRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Rewarded (Playback Event) (In-App)',
      configId: 'prebid-demo-video-rewarded-playbackevent',
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
      title: 'Video Rewarded Endcard (Default) (In-App)',
      configId: 'prebid-demo-video-rewarded-endcard-default',
      format: DemoAdFormat.videoRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Rewarded Endcard (5s + autoclose) (In-App)',
      configId: 'prebid-demo-video-rewarded-endcard-time',
      format: DemoAdFormat.videoRewarded,
      width: 320,
      height: 480,
    ),
    TestCase(
      title: 'Video Rewarded Endcard (Event + close) (In-App)',
      configId: 'prebid-demo-video-rewarded-endcard-event',
      format: DemoAdFormat.videoRewarded,
      width: 320,
      height: 480,
    ),

    // =========================================================================
    // MRAID
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
      title: 'MRAID 3.0: Resize Negative Test (In-App)',
      configId: 'prebid-demo-mraid-resize-negative-test',
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
      title: 'MRAID 3.0: Load And Events (In-App)',
      configId: 'prebid-demo-mraid-load-and-events',
      format: DemoAdFormat.displayBanner,
      width: 320,
      height: 50,
    ),

    // =========================================================================
    // Native
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
    // Multiformat
    // =========================================================================
    TestCase(
      title: 'Multiformat (Banner+Video+Native) (In-App)',
      configId: 'prebid-demo-banner-320-50',
      format: DemoAdFormat.multiformat,
      width: 320,
      height: 50,
    ),
  ];
}
