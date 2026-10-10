import Foundation
import CoreGraphics
import Flutter
import UIKit
import PrebidMobile
import AppLovinSDK

// Helpers for the values the Dart side sends over method channels:
// `NativeAsset.toMap()`, `NativeEventTracker.toMap()`,
// `PrebidFullscreenControls.toMap()` and `VideoParameters.toMap()` from
// prebid_mobile_sdk.

private func intValue(_ raw: Any?) -> Int? { (raw as? NSNumber)?.intValue }

/// Formats Prebid errors, appending `localizedFailureReason` (the real server
/// response) which the SDK hides behind a generic `localizedDescription`.
/// Same as the core plugin's.
enum PrebidErrorFormatter {
    static func describe(_ error: Error?) -> String {
        guard let error = error else { return "Unknown error" }
        let nsError = error as NSError
        let description = nsError.localizedDescription
        if let reason = nsError.localizedFailureReason,
           !reason.isEmpty,
           reason != description {
            return "\(description): \(reason)"
        }
        return description
    }

    /// A MAX error's message (`MAError` is no `Error`), with the same
    /// fallback.
    static func describe(_ error: MAError?) -> String {
        guard let message = error?.message, !message.isEmpty else { return "Unknown error" }
        return message
    }
}

/// Finds the view controller to present fullscreen ads from: the top-most
/// presented controller of the foreground key window (scene-aware;
/// `UIApplication.keyWindow` is deprecated and nil in multi-scene apps).
/// A port of the core plugin's.
enum PrebidPresenter {
    static func topViewController() -> UIViewController? {
        // Prefer the active scene, but fall back to an inactive one: the
        // scene is inactive while a system alert (e.g. ATT) or Notification
        // Center is over the app, and when returning from the background.
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = (scenes.filter { $0.activationState == .foregroundActive }
            + scenes.filter { $0.activationState == .foregroundInactive })
            .flatMap { $0.windows }
        let window = windows.first { $0.isKeyWindow } ?? windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }

    /// Calls `present` with a controller that can present now, or `fail`
    /// with the reason. A controller still presenting or dismissing another
    /// makes UIKit drop the presentation with only a console warning, after
    /// MAX has already reported the ad as displayed; so that case waits
    /// once for the running transition (or the next run loop), then fails.
    static func whenReady(
        retry: Bool = true,
        fail: @escaping (String) -> Void,
        present: @escaping (UIViewController) -> Void
    ) {
        guard let top = topViewController() else { return fail(noViewController) }
        guard isBusy(top) else { return present(top) }
        guard retry else { return fail(busy) }
        let again = {
            DispatchQueue.main.async {
                PrebidPresenter.whenReady(retry: false, fail: fail, present: present)
            }
        }
        if let coordinator = (top.presentedViewController ?? top).transitionCoordinator {
            _ = coordinator.animate(alongsideTransition: nil) { _ in again() }
        } else {
            again()
        }
    }

    private static func isBusy(_ controller: UIViewController) -> Bool {
        controller.presentedViewController != nil
            || controller.isBeingPresented
            || controller.isBeingDismissed
    }

    static let noViewController = "No view controller to present the ad from"
    static let notReady = "The ad is not loaded"
    static let busy = "Another view controller is being presented; try again after it is dismissed"
}

/// Runs `body` on the main thread: Flutter channels must be called there,
/// and not every SDK callback arrives on it.
func onMain(_ body: @escaping () -> Void) {
    if Thread.isMainThread {
        body()
    } else {
        DispatchQueue.main.async(execute: body)
    }
}

/// The method channel of a platform view: `<prefix>_<channelId>`, the id the
/// Dart widget listens on before the view exists (so a failure reported
/// during creation is not lost). Falls back to the platform view id.
func viewChannel(_ prefix: String, args: [String: Any], viewId: Int64, messenger: FlutterBinaryMessenger) -> FlutterMethodChannel {
    let channelId = (args["channelId"] as? NSNumber)?.int64Value ?? viewId
    return FlutterMethodChannel(name: "\(prefix)_\(channelId)", binaryMessenger: messenger)
}

