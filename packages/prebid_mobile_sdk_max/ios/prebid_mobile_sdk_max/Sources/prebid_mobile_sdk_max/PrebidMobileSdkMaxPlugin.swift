import Flutter
import UIKit

/// Companion plugin that adds AppLovin MAX mediation on top of the core
/// prebid_mobile_sdk plugin. Registers the MAX banner PlatformView factory and
/// the MAX interstitial method channel.
public class PrebidMobileSdkMaxPlugin: NSObject, FlutterPlugin {

    /// Each engine's managers, kept by its plugin instance (published to the
    /// registrar): shared statics would be replaced by a second engine and
    /// the first engine's calls would never be answered.
    private let interstitialManager: MaxInterstitialManager
    private let rewardedManager: MaxRewardedManager

    private init(messenger: FlutterBinaryMessenger) {
        interstitialManager = MaxInterstitialManager(messenger: messenger)
        rewardedManager = MaxRewardedManager(messenger: messenger)
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let bannerFactory = MaxBannerAdViewFactory(messenger: registrar.messenger())
        registrar.register(bannerFactory, withId: "prebid_mobile_sdk_max/banner")

        let nativeFactory = MaxNativeAdViewFactory(messenger: registrar.messenger())
        registrar.register(nativeFactory, withId: "prebid_mobile_sdk_max/native")

        registrar.publish(PrebidMobileSdkMaxPlugin(messenger: registrar.messenger()))
    }
}
