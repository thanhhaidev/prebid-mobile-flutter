import CoreGraphics
import Foundation
import PrebidMobile
import UIKit

// Parsing of the values the Dart side sends over method channels
// (`NativeParameters.toMap()`, `PrebidFullscreenControls.toMap()`,
// `VideoParameters.toMap()`) and the presenting / error helpers, the same in
// every companion package: tool/check_copies.sh keeps the three copies
// identical.

func intValue(_ raw: Any?) -> Int? { (raw as? NSNumber)?.intValue }

/// Formats Prebid errors, appending `localizedFailureReason` (the real server
/// response) which the SDK hides behind a generic `localizedDescription`.
/// A port of the core plugin's.
enum PrebidErrorFormatter {
    static func describe(_ error: Error?) -> String {
        guard let error = error else { return "Unknown error" }
        let nsError = error as NSError
        let description = nsError.localizedDescription
        if let reason = nsError.localizedFailureReason,
            !reason.isEmpty,
            reason != description
        {
            return "\(description): \(reason)"
        }
        return description
    }
}

/// Finds the view controller to present fullscreen ads and modals from: the
/// top-most presented controller of the foreground key window (scene-aware;
/// `UIApplication.keyWindow` is deprecated and nil in multi-scene apps).
/// A port of the core plugin's.
enum PrebidPresenter {
    /// The top-most presented controller of `window` (the Flutter engine's
    /// own, or the ad view's, so a multi-window iPad or an add-to-app
    /// secondary scene presents in the right place), or of the foreground
    /// key window when `window` is nil or has no root.
    static func topViewController(in window: UIWindow? = nil) -> UIViewController? {
        var top = window?.rootViewController ?? keyWindow()?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }

    private static func keyWindow() -> UIWindow? {
        // Prefer the active scene, but fall back to an inactive one: the
        // scene is inactive while a system alert (e.g. ATT) or Notification
        // Center is over the app, and when returning from the background.
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows =
            (scenes.filter { $0.activationState == .foregroundActive }
            + scenes.filter { $0.activationState == .foregroundInactive })
            .flatMap { $0.windows }
        return windows.first { $0.isKeyWindow } ?? windows.first
    }

