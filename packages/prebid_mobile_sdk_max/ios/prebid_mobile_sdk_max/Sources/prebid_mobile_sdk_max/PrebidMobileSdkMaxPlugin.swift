import Flutter
import UIKit

/// Companion plugin that adds AppLovin MAX mediation on top of the core
/// prebid_mobile_sdk plugin. Registers the MAX banner and native platform
/// views (`prebid_mobile_sdk_max/banner`, `prebid_mobile_sdk_max/native`) and
/// the interstitial and rewarded method channels
/// (`prebid_mobile_sdk_max/interstitial`, `prebid_mobile_sdk_max/rewarded`).
public final class PrebidMobileSdkMaxPlugin: NSObject, FlutterPlugin {

    /// Each engine's managers, kept by its plugin instance: shared statics
    /// would be replaced by a second engine and the first engine's calls
    /// would never be answered.
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

        // Published so the engine keeps the instance and calls
        // detachFromEngine(for:) on teardown.
        registrar.publish(PrebidMobileSdkMaxPlugin(messenger: registrar.messenger()))
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        interstitialManager.dispose()
        rewardedManager.dispose()
    }
}
