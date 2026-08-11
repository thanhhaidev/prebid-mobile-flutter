import 'demo_ad_format.dart';
import 'test_case.dart';

/// Top-level category used by the Examples filter row, mirroring the Prebid
/// reference test app's ad-type chips.
enum DemoAdCategory {
  all('All'),
  banner('Banner'),
  interstitial('Interstitial'),
  rewarded('Rewarded'),
  mraid('MRAID'),
  video('Video'),
  native('Native');

  final String label;
  const DemoAdCategory(this.label);
}

/// Buckets a [TestCase] into a [DemoAdCategory] for filtering.
///
/// MRAID is cross-cutting (matched by configId) and takes priority, matching
/// the reference where MRAID creatives get their own chip regardless of the
/// underlying ad unit.
DemoAdCategory categoryOf(TestCase tc) {
  if (tc.configId.contains('mraid')) return DemoAdCategory.mraid;
  return switch (tc.format) {
    DemoAdFormat.displayBanner ||
    DemoAdFormat.videoBanner => DemoAdCategory.banner,
    DemoAdFormat.displayInterstitial ||
    DemoAdFormat.videoInterstitial => DemoAdCategory.interstitial,
    DemoAdFormat.displayRewarded ||
    DemoAdFormat.videoRewarded => DemoAdCategory.rewarded,
    DemoAdFormat.native => DemoAdCategory.native,
    DemoAdFormat.videoInstream ||
    DemoAdFormat.multiformat => DemoAdCategory.video,
  };
}
