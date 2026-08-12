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
            let configId = args?["configId"] as? String ?? ""
            let adMobAdUnitId = args?["adMobAdUnitId"] as? String ?? ""
            let isVideo = args?["isVideo"] as? Bool ?? false

            // 1. GMA request + Prebid mediation utils + ad unit.
            let gadRequest = Request()
            let mediationDelegate = AdMobMediationInterstitialUtils(gadRequest: gadRequest)
            let adUnit = MediationInterstitialAdUnit(
                configId: configId,
                mediationDelegate: mediationDelegate
            )
            adUnit.adFormats = isVideo ? [.video] : [.banner]

            adUnits[adId] = adUnit
            mediationDelegates[adId] = mediationDelegate

            // 2. Fetch demand, then load the AdMob interstitial.
            adUnit.fetchDemand { [weak self] _ in
                GoogleMobileAds.InterstitialAd.load(
                    with: adMobAdUnitId,
                    request: gadRequest
                ) { [weak self] ad, error in
                    guard let self = self else { return }
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
            if let adId = adId,
               let ad = interstitials[adId],
               let root = UIApplication.shared.keyWindow?.rootViewController {
                ad.present(from: root)
            }
            result(nil)

        case "destroy":
            if let adId = adId {
                if let ad = interstitials.removeValue(forKey: adId) {
                    adIdByInterstitial.removeValue(forKey: ObjectIdentifier(ad))
                }
                adUnits.removeValue(forKey: adId)
                mediationDelegates.removeValue(forKey: adId)
            }
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
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
