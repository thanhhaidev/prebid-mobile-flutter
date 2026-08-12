/// Google **AdMob mediation** integration for Prebid Mobile Flutter.
///
/// This optional companion package competes Prebid demand inside the Google
/// AdMob mediation waterfall, using Prebid's
/// [AdMob adapters](https://docs.prebid.org/prebid-mobile/modules/rendering/ios-sdk-integration-admob.html).
/// Prebid's `MediationBannerAdUnit` / `MediationInterstitialAdUnit` run the
/// auction and hand the winning bid to the AdMob ad object (a `GADBannerView` /
/// `GADInterstitialAd`) via the Prebid AdMob custom-event adapter, which then
/// renders the ad. Contrast with the core `PrebidBannerAd` (Prebid renders) or
/// `prebid_mobile_sdk_gam` (Google Ad Manager renders through event handlers).
///
/// It pulls in the Google Mobile Ads SDK natively, which is why it is a separate
/// package — apps that only use Prebid's In-App rendering are not forced to
/// bundle GMA.
///
/// ## Requirements
///
/// - Initialize the Google Mobile Ads SDK once at startup (e.g. via the
///   `google_mobile_ads` package's `MobileAds.instance.initialize()`).
/// - Declare your AdMob app ID: `GADApplicationIdentifier` in
///   `ios/Runner/Info.plist` and the `com.google.android.gms.ads.APPLICATION_ID`
///   `<meta-data>` in `AndroidManifest.xml`.
/// - In the AdMob dashboard, add Prebid as a custom-event / mediation source on
///   your ad units and wire the Prebid adapters, as described in the Prebid docs.
///
/// ## Usage
///
/// ```dart
/// import 'package:prebid_mobile_sdk_admob/prebid_mobile_sdk_admob.dart';
///
/// // Banner (AdMob renders the winning Prebid or AdMob creative):
/// PrebidAdMobBannerAd(
///   configId: 'prebid-demo-banner-320-50',
///   adMobAdUnitId: 'ca-app-pub-3940256099942544/6300978111',
///   width: 320,
///   height: 50,
/// );
///
/// // Interstitial:
/// final interstitial = PrebidAdMobInterstitialAd(
///   configId: 'prebid-demo-display-interstitial-320-480',
///   adMobAdUnitId: 'ca-app-pub-3940256099942544/1033173712',
///   listener: PrebidInterstitialAdListener(onAdLoaded: () => interstitial.show()),
/// );
/// await interstitial.loadAd();
/// ```
library;

export 'src/admob_banner_ad.dart';
export 'src/admob_interstitial_ad.dart';
export 'src/admob_native_ad.dart';
export 'src/admob_rewarded_ad.dart';
