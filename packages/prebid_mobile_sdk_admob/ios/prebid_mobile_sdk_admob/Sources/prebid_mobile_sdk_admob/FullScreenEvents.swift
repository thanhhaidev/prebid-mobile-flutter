import Foundation
import GoogleMobileAds

/// Forwards one AdMob fullscreen ad's callbacks as Dart events. AdMob holds
/// `fullScreenContentDelegate` weakly, so the ad keeps it.
final class FullScreenEvents: NSObject, FullScreenContentDelegate {

    private let send: (_ event: String, _ error: Error?) -> Void

    init(send: @escaping (_ event: String, _ error: Error?) -> Void) {
        self.send = send
    }

    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        send("onAdDisplayed", nil)
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        send("onAdClosed", nil)
    }

    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        send("onAdImpression", nil)
    }

    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        send("onAdClicked", nil)
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        send("onAdFailed", error)
    }
}
