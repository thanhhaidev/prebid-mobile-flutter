import Flutter
import UIKit

/// Companion plugin that adds Google AdMob mediation on top of the core
/// prebid_mobile_sdk plugin. Registers the AdMob banner and native platform
/// views and the interstitial and rewarded method channels.
public final class PrebidMobileSdkAdmobPlugin: NSObject, FlutterPlugin {

    /// Each engine's managers, kept by its plugin instance (published to the
    /// registrar): shared statics would be replaced by a second engine and
    /// the first engine's calls would never be answered.
    private let interstitialManager: AdMobInterstitialManager
    private let rewardedManager: AdMobRewardedManager

    private init(messenger: FlutterBinaryMessenger) {
        interstitialManager = AdMobInterstitialManager(messenger: messenger)
        rewardedManager = AdMobRewardedManager(messenger: messenger)
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let bannerFactory = AdMobBannerAdViewFactory(messenger: registrar.messenger())
        registrar.register(bannerFactory, withId: "prebid_mobile_sdk_admob/banner")

        let nativeFactory = AdMobNativeAdViewFactory(messenger: registrar.messenger())
        registrar.register(nativeFactory, withId: "prebid_mobile_sdk_admob/native")

        // Published so the engine keeps the instance and calls
        // detachFromEngine(for:) on teardown.
        registrar.publish(PrebidMobileSdkAdmobPlugin(messenger: registrar.messenger()))
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        // Flutter disposes the platform views itself; the fullscreen ads
        // would otherwise outlive the engine (mirrors Android).
        interstitialManager.dispose()
        rewardedManager.dispose()
    }
}
