import Flutter
import UIKit

// Shared by the companion packages; tool/check_copies.sh keeps the copies
// identical.

/// The method channel of one fullscreen ad kind (e.g.
/// `prebid_mobile_sdk_gam/interstitial`): `load`, `show`, `destroy` and
/// `releaseAll` calls for ads keyed by the `adId` the Dart side allocates,
/// and their events sent back over the same channel. A subclass builds,
/// loads, shows and frees its kind of ad (`Ad`) and reports with `send`.
///
/// A subclass can't adopt the SDKs' `@objc` delegate protocols (it is a
/// subclass of a generic class): its ads forward their delegate callbacks
/// through their own delegate objects.
class FullscreenAdManager<Ad: AnyObject> {

    private let channel: FlutterMethodChannel
    private var ads: [Int: Ad] = [:]

    init(name: String, messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result)
        }
    }

    // MARK: - Subclass hooks

    /// Why a load must be refused before the previous ad of its `adId` is
    /// freed, or `nil` to go ahead.
    func refuseLoad(_ adId: Int, _ args: [String: Any]) -> String? { nil }

    /// Builds the ad for `adId` from the `load` arguments, without loading it.
    func create(_ adId: Int, _ args: [String: Any]) -> Ad {
        preconditionFailure("Subclasses build their ads")
    }

    /// Starts loading `ad`, already registered for `adId`, and reports
    /// `onAdLoaded` / `onAdFailed` when done (check `isCurrent` first).
    func load(_ adId: Int, _ ad: Ad) {
        preconditionFailure("Subclasses load their ads")
    }

    /// Whether `ad` has loaded and can be shown.
    func isLoaded(_ ad: Ad) -> Bool { false }

    /// Shows the loaded `ad` from `controller`.
    func show(_ adId: Int, _ ad: Ad, from controller: UIViewController) {}

    /// Frees `ad`, no longer registered for `adId`, so it reports nothing
    /// more.
    func destroy(_ adId: Int, _ ad: Ad) {}

    // MARK: - For subclasses

    /// Whether `ad` is still the one registered for `adId`: false once it was
    /// destroyed or replaced by a newer load, whose events it must not send.
    final func isCurrent(_ adId: Int, _ ad: Ad) -> Bool {
        ads[adId] === ad
    }

    /// Frees the ad of `adId`, if any.
    final func release(_ adId: Int) {
        if let ad = ads.removeValue(forKey: adId) {
            destroy(adId, ad)
        }
    }

    /// Sends `event` for `adId` on the main thread, with any `extras`;
    /// `onAdFailed` carries `error` as its `error` ("Unknown error" when nil).
    final func send(_ adId: Int, _ event: String, error: String? = nil, extras: [String: Any] = [:]) {
        var payload = extras
        payload["adId"] = adId
        if let error = error {
            payload["error"] = error
        } else if event == "onAdFailed" && payload["error"] == nil {
            payload["error"] = PrebidErrorFormatter.describe(nil as Error?)
        }
        onMain { [channel] in channel.invokeMethod(event, arguments: payload) }
    }

    /// Stops answering calls and frees every ad (engine detached).
    final func dispose() {
        channel.setMethodCallHandler(nil)
        releaseAll()
    }

    // MARK: - Calls

    private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        let adId = (args["adId"] as? NSNumber)?.intValue
        switch call.method {
        case "load", "show":
            guard let adId = adId else {
                return result(FlutterError(code: "no_ad_id", message: "Missing adId", details: nil))
            }
            if call.method == "load" { load(adId, args) } else { show(adId) }
        case "destroy":
            if let adId = adId { release(adId) }
        case "releaseAll":
            releaseAll()
        default:
            return result(FlutterMethodNotImplemented)
        }
        result(nil)
    }

    // No SDK-initialized guard as on Android: Prebid iOS runs requests made
    // before initialization.
    private func load(_ adId: Int, _ args: [String: Any]) {
        if let reason = refuseLoad(adId, args) {
            return send(adId, "onAdFailed", error: reason)
        }
        // Reloading an adId replaces (and frees) its previous ad.
        release(adId)
        let ad = create(adId, args)
        ads[adId] = ad
        load(adId, ad)
    }

    private func show(_ adId: Int) {
        guard let ad = ads[adId], isLoaded(ad) else {
            return send(adId, "onAdFailed", error: PrebidPresenter.notReady)
        }
        PrebidPresenter.whenReady(
            fail: { [weak self] reason in self?.send(adId, "onAdFailed", error: reason) },
            present: { [weak self, weak ad] controller in
                // The wait for a busy controller may outlast the ad:
                // destroyed, reloaded or expired meanwhile.
                guard let self = self else { return }
                guard let ad = ad, self.isCurrent(adId, ad), self.isLoaded(ad) else {
                    return self.send(adId, "onAdFailed", error: PrebidPresenter.notReady)
                }
                self.show(adId, ad, from: controller)
            }
        )
    }

    /// Frees every ad. Also called from Dart before its first call: after a
    /// hot restart this manager still holds the previous isolate's ads.
    private func releaseAll() {
        ads.keys.forEach { release($0) }
    }
}
