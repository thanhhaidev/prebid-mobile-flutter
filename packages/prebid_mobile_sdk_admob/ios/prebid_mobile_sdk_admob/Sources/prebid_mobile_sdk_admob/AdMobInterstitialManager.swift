import Flutter
import UIKit
import GoogleMobileAds
import PrebidMobile
import PrebidMobileAdMobAdapters

/// Handles AdMob-mediated interstitials over the
/// `prebid_mobile_sdk_admob/interstitial` method channel. Each ad is keyed by an
/// `adId` allocated on the Dart side; native events are pushed back over the
/// same channel.
class AdMobInterstitialManager: NSObject, FullScreenContentDelegate {

    private let channel: FlutterMethodChannel

    private var adUnits: [Int: MediationInterstitialAdUnit] = [:]
    private var mediationDelegates: [Int: AdMobMediationInterstitialUtils] = [:]
    private var interstitials: [Int: GoogleMobileAds.InterstitialAd] = [:]
    private var adIdByInterstitial: [ObjectIdentifier: Int] = [:]

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "prebid_mobile_sdk_admob/interstitial",
            binaryMessenger: messenger
        )
        super.init()
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result)
        }
    }

    private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        let adId = args?["adId"] as? Int

        switch call.method {
        case "load":
            guard let adId = adId else {
                result(FlutterError(code: "no_ad_id", message: "Missing adId", details: nil))
                return
            }
            // Reloading an adId replaces its previous ad.
            release(adId)
            let configId = args?["configId"] as? String ?? ""
            let adMobAdUnitId = args?["adMobAdUnitId"] as? String ?? ""
            let isVideo = args?["isVideo"] as? Bool ?? false

            // 1. GMA request + Prebid mediation utils + ad unit.
            let gadRequest = Request()
            let mediationDelegate = AdMobMediationInterstitialUtils(gadRequest: gadRequest)
            let controls = FullscreenControls(args?["controls"])
            let adUnit = MediationInterstitialAdUnit(
                configId: configId,
                minSizePercentage: controls?.minSizePercentage,
                mediationDelegate: mediationDelegate
            )
            controls?.apply(to: adUnit)
            applyVideoParameters(args?["videoParameters"], to: adUnit.videoParameters)
            adUnit.adFormats = isVideo ? [.video] : [.banner]

            adUnits[adId] = adUnit
            mediationDelegates[adId] = mediationDelegate

            // 2. Fetch demand, then load the AdMob interstitial.
            adUnit.fetchDemand { [weak self, weak adUnit] _ in
                // Destroyed / replaced while the auction ran: skip the load.
                guard let self = self, let adUnit = adUnit, self.adUnits[adId] === adUnit else { return }
                GoogleMobileAds.InterstitialAd.load(
                    with: adMobAdUnitId,
                    request: gadRequest
                ) { [weak self, weak adUnit] ad, error in
                    // A late load must not re-insert an ad for a released adId.
                    guard let self = self, let adUnit = adUnit, self.adUnits[adId] === adUnit else { return }
                    if let error = error {
                        self.send(adId, "onAdFailed", error: error.localizedDescription)
                        return
                    }
                    guard let ad = ad else { return }
                    ad.fullScreenContentDelegate = self
                    self.interstitials[adId] = ad
                    self.adIdByInterstitial[ObjectIdentifier(ad)] = adId
                    self.send(adId, "onAdLoaded")
                }
            }
            result(nil)

        case "show":
            guard let adId = adId else {
                result(FlutterError(code: "no_ad_id", message: "Missing adId", details: nil))
                return
            }
            if let ad = interstitials[adId] {
                if let controller = topViewController() {
                    ad.present(from: controller)
                } else {
                    send(adId, "onAdFailed", error: "No view controller to present the interstitial from")
                }
            } else {
                send(adId, "onAdFailed", error: "The interstitial is not ready to show; wait for onAdLoaded")
            }
            result(nil)

        case "destroy":
            if let adId = adId {
                release(adId)
            }
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Drops everything held for `adId` (including the reverse map), so late
    /// callbacks from the released ad are no longer forwarded.
    private func release(_ adId: Int) {
        if let ad = interstitials.removeValue(forKey: adId) {
            ad.fullScreenContentDelegate = nil
            adIdByInterstitial.removeValue(forKey: ObjectIdentifier(ad))
        }
        adUnits.removeValue(forKey: adId)
        mediationDelegates.removeValue(forKey: adId)
    }

    private func send(_ adId: Int, _ event: String, error: String? = nil) {
        var payload: [String: Any] = ["adId": adId]
        if let error = error {
            payload["error"] = error
        }
        channel.invokeMethod(event, arguments: payload)
    }

    // MARK: - FullScreenContentDelegate

    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        if let adId = adIdByInterstitial[ObjectIdentifier(ad as AnyObject)] {
            send(adId, "onAdDisplayed")
        }
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        if let adId = adIdByInterstitial[ObjectIdentifier(ad as AnyObject)] {
            send(adId, "onAdClosed")
        }
    }

    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        if let adId = adIdByInterstitial[ObjectIdentifier(ad as AnyObject)] {
            send(adId, "onAdImpression")
        }
    }

    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        if let adId = adIdByInterstitial[ObjectIdentifier(ad as AnyObject)] {
            send(adId, "onAdClicked")
        }
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        if let adId = adIdByInterstitial[ObjectIdentifier(ad as AnyObject)] {
            send(adId, "onAdFailed", error: error.localizedDescription)
        }
    }
}
