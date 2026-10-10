import Flutter
import UIKit
import PrebidMobile

/// What `FullscreenAdManager` needs from a Prebid fullscreen ad unit.
protocol FullscreenAdUnit: AnyObject {
    var isReady: Bool { get }
    func loadAd()
    func show(from controller: UIViewController)
}

extension InterstitialRenderingAdUnit: FullscreenAdUnit {}
extension RewardedAdUnit: FullscreenAdUnit {}

/// The method channel of one fullscreen ad kind (e.g.
/// `prebid_mobile_sdk_gam/interstitial`): `load`, `show`, `destroy` and
/// `releaseAll` calls for ads keyed by the `adId` the Dart side allocates,
/// and their events sent back over the same channel. Subclasses build the ad
/// unit in `makeAdUnit(args:)`, set themselves as its delegate and report
/// with `send(_:_:error:extras:)`.
///
/// Not generic: a subclass of a generic class can't adopt Prebid's `@objc`
/// delegate protocols.
class FullscreenAdManager: NSObject {

    private let channel: FlutterMethodChannel
    private var ads: [Int: FullscreenAdUnit] = [:]
    private var adIdByUnit: [ObjectIdentifier: Int] = [:]

    init(name: String, messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
        super.init()
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result)
        }
    }

    /// Builds an ad unit from the `load` arguments, not loaded yet.
    func makeAdUnit(args: [String: Any]) -> FullscreenAdUnit {
        fatalError("Subclasses build their ad unit")
    }

    /// Stops answering calls and drops every ad (engine detached).
    func dispose() {
        channel.setMethodCallHandler(nil)
        releaseAll()
    }

    private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        let adId = (args["adId"] as? NSNumber)?.intValue

        switch call.method {
        case "load", "show":
            guard let adId = adId else {
                result(FlutterError(code: "no_ad_id", message: "Missing adId", details: nil))
                return
            }
            if call.method == "load" { load(adId, args) } else { show(adId) }
        case "destroy":
            if let adId = adId { release(adId) }
        case "releaseAll":
            releaseAll()
        default:
            result(FlutterMethodNotImplemented)
            return
        }
        result(nil)
    }

    private func load(_ adId: Int, _ args: [String: Any]) {
        // Reloading an adId replaces its previous ad unit. No init guard:
        // Prebid iOS handles requests made before initialization.
        release(adId)
        let adUnit = makeAdUnit(args: args)
        ads[adId] = adUnit
        adIdByUnit[ObjectIdentifier(adUnit)] = adId
        adUnit.loadAd()
    }

    private func show(_ adId: Int) {
        guard let adUnit = ads[adId], adUnit.isReady else {
            return send(adId: adId, "onAdFailed", error: PrebidPresenter.notReady)
        }
        PrebidPresenter.whenReady(
            fail: { [weak self] reason in self?.send(adId: adId, "onAdFailed", error: reason) },
            present: { [weak self] controller in
                // The wait may have outlived the ad: destroyed or reloaded
                // (nothing to report), or expired.
                guard let self = self, self.ads[adId] === adUnit else { return }
                guard adUnit.isReady else {
                    return self.send(adId: adId, "onAdFailed", error: PrebidPresenter.notReady)
                }
                adUnit.show(from: controller)
            }
        )
    }

    /// Drops the ad unit for `adId` and its reverse mapping, so late delegate
    /// callbacks from it are no longer forwarded.
    private func release(_ adId: Int) {
        if let adUnit = ads.removeValue(forKey: adId) {
            adIdByUnit.removeValue(forKey: ObjectIdentifier(adUnit))
        }
    }

    /// Drops every ad. Also called from Dart before its first call: after a
    /// hot restart this manager still holds the previous isolate's ads.
    private func releaseAll() {
        ads.removeAll()
        adIdByUnit.removeAll()
    }

    /// Sends `event` for the ad `adUnit` belongs to; ignored once released.
    func send(_ adUnit: AnyObject, _ event: String, error: String? = nil, extras: [String: Any] = [:]) {
        guard let adId = adIdByUnit[ObjectIdentifier(adUnit)] else { return }
        send(adId: adId, event, error: error, extras: extras)
    }

    private func send(adId: Int, _ event: String, error: String? = nil, extras: [String: Any] = [:]) {
        var payload = extras
        payload["adId"] = adId
        if let error = error { payload["error"] = error }
        channel.invokeMethod(event, arguments: payload)
    }
}
