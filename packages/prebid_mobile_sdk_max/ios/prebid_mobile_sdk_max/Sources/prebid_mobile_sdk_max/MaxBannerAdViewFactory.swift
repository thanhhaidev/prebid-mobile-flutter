import Flutter
import UIKit
import PrebidMobile
import PrebidMobileMAXAdapters
import AppLovinSDK

/// PlatformView factory for AppLovin MAX-mediated banners. The rendered view is
/// the MAX `MAAdView`; Prebid's `MediationBannerAdUnit` runs the auction and
/// passes the winning bid to MAX via the Prebid MAX adapter.
class MaxBannerAdViewFactory: NSObject, FlutterPlatformViewFactory {

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
        return MaxBannerPlatformView(
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

class MaxBannerPlatformView: NSObject, FlutterPlatformView, MAAdViewAdDelegate {

    private let maxAdBannerView: MAAdView
    private let methodChannel: FlutterMethodChannel
    private let adSize: CGSize

    // Retained for the lifetime of the view — the auction runs through these.
    private var mediationDelegate: MAXMediationBannerUtils?
    private var mediationAdUnit: MediationBannerAdUnit?

    init(
        frame: CGRect,
        viewId: Int64,
        messenger: FlutterBinaryMessenger,
        args: [String: Any]
    ) {
        let configId = args["configId"] as? String ?? ""
        let maxAdUnitId = args["maxAdUnitId"] as? String ?? ""
        let width = args["width"] as? Int ?? 320
        let height = args["height"] as? Int ?? 50
        let autoLoad = args["autoLoad"] as? Bool ?? true

        adSize = CGSize(width: width, height: height)

        methodChannel = FlutterMethodChannel(
            name: "prebid_mobile_sdk_max/banner_\(viewId)",
            binaryMessenger: messenger
        )

        // 1. Create and configure the MAX ad view.
        maxAdBannerView = MAAdView(adUnitIdentifier: maxAdUnitId)
        maxAdBannerView.frame = CGRect(origin: .zero, size: adSize)
        maxAdBannerView.isHidden = false

        super.init()

        maxAdBannerView.delegate = self

        // 2. Prebid mediation utils + ad unit.
        let mediationDelegate = MAXMediationBannerUtils(adView: maxAdBannerView)
        self.mediationDelegate = mediationDelegate
        let adUnit = MediationBannerAdUnit(
            configID: configId,
            size: adSize,
            mediationDelegate: mediationDelegate
        )
        mediationAdUnit = adUnit

        if autoLoad {
            // 3. Fetch demand, then load the MAX banner.
            adUnit.fetchDemand { [weak self] _ in
                self?.maxAdBannerView.loadAd()
            }
        }
    }

    func view() -> UIView {
        return maxAdBannerView
    }

    // MARK: - MAAdViewAdDelegate

    func didLoad(_ ad: MAAd) {
        methodChannel.invokeMethod("onAdSize", arguments: [
            "width": Double(adSize.width),
            "height": Double(adSize.height),
        ])
        methodChannel.invokeMethod("onAdLoaded", arguments: nil)
        methodChannel.invokeMethod("onAdDisplayed", arguments: nil)
    }

    func didFailToLoadAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
        let nsError = NSError(
            domain: "MAX",
            code: error.code.rawValue,
            userInfo: [NSLocalizedDescriptionKey: error.message]
        )
        mediationAdUnit?.adObjectDidFailToLoadAd(adObject: maxAdBannerView, with: nsError)
        methodChannel.invokeMethod("onAdFailed", arguments: error.message)
    }

    func didFail(toDisplay ad: MAAd, withError error: MAError) {
        methodChannel.invokeMethod("onAdFailed", arguments: error.message)
    }

    func didClick(_ ad: MAAd) {
        methodChannel.invokeMethod("onAdClicked", arguments: nil)
    }

    func didHide(_ ad: MAAd) {
        methodChannel.invokeMethod("onAdClosed", arguments: nil)
    }

    func didDisplay(_ ad: MAAd) {}
    func didExpand(_ ad: MAAd) {}
    func didCollapse(_ ad: MAAd) {}
}
