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
        default: Prebid.shared.logLevel = .info
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
        if enabled {
            let forwarder = BidEventForwarder(api: eventFlutterApi)
            eventDelegate = forwarder
            Prebid.shared.eventDelegate = forwarder
        } else {
            Prebid.shared.eventDelegate = nil
            eventDelegate = nil
        }
    }

    // SharedID
    func setSendSharedId(send: Bool) throws {
        Targeting.shared.sendSharedId = send
    }

    func getSharedId() throws -> ExternalUserIdData? {
        let id = Targeting.shared.sharedId
        guard let uid = id.uids.first else { return nil }
        return ExternalUserIdData(
            source: id.source,
            identifier: uid.uniqueId,
            atype: uid.aType.int64Value
        )
    }

    func resetSharedId() throws {
        Targeting.shared.resetSharedId()
    }

    // External User IDs
    func setExternalUserIds(userIds: [ExternalUserIdData]) throws {
        let externalIds = userIds.map { data -> ExternalUserId in
            // ext goes on the uid, matching the Android mapping.
            let ext = data.ext?.reduce(into: [String: Any]()) { result, entry in
                if let key = entry.key, let value = entry.value { result[key] = value }
            }
            let uid = UserUniqueID(
                uniqueId: data.identifier,
                aType: NSNumber(value: data.atype ?? 0),
                ext: ext
            )
            let eid = ExternalUserId(source: data.source, uids: [uid])
            eid.inserter = data.inserter
            eid.matcher = data.matcher
            eid.mm = data.mm.map { NSNumber(value: $0) }
            return eid
        }
        Targeting.shared.setExternalUserIds(externalIds)
    }

    func getExternalUserIds() throws -> [ExternalUserIdData] {
        guard let ids = Targeting.shared.getExternalUserIds() else { return [] }
        // One entry per uid (like Android), carrying the uid's ext.
        return ids.flatMap { dict -> [ExternalUserIdData] in
            guard let source = dict["source"] as? String,
                  let uids = dict["uids"] as? [[String: Any]] else { return [] }
            return uids.map { uid in
                ExternalUserIdData(
                    source: source,
                    identifier: uid["id"] as? String ?? "",
                    atype: (uid["atype"] as? NSNumber)?.int64Value,
                    ext: (uid["ext"] as? [String: Any])?.reduce(into: [String?: Any?]()) { $0[$1.key] = $1.value }
                )
            }
        }
    }

    func clearExternalUserIds() throws {
        Targeting.shared.setExternalUserIds([])
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
