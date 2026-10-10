import Flutter
import PrebidMobile

/// PrebidMobileHostApi: SDK initialization and the Prebid settings.
/// `releaseAds` destroys every ad of this engine (Dart hot restart).
final class PrebidMobileHostApiImpl: PrebidMobileHostApi {
    private let eventFlutterApi: PrebidEventFlutterApi
    private let releaseAllAds: () -> Void
    // Strong reference: Prebid holds its event delegate weakly.
    private var eventDelegate: BidEventForwarder?

    init(eventFlutterApi: PrebidEventFlutterApi, releaseAds: @escaping () -> Void) {
        self.eventFlutterApi = eventFlutterApi
        self.releaseAllAds = releaseAds
    }

    func releaseAds() throws {
        releaseAllAds()
    }

    func initializeSdk(prebidServerUrl: String, accountId: String, nonTrackingUrl: String?,
                       completion: @escaping (Result<InitializationResult, Error>) -> Void) {
        Prebid.shared.prebidServerAccountId = accountId
        let callback: PrebidInitializationCallback = { status, error in
            let statusStr: String
            switch status {
            // Skipped = setDisableStatusCheck(true); Android reports that as
            // SUCCEEDED, so match it.
            case .succeeded, .serverStatusSkipped: statusStr = "succeeded"
            case .serverStatusWarning: statusStr = "serverStatusWarning"
            default: statusStr = "failed"
            }
            let result = InitializationResult(status: statusStr, error: error?.localizedDescription)
            // The status check replies on Prebid's URLSession queue; channel
            // replies belong on the platform (main) thread.
            if Thread.isMainThread {
                completion(.success(result))
            } else {
                DispatchQueue.main.async { completion(.success(result)) }
            }
        }
        do {
            // With Google Mobile Ads linked, Prebid checks its version is one
            // it supports (a warning in the log otherwise).
            let gmaVersion = linkedGmaVersion()
            switch (nonTrackingUrl, gmaVersion) {
            // The non-tracking URL is used instead of serverURL when the user
            // hasn't authorized tracking (ATT).
            case let (nonTrackingUrl?, gmaVersion?):
                try Prebid.initializeSDK(
                    serverURL: prebidServerUrl,
                    nonTrackingURLString: nonTrackingUrl,
                    gadMobileAdsVersion: gmaVersion,
                    callback
                )
            case let (nonTrackingUrl?, nil):
                try Prebid.initializeSDK(
                    serverURL: prebidServerUrl, nonTrackingURLString: nonTrackingUrl, callback
                )
            case let (nil, gmaVersion?):
                try Prebid.initializeSDK(
                    serverURL: prebidServerUrl, gadMobileAdsVersion: gmaVersion, callback
                )
            case (nil, nil):
                try Prebid.initializeSDK(serverURL: prebidServerUrl, callback)
            }
        } catch {
            let result = InitializationResult(status: "failed", error: error.localizedDescription)
            completion(.success(result))
        }
    }

    func setTimeoutMillis(timeoutMillis: Int64) throws {
        Prebid.shared.timeoutMillis = Int(timeoutMillis)
    }

    func setShareGeoLocation(share: Bool) throws {
        Prebid.shared.shareGeoLocation = share
    }

    func setPbsDebug(enabled: Bool) throws {
        Prebid.shared.pbsDebug = enabled
    }

    func setCustomHeaders(headers: [String: String]) throws {
        Prebid.shared.customHeaders = headers
    }

    func setStoredAuctionResponse(response: String) throws {
        Prebid.shared.storedAuctionResponse = response
        StoredAuctionResponseKeeper.remember(response)
    }

    func clearStoredAuctionResponse() throws {
        // Must be nil, not "" — the SDK serializes an empty string into the request.
        Prebid.shared.storedAuctionResponse = nil
        StoredAuctionResponseKeeper.remember(nil)
    }

    func addStoredBidResponse(bidder: String, responseId: String) throws {
        Prebid.shared.addStoredBidResponse(bidder: bidder, responseId: responseId)
    }

    func clearStoredBidResponses() throws {
        Prebid.shared.clearStoredBidResponses()
    }

    func setLogLevel(level: Int64) throws {
        configureLogger { $0.silenced = level == 6 }
        switch level {
        case 0: Prebid.shared.logLevel = .debug
        case 1: Prebid.shared.logLevel = .verbose
        case 2: Prebid.shared.logLevel = .info
        case 3: Prebid.shared.logLevel = .warn
        case 4: Prebid.shared.logLevel = .error
        case 5, 6: Prebid.shared.logLevel = .severe // 6 = none: PluginLogger drops everything.
        default: Prebid.shared.logLevel = .debug // As Android.
        }
    }

