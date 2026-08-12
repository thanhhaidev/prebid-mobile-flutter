import Flutter
import UIKit

/// Companion plugin that adds AppLovin MAX mediation on top of the core
/// prebid_mobile_sdk plugin. Registers the MAX banner PlatformView factory and
/// the MAX interstitial method channel.
public class PrebidMobileSdkMaxPlugin: NSObject, FlutterPlugin {

    /// Retains the interstitial and rewarded managers for the plugin's lifetime.
    private static var interstitialManager: MaxInterstitialManager?
    private static var rewardedManager: MaxRewardedManager?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let bannerFactory = MaxBannerAdViewFactory(messenger: registrar.messenger())
        registrar.register(bannerFactory, withId: "prebid_mobile_sdk_max/banner")

        let nativeFactory = MaxNativeAdViewFactory(messenger: registrar.messenger())
        registrar.register(nativeFactory, withId: "prebid_mobile_sdk_max/native")

        interstitialManager = MaxInterstitialManager(messenger: registrar.messenger())
        rewardedManager = MaxRewardedManager(messenger: registrar.messenger())
    }
}
