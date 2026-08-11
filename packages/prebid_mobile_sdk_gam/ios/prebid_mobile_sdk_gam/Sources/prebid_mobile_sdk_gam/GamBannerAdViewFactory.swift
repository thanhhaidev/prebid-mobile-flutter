import Flutter
import UIKit
import GoogleMobileAds
import PrebidMobile
import PrebidMobileGAMEventHandlers

/// PlatformView factory for GAM-rendered banners. Mirrors the core
/// BannerAdViewFactory but builds the BannerView with a `GAMBannerEventHandler`
/// so Google Ad Manager renders the ad.
class GamBannerAdViewFactory: NSObject, FlutterPlatformViewFactory {

    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return GamBannerPlatformView(
            frame: frame,
            viewId: viewId,
            messenger: messenger,
            args: args as? [String: Any] ?? [:]
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class GamBannerPlatformView: NSObject, FlutterPlatformView, PrebidMobile.BannerViewDelegate {

    private let bannerView: PrebidMobile.BannerView
    private let methodChannel: FlutterMethodChannel

    init(
        frame: CGRect,
        viewId: Int64,
        messenger: FlutterBinaryMessenger,
        args: [String: Any]
    ) {
        let configId = args["configId"] as? String ?? ""
        let gamAdUnitId = args["gamAdUnitId"] as? String ?? ""
        let width = args["width"] as? Int ?? 320
        let height = args["height"] as? Int ?? 50
        let isVideo = args["isVideo"] as? Bool ?? false
        let autoLoad = args["autoLoad"] as? Bool ?? true
        let refreshInterval = args["refreshIntervalSeconds"] as? Int

        let adSize = CGSize(width: width, height: height)

        methodChannel = FlutterMethodChannel(
            name: "prebid_mobile_sdk_gam/banner_\(viewId)",
            binaryMessenger: messenger
        )

        let eventHandler = GAMBannerEventHandler(
            adUnitID: gamAdUnitId,
            validGADAdSizes: [nsValue(for: adSizeFor(cgSize: adSize))]
        )
        bannerView = PrebidMobile.BannerView(
            frame: CGRect(origin: .zero, size: adSize),
            configID: configId,
            adSize: adSize,
            eventHandler: eventHandler
        )

        super.init()

        if isVideo {
            bannerView.adFormat = .video
        }

        if let interval = refreshInterval, interval > 0 {
            bannerView.refreshInterval = TimeInterval(interval)
        }

        bannerView.delegate = self

        if autoLoad {
            bannerView.loadAd()
        }
    }

    func view() -> UIView {
        return bannerView
    }

    // MARK: - BannerViewDelegate

    func bannerViewPresentationController() -> UIViewController? {
        return UIApplication.shared.keyWindow?.rootViewController
    }

    func bannerView(_ bannerView: PrebidMobile.BannerView, didReceiveAdWithAdSize adSize: CGSize) {
        methodChannel.invokeMethod("onAdSize", arguments: [
            "width": Double(adSize.width),
            "height": Double(adSize.height),
        ])
        // iOS reports load and render as one event; Android splits them into
        // onAdLoaded + onAdDisplayed, so emit both here for cross-platform parity.
        methodChannel.invokeMethod("onAdLoaded", arguments: nil)
        methodChannel.invokeMethod("onAdDisplayed", arguments: nil)
    }

    func bannerView(_ bannerView: PrebidMobile.BannerView, didFailToReceiveAdWith error: Error) {
        methodChannel.invokeMethod("onAdFailed", arguments: error.localizedDescription)
    }

    func bannerViewWillPresentModal(_ bannerView: PrebidMobile.BannerView) {
        methodChannel.invokeMethod("onAdClicked", arguments: nil)
    }

    func bannerViewDidDismissModal(_ bannerView: PrebidMobile.BannerView) {
        methodChannel.invokeMethod("onAdClosed", arguments: nil)
    }
}