    func setCreativeFactoryTimeout(timeout: Int64) throws {
        Prebid.shared.creativeFactoryTimeout = TimeInterval(timeout) / 1000.0
    }

    func setCreativeFactoryTimeoutPreRenderContent(timeout: Int64) throws {
        Prebid.shared.creativeFactoryTimeoutPreRenderContent = TimeInterval(timeout) / 1000.0
    }

    // Seconds natively; milliseconds over the channel, like Android.
    func getCreativeFactoryTimeout() throws -> Int64 {
        Int64((Prebid.shared.creativeFactoryTimeout * 1000).rounded())
    }

    func getCreativeFactoryTimeoutPreRenderContent() throws -> Int64 {
        Int64((Prebid.shared.creativeFactoryTimeoutPreRenderContent * 1000).rounded())
    }

    func setPrebidServerAccountId(accountId: String) throws {
        Prebid.shared.prebidServerAccountId = accountId
    }

    func getPrebidServerAccountId() throws -> String {
        Prebid.shared.prebidServerAccountId
    }

    func setPrebidServerUrl(url: String) throws {
        // Throws prebidServerURLInvalid for a malformed URL. A nil
        // non-tracking URL leaves the one given to initializeSdk in place.
        try Host.shared.setHostURL(url, nonTrackingURLString: nil)
    }

    func getPrebidServerUrl() throws -> String? {
        // The URL auctions use now: the non-tracking one without ATT consent.
        try? Host.shared.getHostURL()
    }

    func setUseCacheForReportingWithRenderingApi(use: Bool) throws {
        Prebid.shared.useCacheForReportingWithRenderingAPI = use
    }

    func getUseCacheForReportingWithRenderingApi() throws -> Bool {
        Prebid.shared.useCacheForReportingWithRenderingAPI
    }

    func setCustomStatusEndpoint(endpoint: String) throws {
        Prebid.shared.customStatusEndpoint = endpoint
    }

    func setShouldAssignNativeAssetId(assign: Bool) throws {
        Prebid.shared.shouldAssignNativeAssetID = assign
    }

    func setFilterOutUncachedBids(filter: Bool) throws {
        Prebid.shared.filterOutUncachedBids = filter
    }

    func setEidsPlacement(placement: String) throws {
        switch placement {
        case "openRtb26": Prebid.shared.eidsPlacement = .openRTB26
        case "openRtb25": Prebid.shared.eidsPlacement = .openRTB25
        default: Prebid.shared.eidsPlacement = .compatible
        }
    }

    func setIncludeWinners(include: Bool) throws {
        Prebid.shared.includeWinners = include
    }

    func setIncludeBidderKeys(include: Bool) throws {
        Prebid.shared.includeBidderKeys = include
    }

    func setAuctionSettingsId(settingsId: String?) throws {
        Prebid.shared.auctionSettingsId = settingsId
    }

    func setDisableStatusCheck(disable: Bool) throws {
        Prebid.shared.shouldDisableStatusCheck = disable
    }

    func setEventDelegateEnabled(enabled: Bool) throws {
        guard enabled else { return clearEventDelegate() }
        let forwarder = BidEventForwarder(api: eventFlutterApi)
        eventDelegate = forwarder
        Prebid.shared.eventDelegate = forwarder
    }

    // Prebid iOS has no "none" level and logs through one replaceable logger:
    // a PluginLogger stands in while logs go to Dart or nowhere.
    private var logger: PluginLogger?

    func setLogListenerEnabled(enabled: Bool) throws {
        configureLogger { [eventFlutterApi] in $0.api = enabled ? eventFlutterApi : nil }
    }

    /// Stops sending logs to this engine's Dart side (plugin detach).
    func clearLogger() {
        configureLogger { $0.api = nil }
    }

    private func configureLogger(_ change: (PluginLogger) -> Void) {
        let logger = self.logger ?? PluginLogger()
        change(logger)
        if logger.api == nil && !logger.silenced {
            // Back to Prebid's console logger (only if this engine replaced it).
            if self.logger != nil { Log.setCustomLogger(SDKConsoleLogger()) }
            self.logger = nil
        } else {
            if self.logger == nil { Log.setCustomLogger(logger) }
            self.logger = logger
        }
    }