/// Native request assets, or nil when the widget uses the defaults.
func nativeAssetsFrom(_ raw: Any?) -> [NativeAsset]? {
    guard let list = raw as? [[String: Any]] else { return nil }
    return list.compactMap { m -> NativeAsset? in
        let required = m["required"] as? Bool ?? false
        switch m["assetType"] as? String {
        case "title":
            return NativeAssetTitle(length: intValue(m["titleLength"]) ?? 90, required: required)
        case "image":
            let image = NativeAssetImage(isRequired: required)
            if let t = intValue(m["imageType"]) { image.type = ImageAsset(integerLiteral: t) }
            if let w = intValue(m["imageWidth"]) { image.width = w }
            if let h = intValue(m["imageHeight"]) { image.height = h }
            if let w = intValue(m["imageWidthMin"]) { image.widthMin = w }
            if let h = intValue(m["imageHeightMin"]) { image.heightMin = h }
            return image
        case "data":
            guard let t = intValue(m["dataType"]), let type = DataAsset(rawValue: t) else { return nil }
            let data = NativeAssetData(type: type, required: required)
            if let len = intValue(m["dataLength"]) { data.length = len }
            return data
        default:
            return nil
        }
    }
}

/// Native event trackers, or nil when the widget uses the defaults.
func nativeTrackersFrom(_ raw: Any?) -> [NativeEventTracker]? {
    guard let list = raw as? [[String: Any]] else { return nil }
    return list.compactMap { m -> NativeEventTracker? in
        guard let event = intValue(m["eventType"]) else { return nil }
        let methods = (m["methods"] as? [NSNumber] ?? []).map { EventTracking(integerLiteral: $0.intValue) }
        return NativeEventTracker(event: EventType(integerLiteral: event), methods: methods)
    }
}

/// Copies `VideoParameters.toMap()` onto an ad unit's `videoParameters`, which
/// Prebid exposes get-only (it is configured in place). Absent keys keep the
/// SDK defaults.
func applyVideoParameters(_ raw: Any?, to vp: VideoParameters) {
    guard let m = raw as? [String: Any] else { return }
    func ints(_ key: String) -> [Int]? { (m[key] as? [NSNumber])?.map { $0.intValue } }

    if let mimes = m["mimes"] as? [String], !mimes.isEmpty { vp.mimes = mimes }
    if let v = ints("protocols") { vp.protocols = v.map { Signals.Protocols(integerLiteral: $0) } }
    if let v = ints("playbackMethods") { vp.playbackMethod = v.map { Signals.PlaybackMethod(integerLiteral: $0) } }
    if let v = ints("api") { vp.api = v.map { Signals.Api(integerLiteral: $0) } }
    if let v = intValue(m["placement"]) { vp.placement = Signals.Placement(integerLiteral: v) }
    if let v = intValue(m["plcmt"]) { vp.plcmnt = Signals.Plcmnt(integerLiteral: v) }
    if let v = intValue(m["startDelay"]) { vp.startDelay = Signals.StartDelay(integerLiteral: v) }
    if let v = intValue(m["linearity"]) { vp.linearity = SingleContainerInt(integerLiteral: v) }
    if let v = ints("battr") { vp.battr = v.map { Signals.CreativeAttribute(integerLiteral: $0) } }
    if let v = m["skippable"] as? Bool { vp.isSkippable = v }
    if let v = intValue(m["maxDuration"]) { vp.maxDuration = SingleContainerInt(integerLiteral: v) }
    if let v = intValue(m["minDuration"]) { vp.minDuration = SingleContainerInt(integerLiteral: v) }
    if let v = intValue(m["maxBitrate"]) { vp.maxBitrate = SingleContainerInt(integerLiteral: v) }
    if let v = intValue(m["minBitrate"]) { vp.minBitrate = SingleContainerInt(integerLiteral: v) }
}

/// `debugDropBidProbability` (`PrebidMax.debugDropBidProbability`, testing
/// only), clamped to `0...1`; 0 when absent.
func debugDropBidProbability(_ raw: Any?) -> Double {
    guard let p = (raw as? NSNumber)?.doubleValue, !p.isNaN else { return 0 }
    return min(max(p, 0), 1)
}

