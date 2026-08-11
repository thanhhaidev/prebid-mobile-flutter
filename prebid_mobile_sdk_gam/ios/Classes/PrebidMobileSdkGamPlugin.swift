import Flutter
import UIKit

/// Companion plugin that adds Google Ad Manager (GAM) rendering on top of the
/// core prebid_mobile_sdk plugin. Registers the GAM banner PlatformView factory
/// and the GAM interstitial method channel.
public class PrebidMobileSdkGamPlugin: NSObject, FlutterPlugin {

    /// Retains the interstitial manager for the lifetime of the plugin.
    private static var interstitialManager: GamInterstitialManager?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let factory = GamBannerAdViewFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: "prebid_mobile_sdk_gam/banner")

        interstitialManager = GamInterstitialManager(messenger: registrar.messenger())
    }
}
