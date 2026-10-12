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
    private let preloadedBanners: PreloadedBanners

    private init(messenger: FlutterBinaryMessenger) {
        preloadedBanners = PreloadedBanners(
            messenger: messenger,
            channelName: "prebid_mobile_sdk_max/preloaded_banner"
        ) { channelId, args in
            MaxBannerPlatformView(frame: .zero, viewId: channelId, messenger: messenger, args: args)
        }
        interstitialManager = MaxInterstitialManager(messenger: messenger)
        rewardedManager = MaxRewardedManager(messenger: messenger)
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = PrebidMobileSdkMaxPlugin(messenger: registrar.messenger())
        // Fullscreen ads present in this engine's window.
        let engineWindow: () -> UIWindow? = { [weak registrar] in registrar?.viewController?.viewIfLoaded?.window }
        instance.interstitialManager.engineWindow = engineWindow
        instance.rewardedManager.engineWindow = engineWindow
        let bannerFactory = MaxBannerAdViewFactory(
            messenger: registrar.messenger(),
            preloaded: instance.preloadedBanners
        )
        registrar.register(bannerFactory, withId: "prebid_mobile_sdk_max/banner")

        let nativeFactory = MaxNativeAdViewFactory(messenger: registrar.messenger())
        registrar.register(nativeFactory, withId: "prebid_mobile_sdk_max/native")

        // Published so the engine keeps the instance and calls
        // detachFromEngine(for:) on teardown.
        registrar.publish(instance)
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        preloadedBanners.dispose()
        interstitialManager.dispose()
        rewardedManager.dispose()
    }
}
