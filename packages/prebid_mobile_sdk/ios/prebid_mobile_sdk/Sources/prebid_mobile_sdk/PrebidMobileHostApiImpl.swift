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
            if let nonTrackingUrl = nonTrackingUrl {
                // Used instead of serverURL when the user hasn't authorized
                // tracking (ATT).
                try Prebid.initializeSDK(
                    serverURL: prebidServerUrl,
                    nonTrackingURLString: nonTrackingUrl,
                    gadMobileAdsVersion: nil,
                    callback
                )
            } else {
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
        switch level {
        case 0: Prebid.shared.logLevel = .debug
        case 1: Prebid.shared.logLevel = .verbose
        case 2: Prebid.shared.logLevel = .info
        case 3: Prebid.shared.logLevel = .warn
        case 4: Prebid.shared.logLevel = .error
        case 5: Prebid.shared.logLevel = .severe
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