    func setLocationUpdatesEnabled(enabled: Bool) throws {
        Prebid.shared.locationUpdatesEnabled = enabled
    }

    func getLocationUpdatesEnabled() throws -> Bool? { Prebid.shared.locationUpdatesEnabled }

    func setDebugLogFileEnabled(enabled: Bool) throws {
        Prebid.shared.debugLogFileEnabled = enabled
    }

    func getDebugLogFileEnabled() throws -> Bool? { Prebid.shared.debugLogFileEnabled }

    func getTimeoutMillisDynamic() throws -> Int64? {
        Prebid.shared.timeoutMillisDynamic.map { $0.int64Value }
    }

    /// Drops this engine's delegate. Prebid has a single process-wide one, so
    /// it's only cleared there while it is still this engine's: another
    /// engine (add-to-app) may have set its own since.
    func clearEventDelegate() {
        guard let own = eventDelegate else { return }
        eventDelegate = nil
        if Prebid.shared.eventDelegate === own { Prebid.shared.eventDelegate = nil }
    }

    // SharedID
    func setSendSharedId(send: Bool) throws {
        Targeting.shared.sendSharedId = send
    }

    func getSharedId() throws -> ExternalUserIdData? {
        let id = Targeting.shared.sharedId
        return id.uids.isEmpty ? nil : id.data
    }

    func resetSharedId() throws {
        Targeting.shared.resetSharedId()
    }

    // External User IDs
    func setExternalUserIds(userIds: [ExternalUserIdData]) throws {
        let externalIds = userIds.map { data -> ExternalUserId in
            let uids = data.uids.compactMap { $0 }.map { uid in
                UserUniqueID(
                    uniqueId: uid.id,
                    aType: NSNumber(value: uid.atype),
                    ext: uid.ext?.stringKeys
                )
            }
            let eid = ExternalUserId(source: data.source, uids: uids, ext: data.ext?.stringKeys)
            eid.inserter = data.inserter
            eid.matcher = data.matcher
            eid.mm = data.mm.map { NSNumber(value: $0) }
            return eid
        }
        Targeting.shared.setExternalUserIds(externalIds)
    }

    func getExternalUserIds() throws -> [ExternalUserIdData] {
        // Prebid iOS returns the ids as their JSON dictionaries.
        (Targeting.shared.getExternalUserIds() ?? []).compactMap { dict in
            guard let source = dict["source"] as? String,
                  let uids = dict["uids"] as? [[String: Any]] else { return nil }
            return ExternalUserIdData(
                source: source,
                uids: uids.map { uid in
                    UserUniqueIdData(
                        id: uid["id"] as? String ?? "",
                        atype: (uid["atype"] as? NSNumber)?.int64Value ?? 0,
                        ext: (uid["ext"] as? [String: Any])?.pigeonKeys
                    )
                },
                ext: (dict["ext"] as? [String: Any])?.pigeonKeys,
                inserter: dict["inserter"] as? String,
                matcher: dict["matcher"] as? String,
                mm: (dict["mm"] as? NSNumber)?.int64Value
            )
        }
    }

    func clearExternalUserIds() throws {
        Targeting.shared.setExternalUserIds([])
    }

    func getTimeoutMillis() throws -> Int64 { Int64(Prebid.shared.timeoutMillis) }
    func getPbsDebug() throws -> Bool { Prebid.shared.pbsDebug }
    func getShareGeoLocation() throws -> Bool { Prebid.shared.shareGeoLocation }
    func getCustomHeaders() throws -> [String: String] { Prebid.shared.customHeaders }
    func getStoredAuctionResponse() throws -> String? { Prebid.shared.storedAuctionResponse }
    func getStoredBidResponses() throws -> [String: String] { Prebid.shared.storedBidResponses }
    func getCustomStatusEndpoint() throws -> String? { Prebid.shared.customStatusEndpoint }
    func getShouldAssignNativeAssetId() throws -> Bool { Prebid.shared.shouldAssignNativeAssetID }
    func getFilterOutUncachedBids() throws -> Bool { Prebid.shared.filterOutUncachedBids }
    func getIncludeWinners() throws -> Bool { Prebid.shared.includeWinners }
    func getIncludeBidderKeys() throws -> Bool { Prebid.shared.includeBidderKeys }
    func getAuctionSettingsId() throws -> String? { Prebid.shared.auctionSettingsId }
    func getDisableStatusCheck() throws -> Bool { Prebid.shared.shouldDisableStatusCheck }

