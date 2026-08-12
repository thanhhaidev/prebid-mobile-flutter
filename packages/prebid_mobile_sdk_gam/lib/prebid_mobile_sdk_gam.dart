/// Google Ad Manager (GAM) **rendering** integration for Prebid Mobile Flutter.
///
/// This optional companion package lets Google Ad Manager render the ad while
/// Prebid demand competes in the same auction, using Prebid's GAM
/// [event handlers](https://docs.prebid.org/prebid-mobile/pbm-api/android/pbm-ad-unit-banner-android.html).
/// Unlike the core [`PrebidBannerAd`] (Prebid renders) or the Original API
/// keyword handoff, here GAM owns rendering via a Prebid line item + the Prebid
/// Universal Creative.
///
/// It pulls in the Google Mobile Ads SDK natively, which is why it is a separate
/// package — apps that only use Prebid's In-App rendering are not forced to
/// bundle GMA or declare a GAM app ID.
///
/// ## Requirements
///
/// - Initialize the Google Mobile Ads SDK once at startup (e.g. via the
///   `google_mobile_ads` package's `MobileAds.instance.initialize()`).
/// - Declare your Ad Manager app ID: `GADApplicationIdentifier` in
///   `ios/Runner/Info.plist` and the `com.google.android.gms.ads.APPLICATION_ID`
///   `<meta-data>` in `AndroidManifest.xml`.
/// - Configure Prebid line items in Google Ad Manager that target the `hb_*`
///   keys.
///
/// ## Usage
///
/// ```dart
/// import 'package:prebid_mobile_sdk_gam/prebid_mobile_sdk_gam.dart';
///
/// // Banner (GAM renders):
/// PrebidGamBannerAd(
///   configId: 'prebid-demo-banner-320-50',
///   gamAdUnitId: '/21808260008/prebid_oxb_320x50_banner',
///   width: 320,
///   height: 50,
/// );
///
/// // Interstitial (GAM renders):
/// final interstitial = PrebidGamInterstitialAd(
///   configId: 'prebid-demo-display-interstitial-320-480',
///   gamAdUnitId: '/21808260008/prebid_oxb_html_interstitial',
///   listener: PrebidInterstitialAdListener(onAdLoaded: () => interstitial.show()),
/// );
/// await interstitial.loadAd();
/// ```
library;

export 'src/gam_banner_ad.dart';
export 'src/gam_interstitial_ad.dart';
export 'src/gam_native_ad.dart';
export 'src/gam_rewarded_ad.dart';