    /// Calls `present` with a controller that can present now, or `fail`
    /// with the reason. A controller still presenting or dismissing another
    /// makes UIKit drop the presentation with only a console warning, after
    /// the ad has already been reported as displayed; so that case waits
    /// once for the running transition (or the next run loop), then fails.
    static func whenReady(
        in window: UIWindow? = nil,
        retry: Bool = true,
        fail: @escaping (String) -> Void,
        present: @escaping (UIViewController) -> Void
    ) {
        guard let top = topViewController(in: window) else { return fail(noViewController) }
        guard isBusy(top) else { return present(top) }
        guard retry else { return fail(busy) }
        var retried = false
        let again = {
            guard !retried else { return }
            retried = true
            DispatchQueue.main.async {
                PrebidPresenter.whenReady(in: window, retry: false, fail: fail, present: present)
            }
        }
        // UIKit doesn't call the completion when it can't queue it (false).
        let queued =
            (top.presentedViewController ?? top).transitionCoordinator?
            .animate(alongsideTransition: nil) { _ in again() } ?? false
        if !queued { again() }
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

/// Native request assets, or nil when the widget uses the defaults.
func nativeAssetsFrom(_ raw: Any?) -> [NativeAsset]? {
    guard let list = raw as? [[String: Any]] else { return nil }
    return list.compactMap { m -> NativeAsset? in
        let required = m["required"] as? Bool ?? false
        // Prebid iOS has no asset-level ext: `assetExt` is Android only.
        let ext = jsonValue(m["ext"])
        switch m["assetType"] as? String {
        case "title":
            let title = NativeAssetTitle(length: intValue(m["titleLength"]) ?? 90, required: required)
            title.ext = ext
            return title
        case "image":
            let image = NativeAssetImage(isRequired: required)
            if let t = intValue(m["imageType"]) { image.type = ImageAsset(integerLiteral: t) }
            if let w = intValue(m["imageWidth"]) { image.width = w }
            if let h = intValue(m["imageHeight"]) { image.height = h }
            if let w = intValue(m["imageWidthMin"]) { image.widthMin = w }
            if let h = intValue(m["imageHeightMin"]) { image.heightMin = h }
            if let mimes = m["imageMimes"] as? [String] { image.mimes = mimes }
            image.ext = ext
            return image
        case "data":
            guard let t = intValue(m["dataType"]), let type = DataAsset(rawValue: t) else { return nil }
            let data = NativeAssetData(type: type, required: required)
            if let len = intValue(m["dataLength"]) { data.length = len }
            data.ext = ext
            return data
        default:
            return nil
        }
    }
}

/// A JSON object string (`jsonEncode` in Dart) as a dictionary, or nil.
func jsonDictionary(_ raw: Any?) -> [String: Any]? {
    guard let data = (raw as? String)?.data(using: .utf8) else { return nil }
    return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
}

private func jsonValue(_ raw: Any?) -> AnyObject? {
    jsonDictionary(raw) as NSDictionary?
}

/// Native event trackers, or nil when the widget uses the defaults. Their
/// `ext` is dropped: Prebid iOS doesn't send it.
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
    let supportSKOverlay: Bool?
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
        supportSKOverlay = m["supportSKOverlay"] as? Bool
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

/// Impression-level ORTB JSON with `ext.data.pbadslot` set to [pbAdSlot]
/// (unless the JSON already sets one), for ad units without a pbAdSlot setter.
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

/// Configures an AdMob / MAX native unit from the Dart widget's `args`
/// (`NativeParameters.toMap()` and the ORTB configs). Unset, it requests
/// Prebid's reference assets, impression trackers (image + JS) and the
/// social / general social / in-feed context, as on Android.
func configureMediationNative(_ adUnit: MediationNativeAdUnit, args: [String: Any]) {
    adUnit.addNativeAssets(nativeAssetsFrom(args["assets"]) ?? mediationNativeAssets())
    adUnit.setContextType(.Social)
    adUnit.setPlacementType(.FeedContent)
    adUnit.setContextSubType(.Social)
    if let v = args["context"] as? Int { adUnit.setContextType(ContextType(integerLiteral: v)) }
    if let v = args["contextSubType"] as? Int { adUnit.setContextSubType(ContextSubType(integerLiteral: v)) }
    if let v = args["placementType"] as? Int { adUnit.setPlacementType(PlacementType(integerLiteral: v)) }
    if let v = intValue(args["placementCount"]) { adUnit.setPlacementCount(v) }
    if let v = intValue(args["sequence"]) { adUnit.setSequence(v) }
    if let v = args["assetUrlSupport"] as? Bool { adUnit.setAssetURLSupport(v ? 1 : 0) }
    if let v = args["dUrlSupport"] as? Bool { adUnit.setDURLSupport(v ? 1 : 0) }
    if let v = args["privacy"] as? Bool { adUnit.setPrivacy(v ? 1 : 0) }
    if let v = jsonDictionary(args["ext"]) { adUnit.setExt(v) }
    if let v = args["impOrtbConfig"] as? String { adUnit.setImpORTBConfig(v) }
    if let v = args["globalOrtbConfig"] as? String { adUnit.setGlobalORTBConfig(v) }
    adUnit.addEventTracker(
        nativeTrackersFrom(args["eventTrackers"]) ?? [
            NativeEventTracker(event: .Impression, methods: [.Image, .js])
        ])
}

/// Prebid's reference native request: title, icon, sponsored, body and call
/// to action.
private func mediationNativeAssets() -> [NativeAsset] {
    let icon = NativeAssetImage(minimumWidth: 20, minimumHeight: 20, required: true)
    icon.type = ImageAsset.Icon
    let title = NativeAssetTitle(length: 90, required: true)
    let body = NativeAssetData(type: DataAsset.description, required: true)
    let cta = NativeAssetData(type: DataAsset.ctatext, required: true)
    let sponsored = NativeAssetData(type: DataAsset.sponsored, required: true)
    return [title, icon, sponsored, body, cta]
}

/// `additionalSizes`: a flat `[w, h, w, h, ...]` list of extra banner sizes.
func additionalSizesFrom(_ raw: Any?) -> [CGSize] {
    let flat = (raw as? [NSNumber] ?? []).map { $0.intValue }
    return stride(from: 0, to: flat.count - 1, by: 2).map {
        CGSize(width: flat[$0], height: flat[$0 + 1])
    }
}

/// `adPosition` (a `PrebidAdPosition` value), when it names one.
func adPositionFrom(_ raw: Any?) -> AdPosition? {
    (raw as? Int).flatMap { AdPosition(rawValue: $0) }
}

/// `refreshIntervalSeconds` as a Prebid iOS refresh interval. Prebid
/// refreshes every 60 s by default, and `AdUnitConfig` clamps 0 up to its
/// 15 s minimum: only a negative value is stored as 0, which disables
/// auto-refresh (parity with Android, where unset or 0 means none).
/// Positive values are clamped by Prebid to 15–120 s.
func prebidRefreshInterval(_ raw: Any?) -> TimeInterval {
    guard let seconds = raw as? Int, seconds > 0 else { return -1 }
    return TimeInterval(seconds)
}

/// Configures an AdMob / MAX banner unit from the Dart widget's `args`.
func configureMediationBanner(_ adUnit: MediationBannerAdUnit, args: [String: Any]) {
    if let pos = adPositionFrom(args["adPosition"]) { adUnit.adPosition = pos }
    // Prebid iOS has no pbAdSlot setter on this ad unit: send it in the imp.
    if let config = impOrtb(args["impOrtbConfig"] as? String, pbAdSlot: args["pbAdSlot"] as? String) {
        adUnit.setImpORTBConfig(config)
    }
    if let config = args["globalOrtbConfig"] as? String { adUnit.setGlobalORTBConfig(config) }
    if let formats = adFormatsFrom(args["adFormats"]) { adUnit.adFormats = formats }
    // `videoParameters` is a live, get-only reference: configured in place.
    applyVideoParameters(args["videoParameters"], to: adUnit.videoParameters)
    let additionalSizes = additionalSizesFrom(args["additionalSizes"])
    if !additionalSizes.isEmpty { adUnit.additionalSizes = additionalSizes }
    adUnit.refreshInterval = prebidRefreshInterval(args["refreshIntervalSeconds"])
}

func impOrtb(_ json: String?, pbAdSlot: String?) -> String? {
    guard let pbAdSlot = pbAdSlot else { return json }
    let data = json.flatMap { $0.data(using: .utf8) }
    var imp = data.flatMap { (try? JSONSerialization.jsonObject(with: $0)) as? [String: Any] } ?? [:]
    var ext = imp["ext"] as? [String: Any] ?? [:]
    var extData = ext["data"] as? [String: Any] ?? [:]
    if extData["pbadslot"] == nil { extData["pbadslot"] = pbAdSlot }
    ext["data"] = extData
    imp["ext"] = ext
    return (try? JSONSerialization.data(withJSONObject: imp)).flatMap { String(data: $0, encoding: .utf8) } ?? json
}
