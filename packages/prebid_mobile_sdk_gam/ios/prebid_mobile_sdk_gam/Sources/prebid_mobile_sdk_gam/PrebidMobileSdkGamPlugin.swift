import Flutter
import UIKit

/// Companion plugin that adds Google Ad Manager (GAM) rendering on top of the
/// core prebid_mobile_sdk plugin. Registers the GAM banner and native platform
/// view factories and the GAM interstitial and rewarded method channels.
public final class PrebidMobileSdkGamPlugin: NSObject, FlutterPlugin {

    /// Each engine's managers, kept by its plugin instance (published to the
    /// registrar): shared statics would be replaced by a second engine and
    /// the first engine's calls would never be answered.
    private let interstitialManager: GamInterstitialManager
    private let rewardedManager: GamRewardedManager
    private let preloadedBanners: PreloadedBanners

    private init(messenger: FlutterBinaryMessenger) {
        preloadedBanners = PreloadedBanners(
            messenger: messenger,
            channelName: "prebid_mobile_sdk_gam/preloaded_banner"
        ) { channelId, args in
            GamBannerPlatformView(frame: .zero, viewId: channelId, messenger: messenger, args: args)
        }
        interstitialManager = GamInterstitialManager(messenger: messenger)
        rewardedManager = GamRewardedManager(messenger: messenger)
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = PrebidMobileSdkGamPlugin(messenger: registrar.messenger())
        // Fullscreen ads present in this engine's window.
        let engineWindow: () -> UIWindow? = { [weak registrar] in registrar?.viewController?.view.window }
        instance.interstitialManager.engineWindow = engineWindow
        instance.rewardedManager.engineWindow = engineWindow
        let factory = GamBannerAdViewFactory(
            messenger: registrar.messenger(),
            preloaded: instance.preloadedBanners
        )
        registrar.register(factory, withId: "prebid_mobile_sdk_gam/banner")

        let nativeFactory = GamNativeAdViewFactory(messenger: registrar.messenger())
        registrar.register(nativeFactory, withId: "prebid_mobile_sdk_gam/native")

        // Published so the engine keeps this instance and calls
        // `detachFromEngine(for:)` on it.
        registrar.publish(instance)
    }

    /// Stops answering the fullscreen channels and drops their ads, as the
    /// Android plugin does in `onDetachedFromEngine`.
    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        preloadedBanners.dispose()
        interstitialManager.dispose()
        rewardedManager.dispose()
    }
}
