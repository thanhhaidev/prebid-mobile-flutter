package io.github.thanhhaidev.prebid_mobile_sdk

import org.prebid.mobile.NativeAdUnit
import org.prebid.mobile.PrebidMobile
import org.prebid.mobile.PrebidNativeAd

/**
 * NativeAdHostApi: In-App native ads. The assets go to Dart; the ad itself
 * stays in the [NativeAdStore] for the native view that renders or tracks it.
 */
internal class NativeAdHostApiImpl(
    private val flutterApi: AdFlutterApi,
    private val store: NativeAdStore,
) : NativeAdHostApi {

    private val nativeAds = mutableMapOf<Long, NativeAdUnit>()

    override fun loadAd(adId: Long, config: NativeAdRequestConfig) {
        destroy(adId)
        if (!PrebidMobile.isSdkInitialized()) {
            return flutterApi.sendAdFailed(adId, PluginErrors.NOT_INITIALIZED)
        }
        val nativeAdUnit = NativeAdUnit(config.configId)
        NativeRequestSettings(config).applyTo(nativeAdUnit)
        nativeAds[adId] = nativeAdUnit
        nativeAdUnit.fetchDemand { bidInfo ->
            val code = bidInfo.dartResultCode()
            if (code != "prebidDemandFetchSuccess") return@fetchDemand flutterApi.sendAdFailed(adId, code)
            show(adId, bidInfo.nativeCacheId)
        }
    }

    override fun loadFromCacheId(adId: Long, cacheId: String) {
        destroy(adId)
        show(adId, cacheId)
    }

    override fun performClick(adId: Long): Boolean = store.performClick(adId)

    /** Hands the cached native ad to Dart and the store, or reports a failure. */
    private fun show(adId: Long, cacheId: String?) {
        val nativeAd = cacheId?.let { PrebidNativeAd.create(it) }
            ?: return flutterApi.sendAdFailed(adId, "Failed to parse native ad")
        store.put(adId, nativeAd)
        flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdLoaded", nativeAd = nativeAd.toNativeAdData())) {}
    }

    override fun destroy(adId: Long) {
        nativeAds.remove(adId)?.destroy()
        store.remove(adId)
    }

    fun destroyAll() {
        (nativeAds.keys + store.ads.keys).toSet().forEach(::destroy)
    }
}
