import Flutter
import UIKit

/// The method channel of one fullscreen ad kind (`prebid_mobile_sdk_max/interstitial`,
/// `prebid_mobile_sdk_max/rewarded`): `load`, `show`, `destroy` and `releaseAll`
/// calls keyed by the `adId` the Dart side allocates, with events sent back
/// over the same channel. A subclass overrides `create`, `start`, `isReady`,
/// `show` and `destroy` for its ads of type `Ad`.
class FullscreenAdManager<Ad: AnyObject> {

    private let channel: FlutterMethodChannel

    /// The live ads by `adId`.
    private(set) var ads: [Int: Ad] = [:]

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

    /// Builds the ad for `adId`; it is stored before `start` runs.
    func create(_ adId: Int, _ args: [String: Any]) -> Ad {
        preconditionFailure("Subclasses build their ads")
    }

    /// Starts loading `ad` (the Prebid auction, then the MAX load).
    func start(_ adId: Int, _ ad: Ad) {}

    /// Whether `ad` has loaded and can be shown.
    func isReady(_ ad: Ad) -> Bool { false }

    /// Shows `ad` from `viewController`.
    func show(_ ad: Ad, from viewController: UIViewController) {}

    /// Frees `ad`, already removed from `ads`.
    func destroy(_ adId: Int, _ ad: Ad) {}

    // MARK: - Calls

    private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        let adId = (args["adId"] as? NSNumber)?.intValue
        switch call.method {
        case "load":
            guard let adId = adId else { return result(Self.missingAdId) }
            load(adId, args)
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

    // No SDK-initialized guard as on Android: Prebid iOS runs requests made
    // before init.
    private func load(_ adId: Int, _ args: [String: Any]) {
        if let reason = refuseLoad(adId, args) {
            return send(adId, "onAdFailed", ["error": reason])
        }
        // Reloading an adId replaces (and frees) its previous ad.
        release(adId)
        let ad = create(adId, args)
        ads[adId] = ad
        start(adId, ad)
    }

    private func show(_ adId: Int) {
        guard let ad = ads[adId], isReady(ad) else {
            return send(adId, "onAdFailed", ["error": PrebidPresenter.notReady])
        }
        PrebidPresenter.whenReady(fail: { [weak self] error in
            self?.send(adId, "onAdFailed", ["error": error])
        }) { [weak self] viewController in
            // Re-checked: a retry runs later, after a possible destroy.
            guard let self = self else { return }
            guard let ad = self.ads[adId], self.isReady(ad) else {
                return self.send(adId, "onAdFailed", ["error": PrebidPresenter.notReady])
            }
            self.show(ad, from: viewController)
        }
    }

    /// Frees the ad of `adId`, if any.
    func release(_ adId: Int) {
        if let ad = ads.removeValue(forKey: adId) {
            destroy(adId, ad)
        }
    }

    /// Frees every ad: the Dart side restarted (hot restart) and owns none.
    private func releaseAll() {
        ads.keys.forEach { release($0) }
    }

    /// Stops answering calls and frees every ad (engine detached).
    func dispose() {
        channel.setMethodCallHandler(nil)
        releaseAll()
    }

    /// Sends `event` for `adId` with `payload`, on the main thread.
    func send(_ adId: Int, _ event: String, _ payload: [String: Any] = [:]) {
        var arguments = payload
        arguments["adId"] = adId
        onMain { [channel] in channel.invokeMethod(event, arguments: arguments) }
    }

    private static var missingAdId: FlutterError {
        FlutterError(code: "no_ad_id", message: "Missing adId", details: nil)
    }
}
