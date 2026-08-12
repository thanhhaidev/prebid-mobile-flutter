/// AppLovin **MAX mediation** integration for Prebid Mobile Flutter.
///
/// This optional companion package competes Prebid demand inside the AppLovin
/// MAX mediation waterfall, using Prebid's
/// [MAX adapters](https://docs.prebid.org/prebid-mobile/modules/rendering/ios-sdk-integration-max.html).
/// Prebid's `MediationBannerAdUnit` / `MediationInterstitialAdUnit` run the
/// auction and hand the winning bid to the MAX ad object (a `MAAdView` /
/// `MAInterstitialAd`) via the Prebid MAX adapter, which then renders the ad.
/// Contrast with the core `PrebidBannerAd` (Prebid renders) or
/// `prebid_mobile_sdk_gam` (Google Ad Manager renders through event handlers).
///
/// It pulls in the AppLovin MAX SDK natively, which is why it is a separate
/// package — apps that only use Prebid's In-App rendering are not forced to
/// bundle AppLovin.
///
/// ## Requirements
///
/// - Initialize the AppLovin MAX SDK once at startup with your SDK key (e.g. via
///   the `applovin_max` package's `AppLovinMAX.initialize(sdkKey)`), before
///   loading any ad here.
/// - In the AppLovin MAX dashboard, add Prebid as a custom network on your ad
///   units and wire the Prebid MAX adapter, as described in the Prebid docs.
///
/// ## Usage
///
/// ```dart
/// import 'package:prebid_mobile_sdk_max/prebid_mobile_sdk_max.dart';
///
/// // Banner (MAX renders the winning Prebid or MAX creative):
/// PrebidMaxBannerAd(
///   configId: 'prebid-demo-banner-320-50',
///   maxAdUnitId: 'YOUR_MAX_BANNER_AD_UNIT_ID',
///   width: 320,
///   height: 50,
/// );
///
/// // Interstitial:
/// final interstitial = PrebidMaxInterstitialAd(
///   configId: 'prebid-demo-display-interstitial-320-480',
///   maxAdUnitId: 'YOUR_MAX_INTERSTITIAL_AD_UNIT_ID',
///   listener: PrebidInterstitialAdListener(onAdLoaded: () => interstitial.show()),
/// );
/// await interstitial.loadAd();
/// ```
library;

export 'src/max_banner_ad.dart';
export 'src/max_interstitial_ad.dart';
export 'src/max_native_ad.dart';
export 'src/max_rewarded_ad.dart';
