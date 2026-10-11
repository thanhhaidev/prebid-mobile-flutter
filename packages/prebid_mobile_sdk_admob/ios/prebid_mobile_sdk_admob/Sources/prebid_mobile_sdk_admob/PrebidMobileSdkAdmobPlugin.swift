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
    private let preloadedBanners: PreloadedBanners

    private init(messenger: FlutterBinaryMessenger) {
        preloadedBanners = PreloadedBanners(
            messenger: messenger,
            channelName: "prebid_mobile_sdk_admob/preloaded_banner"
        ) { channelId, args in
            AdMobBannerPlatformView(frame: .zero, viewId: channelId, messenger: messenger, args: args)
        }
        interstitialManager = AdMobInterstitialManager(messenger: messenger)
        rewardedManager = AdMobRewardedManager(messenger: messenger)
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = PrebidMobileSdkAdmobPlugin(messenger: registrar.messenger())
        // Fullscreen ads present in this engine's window.
        let engineWindow: () -> UIWindow? = { [weak registrar] in registrar?.viewController?.view.window }
        instance.interstitialManager.engineWindow = engineWindow
        instance.rewardedManager.engineWindow = engineWindow
        let bannerFactory = AdMobBannerAdViewFactory(
            messenger: registrar.messenger(),
            preloaded: instance.preloadedBanners
        )
        registrar.register(bannerFactory, withId: "prebid_mobile_sdk_admob/banner")

        let nativeFactory = AdMobNativeAdViewFactory(messenger: registrar.messenger())
        registrar.register(nativeFactory, withId: "prebid_mobile_sdk_admob/native")

        // Published so the engine keeps the instance and calls
        // detachFromEngine(for:) on teardown.
        registrar.publish(instance)
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        preloadedBanners.dispose()
        // Flutter disposes the platform views itself; the fullscreen ads
        // would otherwise outlive the engine (mirrors Android).
        interstitialManager.dispose()
        rewardedManager.dispose()
    }
}
