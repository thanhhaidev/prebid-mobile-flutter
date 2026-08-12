import 'demo_ad_format.dart';
import 'test_case.dart';

/// Format tag used by the Examples format-filter row, mirroring the Prebid
/// `PrebidInternalTestApp` tags (Banner / Interstitial / MRAID / Video /
/// Native). Rewarded, outstream, in-stream and multiformat all fold into
/// [video] exactly as the reference app does.
enum DemoAdCategory {
  all('All'),
  banner('Banner'),
  interstitial('Interstitial'),
  mraid('MRAID'),
  video('Video'),
  native('Native');

  final String label;
  const DemoAdCategory(this.label);
}

/// Buckets a [TestCase] into a [DemoAdCategory] for the format filter.
///
/// MRAID is cross-cutting (matched by configId) and takes priority, matching
/// the reference where MRAID creatives get their own tag regardless of the
/// underlying ad unit.
DemoAdCategory categoryOf(TestCase tc) {
  if (tc.configId.contains('mraid')) return DemoAdCategory.mraid;
  return switch (tc.format) {
    DemoAdFormat.displayBanner => DemoAdCategory.banner,
    DemoAdFormat.displayInterstitial => DemoAdCategory.interstitial,
    DemoAdFormat.native => DemoAdCategory.native,
    // Outstream banner-video, video interstitial, rewarded, in-stream and
    // multiformat are all tagged "Video" in the reference app.
    DemoAdFormat.videoBanner ||
    DemoAdFormat.videoInterstitial ||
    DemoAdFormat.displayRewarded ||
    DemoAdFormat.videoRewarded ||
    DemoAdFormat.videoInstream ||
    DemoAdFormat.multiformat => DemoAdCategory.video,
  };
}
