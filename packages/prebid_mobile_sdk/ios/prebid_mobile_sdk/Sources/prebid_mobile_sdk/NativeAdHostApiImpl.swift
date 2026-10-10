import Flutter
import PrebidMobile

/// NativeAdHostApi: In-App native ads. The assets go to Dart; the ad itself
/// stays in the [NativeAdStore] for the native view that renders or tracks it.
final class NativeAdHostApiImpl: NativeAdHostApi {
    private let flutterApi: AdFlutterApi
    private let nativeAdStore: NativeAdStore
    private var nativeRequests: [Int64: NativeRequest] = [:]

    init(flutterApi: AdFlutterApi, store: NativeAdStore) {
        self.flutterApi = flutterApi
        self.nativeAdStore = store
    }

    func loadAd(adId: Int64, config: NativeAdRequestConfig) throws {
        try destroy(adId: adId)
        let nativeRequest = NativeRequest(configId: config.configId)
        NativeRequestSettings(config).apply(to: nativeRequest)
        nativeRequests[adId] = nativeRequest

        // A destroyed or reloaded ad's result is ignored.
        let requestId = ObjectIdentifier(nativeRequest)
        InFlightAdUnits.retain(nativeRequest)
        nativeRequest.fetchDemand(completionBidInfo: { [weak self] bidInfo in
            InFlightAdUnits.release(requestId)
            guard let self = self,
                  self.nativeRequests[adId].map(ObjectIdentifier.init) == requestId else { return }
            guard bidInfo.resultCode == .prebidDemandFetchSuccess else {
                return self.flutterApi.sendAdFailed(adId, bidInfo.resultCode.dartCode)
            }
            self.show(adId, cacheId: bidInfo.nativeAdCacheId)
        })
    }

    func loadFromCacheId(adId: Int64, cacheId: String) throws {
        try destroy(adId: adId)
        show(adId, cacheId: cacheId)
    }

    func performClick(adId: Int64) throws -> Bool {
        nativeAdStore.performClick(adId)
    }

    /// Hands the cached native ad to Dart and the store, or reports a failure.
    private func show(_ adId: Int64, cacheId: String?) {
        guard let nativeAd = cacheId.flatMap({ NativeAd.create(cacheId: $0) }) else {
            return flutterApi.sendAdFailed(adId, "Failed to parse native ad")
        }
        nativeAdStore.put(
            adId, ad: nativeAd,
            delegate: NativeAdEventForwarder(adId: adId, flutterApi: flutterApi)
        )
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdLoaded", nativeAd: nativeAd.nativeAdData)) { _ in }
    }

    func destroy(adId: Int64) throws {
        nativeRequests.removeValue(forKey: adId)
        nativeAdStore.remove(adId)
    }

    func destroyAll() {
        nativeRequests.removeAll()
        nativeAdStore.removeAll()
    }
}
