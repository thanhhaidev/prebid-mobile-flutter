import Flutter
import UIKit

/// Companion plugin that adds Google AdMob mediation on top of the core
/// prebid_mobile_sdk plugin. Registers the AdMob banner PlatformView factory and
/// the AdMob interstitial method channel.
public class PrebidMobileSdkAdmobPlugin: NSObject, FlutterPlugin {

    /// Retains the interstitial and rewarded managers for the plugin's lifetime.
    private static var interstitialManager: AdMobInterstitialManager?
    private static var rewardedManager: AdMobRewardedManager?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let bannerFactory = AdMobBannerAdViewFactory(messenger: registrar.messenger())
        registrar.register(bannerFactory, withId: "prebid_mobile_sdk_admob/banner")

        let nativeFactory = AdMobNativeAdViewFactory(messenger: registrar.messenger())
        registrar.register(nativeFactory, withId: "prebid_mobile_sdk_admob/native")

        interstitialManager = AdMobInterstitialManager(messenger: registrar.messenger())
        rewardedManager = AdMobRewardedManager(messenger: registrar.messenger())
    }
}
