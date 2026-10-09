import Flutter
import UIKit
import GoogleMobileAds
import PrebidMobile
import PrebidMobileAdMobAdapters

/// PlatformView factory for AdMob-mediated banners. The rendered view is the
/// Google Mobile Ads `BannerView`; Prebid's `MediationBannerAdUnit` runs the
/// auction and passes the winning bid to AdMob via the Prebid AdMob adapter.
class AdMobBannerAdViewFactory: NSObject, FlutterPlatformViewFactory {

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
        return AdMobBannerPlatformView(
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

class AdMobBannerPlatformView: NSObject, FlutterPlatformView, GoogleMobileAds.BannerViewDelegate {

    private let gadBanner: GoogleMobileAds.BannerView
    private let methodChannel: FlutterMethodChannel
    private let adSize: CGSize
    private let gadRequest = Request()

    // Retained for the lifetime of the view — the auction runs through these.
    private var mediationDelegate: AdMobMediationBannerUtils?
    private var mediationAdUnit: MediationBannerAdUnit?

    init(
        frame: CGRect,
        viewId: Int64,
        messenger: FlutterBinaryMessenger,
        args: [String: Any]
    ) {
        let configId = args["configId"] as? String ?? ""
        let adMobAdUnitId = args["adMobAdUnitId"] as? String ?? ""
        let width = args["width"] as? Int ?? 320
        let height = args["height"] as? Int ?? 50
        let autoLoad = args["autoLoad"] as? Bool ?? true

        adSize = CGSize(width: width, height: height)

        methodChannel = FlutterMethodChannel(
            name: "prebid_mobile_sdk_admob/banner_\(viewId)",
            binaryMessenger: messenger
        )

        // 1. Create the GMA banner view (the request is a stored property).
        gadBanner = GoogleMobileAds.BannerView(adSize: adSizeFor(cgSize: adSize))
        gadBanner.adUnitID = adMobAdUnitId

        super.init()

        gadBanner.delegate = self
        gadBanner.rootViewController = topViewController()

        // 2. Prebid mediation utils + ad unit.
        let mediationDelegate = AdMobMediationBannerUtils(gadRequest: gadRequest, bannerView: gadBanner)
        self.mediationDelegate = mediationDelegate
        let adUnit = MediationBannerAdUnit(
            configID: configId,
            size: adSize,
            mediationDelegate: mediationDelegate
        )
        mediationAdUnit = adUnit

        // Calls from PrebidBannerAdController.
        methodChannel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "loadAd":
                self?.load()
                result(nil)
            case "stopRefresh":
                self?.mediationAdUnit?.stopRefresh()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        if autoLoad {
            load()
        }
    }

    /// 3. Fetch demand, then let AdMob run its waterfall and render. The weak
    /// capture skips the load when the view was disposed meanwhile.
    private func load() {
        mediationAdUnit?.fetchDemand { [weak self] _ in
            guard let self = self else { return }
            self.gadBanner.rootViewController = topViewController()
            self.gadBanner.load(self.gadRequest)
        }
    }

    func view() -> UIView {
        return gadBanner
    }

    // MARK: - BannerViewDelegate

    func bannerViewDidReceiveAd(_ bannerView: GoogleMobileAds.BannerView) {
        methodChannel.invokeMethod("onAdSize", arguments: [
            "width": Double(adSize.width),
            "height": Double(adSize.height),
        ])
        methodChannel.invokeMethod("onAdLoaded", arguments: nil)
        methodChannel.invokeMethod("onAdDisplayed", arguments: nil)
    }

    func bannerView(
        _ bannerView: GoogleMobileAds.BannerView,
        didFailToReceiveAdWithError error: Error
    ) {
        mediationAdUnit?.adObjectDidFailToLoadAd(adObject: gadBanner, with: error)
        methodChannel.invokeMethod("onAdFailed", arguments: error.localizedDescription)
    }

    func bannerViewDidRecordImpression(_ bannerView: GoogleMobileAds.BannerView) {
        methodChannel.invokeMethod("onAdImpression", arguments: nil)
    }

    func bannerViewDidRecordClick(_ bannerView: GoogleMobileAds.BannerView) {
        methodChannel.invokeMethod("onAdClicked", arguments: nil)
    }

    func bannerViewDidDismissScreen(_ bannerView: GoogleMobileAds.BannerView) {
        methodChannel.invokeMethod("onAdClosed", arguments: nil)
    }
}