/// Testing hook: whether to withhold this load's Prebid bid from MAX, with
/// `probability`. Android's test app sets the response-id local extra to ""
/// there; Prebid iOS passes the bid object itself, so the caller clears the
/// `PBMMediationAdUnitBidKey` local extra instead — the Prebid MAX adapter
/// then finds no bid and MAX falls back to its waterfall.
func shouldDropBid(_ probability: Double) -> Bool {
    probability > 0 && Double.random(in: 0..<1) < probability
}

/// The `onAdRevenuePaid` payload (`PrebidMaxAdRevenue` on the Dart side).
func revenuePayload(_ ad: MAAd) -> [String: Any] {
    var payload: [String: Any] = [
        "revenue": ad.revenue,
        "revenuePrecision": ad.revenuePrecision,
        "networkName": ad.networkName,
    ]
    if let placement = ad.placement { payload["placement"] = placement }
    return payload
}

/// `adFormats` (`PrebidAdFormat` names), or `nil` when it names none.
func adFormatsFrom(_ raw: Any?) -> Set<PrebidMobile.AdFormat>? {
    let names = raw as? [String] ?? []
    var formats = Set<PrebidMobile.AdFormat>()
    if names.contains("banner") { formats.insert(.banner) }
    if names.contains("video") { formats.insert(.video) }
    return formats.isEmpty ? nil : formats
}

/// Interstitial formats: `adFormats` when it names any, else video or banner
/// from `isVideo`.
func adFormatsFrom(_ raw: Any?, isVideo: Bool) -> Set<PrebidMobile.AdFormat> {
    adFormatsFrom(raw) ?? (isVideo ? [.video] : [.banner])
}

/// Fullscreen rendering controls (`PrebidFullscreenControls`).
struct FullscreenControls {
    let closeButtonArea: Double?
    let closeButtonPosition: Position?
    let skipButtonArea: Double?
    let skipButtonPosition: Position?
    let skipDelay: Double?
    let isMuted: Bool?
    let isSoundButtonVisible: Bool?
    let isAutoCloseOnCompletionEnabled: Bool?
    let minSizePercentage: CGSize?

    init?(_ raw: Any?) {
        guard let m = raw as? [String: Any] else { return nil }
        closeButtonArea = (m["closeButtonArea"] as? NSNumber)?.doubleValue
        closeButtonPosition = FullscreenControls.position(m["closeButtonPosition"])
        skipButtonArea = (m["skipButtonArea"] as? NSNumber)?.doubleValue
        skipButtonPosition = FullscreenControls.position(m["skipButtonPosition"])
        skipDelay = (m["skipDelay"] as? NSNumber)?.doubleValue
        isMuted = m["isMuted"] as? Bool
        isSoundButtonVisible = m["isSoundButtonVisible"] as? Bool
        isAutoCloseOnCompletionEnabled = m["isAutoCloseOnCompletionEnabled"] as? Bool
        if let w = intValue(m["minWidthPercentage"]), let h = intValue(m["minHeightPercentage"]) {
            minSizePercentage = CGSize(width: w, height: h)
        } else {
            minSizePercentage = nil
        }
    }

    private static func position(_ raw: Any?) -> Position? {
        switch raw as? String {
        case "topLeft": return .topLeft
        case "topRight": return .topRight
        default: return nil
        }
    }
}

extension FullscreenControls {
    // `supportSKOverlay` has no mediation equivalent: Prebid's mediation ad
    // units don't expose it (AdMob / AppLovin render the ad), so it is ignored.
    func apply(to adUnit: MediationBaseInterstitialAdUnit) {
        if let v = closeButtonArea { adUnit.closeButtonArea = v }
        if let v = closeButtonPosition { adUnit.closeButtonPosition = v }
        if let v = isMuted { adUnit.isMuted = v }
        if let v = isSoundButtonVisible { adUnit.isSoundButtonVisible = v }
        // Skip / auto-close exist on interstitials only (none on rewarded).
        if let interstitial = adUnit as? MediationInterstitialAdUnit {
            if let v = skipButtonArea { interstitial.skipButtonArea = v }
            if let v = skipButtonPosition { interstitial.skipButtonPosition = v }
            if let v = skipDelay { interstitial.skipDelay = v }
            if let v = isAutoCloseOnCompletionEnabled { interstitial.isAutoCloseOnCompletionEnabled = v }
        }
    }
}
