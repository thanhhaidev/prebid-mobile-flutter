import Flutter
import PrebidMobile
import UIKit

/// MultiformatAdHostApi: the Original API (PrebidAdUnit fetchDemand → targeting keywords).
final class MultiformatAdHostApiImpl: MultiformatAdHostApi {

    private let flutterApi: MultiformatFlutterApi
    private var adUnits: [Int64: PrebidAdUnit] = [:]
    private var refreshSeconds: [Int64: Int64] = [:]

    init(flutterApi: MultiformatFlutterApi) {
        self.flutterApi = flutterApi
    }

    func fetchDemand(
        adId: Int64,
        config: MultiformatAdRequestConfig,
        completion: @escaping (Result<MultiformatBidResult, Error>) -> Void
    ) {
        adUnits[adId]?.stopAutoRefresh()
        let adUnit = PrebidAdUnit(configId: config.configId)
        adUnit.pbAdSlot = config.pbAdSlot
        adUnits[adId] = adUnit

        let request = Self.makeRequest(config)
        if let seconds = refreshSeconds[adId] {
            adUnit.setAutoRefreshMillis(time: Double(seconds) * 1000)
        }

        let unitId = ObjectIdentifier(adUnit)
        let trackInterstitial = config.trackInterstitialImpression
        // Auto-refresh calls this again for every refreshed auction; the
        // Pigeon reply can be sent once, later results go to Dart as events.
        var replied = false
        InFlightAdUnits.retain(adUnit)
        adUnit.fetchDemand(request: request) { [weak self, weak adUnit] bidInfo in
            InFlightAdUnits.release(unitId)
            let result = bidInfo.multiformatResult
            if !replied {
                replied = true
                // Prebid's interstitial tracker watches the key window for the
                // ad server's interstitial showing this bid's creative.
                if trackInterstitial, bidInfo.resultCode == .prebidDemandFetchSuccess {
                    adUnit?.activatePrebidInterstitialImpressionTracker()
                }
                completion(.success(result))
            } else if let self = self, let adUnit = adUnit, self.adUnits[adId] === adUnit {
                self.flutterApi.onDemandRefreshed(adId: adId, result: result) { _ in }
            }
        }
    }

    private static func makeRequest(_ config: MultiformatAdRequestConfig) -> PrebidRequest {
        var bannerParameters: BannerParameters?
        let sizes = (config.bannerSizes ?? []).compactMap { $0 }
        // A banner without sizes is an interstitial's display format (its
        // minimum size and API frameworks still apply).
        let interstitialBanner = config.isInterstitial && (config.bannerApi != nil
            || config.interstitialMinWidthPercentage != nil || config.interstitialMinHeightPercentage != nil)
        if sizes.count >= 2 || interstitialBanner {
            let parameters = BannerParameters()
            if sizes.count >= 2 {
                parameters.adSizes = stride(from: 0, to: sizes.count - 1, by: 2).map {
                    CGSize(width: Int(sizes[$0]), height: Int(sizes[$0 + 1]))
                }
            }
            parameters.api = config.bannerApi?.compactMap { $0 }.map { Signals.Api(integerLiteral: Int($0)) }
            parameters.interstitialMinWidthPerc = config.interstitialMinWidthPercentage.map { Int($0) }
            parameters.interstitialMinHeightPerc = config.interstitialMinHeightPercentage.map { Int($0) }
            bannerParameters = parameters
        }
        let request = PrebidRequest(
            bannerParameters: bannerParameters,
            videoParameters: config.videoConfig?.makeVideoParameters(),
            nativeParameters: config.nativeConfig.map { NativeRequestSettings($0).makeParameters() },
            isInterstitial: config.isInterstitial,
            isRewarded: config.isRewarded
        )
        if let gpid = config.gpid { request.setGPID(gpid) }
        if let v = config.impOrtbConfig { request.setImpORTBConfig(v) }
        if let v = config.globalOrtbConfig { request.setGlobalORTBConfig(v) }
        if let pos = config.adPosition.flatMap({ AdPosition(rawValue: Int($0)) }) {
            request.adPosition = pos
        }
        request.supportSKOverlayForInterstitial = config.supportSKOverlay
        return request
    }

    func setAutoRefreshInterval(adId: Int64, seconds: Int64) throws {
        // Prebid iOS ignores intervals under 30 s; clamp like Android.
        let seconds = min(max(seconds, 30), 120)
        refreshSeconds[adId] = seconds
        adUnits[adId]?.setAutoRefreshMillis(time: Double(seconds) * 1000)
    }

    func stopAutoRefresh(adId: Int64) throws {
        adUnits[adId]?.stopAutoRefresh()
    }

    func resumeAutoRefresh(adId: Int64) throws {
        adUnits[adId]?.resumeAutoRefresh()
    }

    func activateBannerImpressionTracker(adId: Int64) throws -> Bool {
        guard let adUnit = adUnits[adId], let banner = Self.onlyGmaBanner() else { return false }
        adUnit.activatePrebidAdViewImpressionTracker(adView: banner)
        return true
    }

    func findPrebidCreativeSize(adId: Int64, completion: @escaping (Result<[Int64]?, Error>) -> Void) {
        guard let banner = Self.onlyGmaBanner() else { return completion(.success(nil)) }
        AdViewUtils.findPrebidCreativeSize(banner, success: { size in
            DispatchQueue.main.async { completion(.success([Int64(size.width), Int64(size.height)])) }
        }, failure: { _ in
            DispatchQueue.main.async { completion(.success(nil)) }
        })
    }

    func activateBannerSKAdNetwork(adId: Int64) throws -> Bool {
        guard let adUnit = adUnits[adId], let banner = Self.onlyGmaBanner() else { return false }
        adUnit.activatePrebidBannerSKAdNetworkStoreKitAdsFlow(adView: banner)
        return true
    }

    func activateInterstitialSKAdNetwork(adId: Int64) throws {
        adUnits[adId]?.activatePrebidInterstitialSKAdNetworkStoreKitAdsFlow()
    }

    func activateSKOverlay(adId: Int64) throws {
        adUnits[adId]?.activateSKOverlayIfAvailable()
    }

    func dismissSKOverlay(adId: Int64) throws {
        adUnits[adId]?.dismissSKOverlayIfAvailable()
    }

    /// The only Google Mobile Ads banner on screen, if there is exactly one.
    private static func onlyGmaBanner() -> UIView? {
        guard let root = PrebidPresenter.topViewController()?.view.window else { return nil }
        let banners = gmaBannerViews(in: root)
        return banners.count == 1 ? banners[0] : nil
    }

    /// Google Mobile Ads banner views in [view]'s tree, found by class so the
    /// core plugin needn't depend on GMA.
    private static func gmaBannerViews(in view: UIView) -> [UIView] {
        if let type = NSClassFromString("GADBannerView"), view.isKind(of: type) { return [view] }
        return view.subviews.flatMap { gmaBannerViews(in: $0) }
    }

    func destroy(adId: Int64) throws {
        refreshSeconds.removeValue(forKey: adId)
        adUnits.removeValue(forKey: adId)?.stopAutoRefresh()
    }

    func destroyAll() {
        adUnits.keys.forEach { try? destroy(adId: $0) }
    }
}
