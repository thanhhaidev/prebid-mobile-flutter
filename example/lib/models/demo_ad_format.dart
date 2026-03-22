/// Ad format categories matching Prebid's demo app.
///
/// Maps to Prebid iOS demo's `AdFormat` enum from
/// `IntegrationCase/AdFormat.swift`.
enum DemoAdFormat {
  displayBanner('Display Banner'),
  videoBanner('Video Banner'),
  nativeBanner('Native Banner'),
  displayInterstitial('Display Interstitial'),
  videoInterstitial('Video Interstitial'),
  displayRewarded('Display Rewarded'),
  videoRewarded('Video Rewarded'),
  videoInstream('Video In-stream'),
  native('Native'),
  multiformat('Multiformat');

  final String label;
  const DemoAdFormat(this.label);
}
