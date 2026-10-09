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

class GamBannerPlatformView: NSObject, FlutterPlatformView, PrebidMobile.BannerViewDelegate,
    BannerViewVideoPlaybackDelegate {

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
        let videoPlacement = args["videoPlacementType"] as? String

        let adSize = CGSize(width: width, height: height)

        methodChannel = FlutterMethodChannel(
            name: "prebid_mobile_sdk_gam/banner_\(viewId)",
            binaryMessenger: messenger
        )

        let eventHandler = GAMBannerEventHandler(
            adUnitID: gamAdUnitId,
            validGADAdSizes: [nsValue(for: adSizeFor(cgSize: adSize))]
        )
        if let targeting = gamCustomTargeting(args["customTargeting"]) {
            // Prebid 3.4: app custom targeting on the GAM request; Prebid's
            // hb_* keys still take precedence.
            eventHandler.adManagerRequestConfiguration = { request in
                var merged = request.customTargeting ?? [:]
                targeting.forEach { merged[$0.key] = $0.value }
                request.customTargeting = merged
            }
        }
        bannerView = PrebidMobile.BannerView(
            frame: CGRect(origin: .zero, size: adSize),
            configID: configId,
            adSize: adSize,
            eventHandler: eventHandler
        )

        super.init()

        if isVideo {
            bannerView.adFormats = [.video]
            switch videoPlacement {
            case "inArticle": bannerView.videoParameters.placement = .InArticle
            case "inFeed": bannerView.videoParameters.placement = .InFeed
            default: bannerView.videoParameters.placement = .InBanner
            }
        }

        if let interval = refreshInterval, interval > 0 {
            bannerView.refreshInterval = TimeInterval(interval)
        } else {
            // Prebid iOS refreshes every 60 s by default, and `AdUnitConfig`
            // clamps 0 up to its 15 s minimum — only a negative value is
            // stored as 0, which disables auto-refresh (parity with Android).
            bannerView.refreshInterval = -1
        }

        bannerView.delegate = self
        bannerView.videoPlaybackDelegate = self

        // Calls from PrebidBannerAdController.
        methodChannel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "loadAd":
                self?.bannerView.loadAd()
                result(nil)
            case "stopRefresh":
                self?.bannerView.stopRefresh()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        if autoLoad {
            bannerView.loadAd()
        }
    }

    func view() -> UIView {
        return bannerView
    }

    // MARK: - BannerViewDelegate

    func bannerViewPresentationController() -> UIViewController? {
        return topViewController()
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

    func bannerViewDidExpire(_ bannerView: PrebidMobile.BannerView) {
        methodChannel.invokeMethod("onAdExpired", arguments: nil)
    }

    // MARK: - BannerViewVideoPlaybackDelegate

    func videoPlaybackDidPause(_ banner: PrebidMobile.BannerView) {
        methodChannel.invokeMethod("onVideoPaused", arguments: nil)
    }

    func videoPlaybackDidResume(_ banner: PrebidMobile.BannerView) {
        methodChannel.invokeMethod("onVideoResumed", arguments: nil)
    }

    func videoPlaybackWasMuted(_ banner: PrebidMobile.BannerView) {
        methodChannel.invokeMethod("onVideoMuted", arguments: nil)
    }

    func videoPlaybackWasUnmuted(_ banner: PrebidMobile.BannerView) {
        methodChannel.invokeMethod("onVideoUnmuted", arguments: nil)
    }

    func videoPlaybackDidComplete(_ banner: PrebidMobile.BannerView) {
        methodChannel.invokeMethod("onVideoCompleted", arguments: nil)
    }
}
