/// Integration approach a [TestCase] exercises — mirrors the Prebid
/// `PrebidInternalTestApp` integration-type filter row.
enum DemoIntegration {
  /// Prebid Rendering / in-app bidding — the Prebid SDK renders the ad.
  inApp('In-App'),

  /// GAM Rendering API — Google Ad Manager renders via Prebid's GAM (next-gen)
  /// event handlers (companion package `prebid_mobile_sdk_gam`).
  gam('GAM'),

  /// GAM Original API — Prebid returns targeting keywords and Google Ad Manager
  /// renders through a line item + the Prebid Universal Creative.
  original('Original'),

  /// Google AdMob mediation via Prebid's AdMob adapters
  /// (companion package `prebid_mobile_sdk_admob`).
  admob('AdMob'),

  /// AppLovin MAX mediation via Prebid's MAX adapters
  /// (companion package `prebid_mobile_sdk_max`).
  max('Max');

  final String label;
  const DemoIntegration(this.label);
}