    func getEidsPlacement() throws -> String {
        switch Prebid.shared.eidsPlacement {
        case .openRTB26: return "openRtb26"
        case .openRTB25: return "openRtb25"
        default: return "compatible"
        }
    }

    func getSdkVersion() throws -> String {
        return Prebid.shared.version
    }

    func getOmsdkVersion() throws -> String {
        Prebid.shared.omsdkVersion
    }
}

/// Prebid's logger while the plugin routes its logs: to Dart (`api`) or
/// nowhere (`silenced`, PrebidLogLevel.none).
final class PluginLogger: NSObject, PrebidLogger {
    var api: PrebidEventFlutterApi?
    var silenced = false

    func error(_ object: Any, filename: String, line: Int, function: String) { send(object, .error) }
    func info(_ object: Any, filename: String, line: Int, function: String) { send(object, .info) }
    func debug(_ object: Any, filename: String, line: Int, function: String) { send(object, .debug) }
    func verbose(_ object: Any, filename: String, line: Int, function: String) { send(object, .verbose) }
    func warn(_ object: Any, filename: String, line: Int, function: String) { send(object, .warn) }
    func severe(_ object: Any, filename: String, line: Int, function: String) { send(object, .severe) }
    func whereAmI(filename: String, line: Int, function: String) {}

    /// Prebid logs from any queue; Flutter channels need main. The LogLevel
    /// raw values match the Dart PrebidLogLevel indexes.
    private func send(_ object: Any, _ level: LogLevel) {
        guard !silenced, let api = api, level.rawValue >= Log.logLevel.rawValue else { return }
        let message = "\(object)"
        DispatchQueue.main.async {
            api.onLog(level: Int64(level.rawValue), message: message) { _ in }
        }
    }
}

/// `PrebidEventDelegate` → Flutter. Prebid calls it on a background queue.
final class BidEventForwarder: NSObject, PrebidEventDelegate {
    private let api: PrebidEventFlutterApi

    init(api: PrebidEventFlutterApi) {
        self.api = api
    }

    func prebidBidRequestDidFinish(requestData: Data?, responseData: Data?) {
        let request = requestData.flatMap { String(data: $0, encoding: .utf8) }
        let response = responseData.flatMap { String(data: $0, encoding: .utf8) }
        DispatchQueue.main.async { [api] in
            api.onBidResponse(request: request, response: response) { _ in }
        }
    }
}

private extension ExternalUserId {
    var data: ExternalUserIdData {
        ExternalUserIdData(
            source: source,
            uids: uids.map { UserUniqueIdData(id: $0.uniqueId, atype: $0.aType.int64Value, ext: $0.ext?.pigeonKeys) },
            ext: ext?.pigeonKeys,
            inserter: inserter,
            matcher: matcher,
            mm: mm?.int64Value
        )
    }
}

private extension Dictionary where Key == String?, Value == Any? {
    /// The map without its null keys and values, as Prebid wants it.
    var stringKeys: [String: Any] {
        reduce(into: [:]) { result, entry in
            if let key = entry.key, let value = entry.value { result[key] = value }
        }
    }
}

private extension Dictionary where Key == String, Value == Any {
    /// The map typed as a Pigeon map.
    var pigeonKeys: [String?: Any?] { reduce(into: [:]) { $0[$1.key] = $1.value } }
}

/// The version of the Google Mobile Ads SDK linked into the app ("12.2.0"),
/// read through the Objective-C runtime so the plugin needn't depend on it;
/// nil without it.
func linkedGmaVersion() -> String? {
    guard let mobileAds = NSClassFromString("GADMobileAds") as AnyObject?,
          mobileAds.responds(to: NSSelectorFromString("sharedInstance")),
          let shared = mobileAds.perform(NSSelectorFromString("sharedInstance"))?
              .takeUnretainedValue() as? NSObject,
          shared.responds(to: NSSelectorFromString("versionNumber")),
          let value = shared.value(forKey: "versionNumber") as? NSValue,
          // GADVersionNumber: major, minor and patch NSIntegers.
          String(cString: value.objCType).hasSuffix("=qqq}")
    else { return nil }
    var version = (0, 0, 0)
    value.getValue(&version, size: MemoryLayout<(Int, Int, Int)>.size)
    return "\(version.0).\(version.1).\(version.2)"
}
