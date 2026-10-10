import Flutter
import UIKit
import GoogleMobileAds

/// One ad of a `FullscreenAdManager`.
protocol FullscreenAd: AnyObject {
    /// Whether the ad has loaded and can be presented.
    var isLoaded: Bool { get }

    /// Frees the ad and detaches its callbacks, so it reports nothing more.
    func destroy()
}

/// Base of the interstitial and rewarded managers: one method channel shared
/// by every ad of a kind, each ad keyed by the `adId` the Dart side allocates.
/// Answers `load` / `show` / `destroy` / `releaseAll` and pushes the ads'
/// events back over the same channel; a subclass builds, loads and presents
/// its kind of ad.
class FullscreenAdManager<Ad: FullscreenAd> {

    private let channel: FlutterMethodChannel
    private var ads: [Int: Ad] = [:]

    init(name: String, messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result)
        }
    }

    /// Builds the ad for `adId` from the `load` arguments, without loading it.
    func makeAd(adId: Int, args: [String: Any]) -> Ad {
        fatalError("Subclasses build their ads")
    }

    /// Starts loading `ad`, already registered for `adId`, and reports
    /// `onAdLoaded` / `onAdFailed` when done (check `isCurrent` first).
    func load(_ ad: Ad, adId: Int) {
        fatalError("Subclasses load their ads")
    }

    /// Presents the loaded `ad` from `controller`.
    func present(_ ad: Ad, adId: Int, from controller: UIViewController) {
        fatalError("Subclasses present their ads")
    }

    /// Whether `ad` is still the one registered for `adId`: false once it was
    /// destroyed or replaced by a newer load, whose events it must not send.
    final func isCurrent(_ ad: Ad, adId: Int) -> Bool {
        ads[adId] === ad
    }

    /// Sends `event` for `adId` on the main thread, with `error` for
    /// `onAdFailed` ("Unknown error" when nil) and any `extra` payload keys.
    final func send(_ adId: Int, _ event: String, error: String? = nil, extra: [String: Any] = [:]) {
        var payload: [String: Any] = ["adId": adId]
        if event == "onAdFailed" {
            payload["error"] = error ?? PrebidErrorFormatter.describe(nil)
        }
        payload.merge(extra) { _, new in new }
        onMain { [channel] in channel.invokeMethod(event, arguments: payload) }
    }

    /// Stops answering calls and frees every ad (engine detached).
    final func dispose() {
        channel.setMethodCallHandler(nil)
        releaseAll()
    }

    private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        let adId = (args["adId"] as? NSNumber)?.intValue

        switch call.method {
        case "load":
            guard let adId = adId else { return result(Self.missingAdId) }
            // Reloading an adId replaces (and frees) its previous ad. No
            // initialization check: Prebid iOS handles requests made before
            // the SDK finished initializing.
            release(adId)
            let ad = makeAd(adId: adId, args: args)
            ads[adId] = ad
            load(ad, adId: adId)
            result(nil)
        case "show":
            guard let adId = adId else { return result(Self.missingAdId) }
            show(adId)
            result(nil)
        case "destroy":
            if let adId = adId { release(adId) }
            result(nil)
        case "releaseAll":
            releaseAll()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func show(_ adId: Int) {
        guard let ad = ads[adId], ad.isLoaded else {
            return send(adId, "onAdFailed", error: PrebidPresenter.notReady)
        }
        PrebidPresenter.whenReady(
            fail: { [weak self] reason in self?.send(adId, "onAdFailed", error: reason) },
            present: { [weak self, weak ad] controller in
                guard let self = self else { return }
                // The wait for a busy controller may outlast the ad.
                guard let ad = ad, self.isCurrent(ad, adId: adId), ad.isLoaded else {
                    return self.send(adId, "onAdFailed", error: PrebidPresenter.notReady)
                }
                self.present(ad, adId: adId, from: controller)
            }
        )
    }

    private func release(_ adId: Int) {
        ads.removeValue(forKey: adId)?.destroy()
    }

    private func releaseAll() {
        let all = ads.values
        ads.removeAll()
        all.forEach { $0.destroy() }
    }

    private static var missingAdId: FlutterError {
        FlutterError(code: "no_ad_id", message: "Missing adId", details: nil)
    }
}

/// Forwards one AdMob fullscreen ad's callbacks as Dart events. AdMob holds
/// `fullScreenContentDelegate` weakly, so the ad's `FullscreenAd` keeps it.
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
