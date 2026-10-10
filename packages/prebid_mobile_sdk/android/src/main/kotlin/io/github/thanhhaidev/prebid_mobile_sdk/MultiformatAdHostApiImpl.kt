package io.github.thanhhaidev.prebid_mobile_sdk

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import java.util.EnumSet
import org.prebid.mobile.AdSize
import org.prebid.mobile.AdUnit
import org.prebid.mobile.BannerAdUnit
import org.prebid.mobile.BannerParameters
import org.prebid.mobile.InterstitialAdUnit
import org.prebid.mobile.NativeAdUnit
import org.prebid.mobile.PrebidMobile
import org.prebid.mobile.RewardedVideoAdUnit
import org.prebid.mobile.Signals
import org.prebid.mobile.addendum.AdViewUtils
import org.prebid.mobile.addendum.PbFindSizeError
import org.prebid.mobile.api.data.AdUnitFormat
import org.prebid.mobile.api.data.BidInfo
import org.prebid.mobile.api.original.PrebidAdUnit
import org.prebid.mobile.api.original.PrebidRequest
import org.prebid.mobile.rendering.models.AdPosition

/**
 * One Original API ad unit. A single-format request runs on Prebid's
 * matching legacy [AdUnit] (banner, interstitial, rewarded video, native),
 * which takes the pbAdSlot, GPID and ORTB configs; a multiformat one on
 * [PrebidAdUnit], which has no setters for them.
 */
private interface OriginalAdUnit {
    fun fetchDemand(onResult: (BidInfo) -> Unit)
    fun activateBannerImpressionTracker(view: View)
    fun destroy()
}

private class LegacyAdUnit(val unit: AdUnit) : OriginalAdUnit {
    override fun fetchDemand(onResult: (BidInfo) -> Unit) = unit.fetchDemand { onResult(it) }
    override fun activateBannerImpressionTracker(view: View) = unit.activatePrebidImpressionTracker(view)
    override fun destroy() = unit.destroy()
}

private class MultiformatAdUnit(
    val unit: PrebidAdUnit,
    val request: PrebidRequest,
) : OriginalAdUnit {
    override fun fetchDemand(onResult: (BidInfo) -> Unit) = unit.fetchDemand(request) { onResult(it) }
    override fun activateBannerImpressionTracker(view: View) = unit.activatePrebidImpressionTracker(view)
    override fun destroy() = unit.destroy()
}

/** MultiformatAdHostApi: the Original API (fetchDemand → targeting keywords). */
internal class MultiformatAdHostApiImpl(
    private val flutterApi: MultiformatFlutterApi,
    private val activity: () -> Activity?,
) : MultiformatAdHostApi {

    private val adUnits = mutableMapOf<Long, OriginalAdUnit>()
    private val refreshSeconds = mutableMapOf<Long, Int>()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun fetchDemand(
        adId: Long,
        config: MultiformatAdRequestConfig,
        callback: (Result<MultiformatBidResult>) -> Unit
    ) {
        cancelRefresh(adId)
        adUnits.remove(adId)?.let(::release)
        if (!PrebidMobile.isSdkInitialized()) {
            callback(Result.success(MultiformatBidResult(
                resultCode = PluginErrors.NOT_INITIALIZED_CODE,
                targetingKeywords = emptyMap(),
            )))
            return
        }
        val adUnit = makeAdUnit(config)
        adUnits[adId] = adUnit
        inFlight += adUnit
        adUnit.fetchDemand { bidInfo ->
            val result = bidInfo.toMultiformatResult()
            mainHandler.post {
                inFlight -= adUnit
                callback(Result.success(result))
                if (adUnits[adId] === adUnit) scheduleRefresh(adId) else adUnit.destroy()
            }
        }
    }

    private fun makeAdUnit(config: MultiformatAdRequestConfig): OriginalAdUnit {
        val sizes = bannerSizes(config)
        val banner = sizes.isNotEmpty() || interstitialBanner(config)
        val video = config.videoConfig != null
        val native = config.nativeConfig != null
        val unit: AdUnit = when {
            native && !banner && !video && !config.isInterstitial && !config.isRewarded ->
                NativeAdUnit(config.configId).also { NativeRequestSettings(config.nativeConfig!!).applyTo(it) }
            native -> return multiformatAdUnit(config)
            config.isRewarded && video && !banner ->
                RewardedVideoAdUnit(config.configId).apply {
                    // Must be set before the auction: Prebid starts the
                    // tracker when the ad server's ad shows the Prebid creative.
                    if (config.trackInterstitialImpression) activatePrebidImpressionTracker()
                    videoParameters = config.videoConfig!!.toVideoParameters()
                }
            config.isRewarded -> return multiformatAdUnit(config)
            config.isInterstitial && (banner || video) ->
                InterstitialAdUnit(config.configId, formats(banner, video)).apply {
                    if (config.trackInterstitialImpression) activateInterstitialPrebidImpressionTracker()
                    val minWidth = config.interstitialMinWidthPercentage
                    val minHeight = config.interstitialMinHeightPercentage
                    if (minWidth != null && minHeight != null) setMinSizePercentage(minWidth.toInt(), minHeight.toInt())
                    if (banner) bannerParameters = bannerParameters(config, sizes)
                    config.videoConfig?.let { videoParameters = it.toVideoParameters() }
                }
            !config.isInterstitial && sizes.isNotEmpty() -> {
                val (first, rest) = sizes.first() to sizes.drop(1)
                BannerAdUnit(config.configId, first.width, first.height, formats(true, video)).apply {
                    rest.forEach { addAdditionalSize(it.width, it.height) }
                    bannerParameters = bannerParameters(config, sizes)
                    config.videoConfig?.let { videoParameters = it.toVideoParameters() }
                    adPosition(config)?.let(::setAdPosition)
                }
            }
            else -> return multiformatAdUnit(config)
        }
        config.gpid?.let(unit::setGpid)
        config.pbAdSlot?.let(unit::setPbAdSlot)
        config.impOrtbConfig?.let(unit::setImpOrtbConfig)
        config.globalOrtbConfig?.let(unit::setGlobalOrtbConfig)
        return LegacyAdUnit(unit)
    }

    private fun formats(banner: Boolean, video: Boolean): EnumSet<AdUnitFormat> =
        EnumSet.noneOf(AdUnitFormat::class.java).apply {
            if (banner) add(AdUnitFormat.BANNER)
            if (video) add(AdUnitFormat.VIDEO)
        }

    private fun bannerSizes(config: MultiformatAdRequestConfig): List<AdSize> =
        config.bannerSizes.orEmpty().filterNotNull().chunked(2)
            .filter { it.size == 2 }
            .map { (w, h) -> AdSize(w.toInt(), h.toInt()) }

    // A banner without sizes is an interstitial's display format (its
    // minimum size and API frameworks still apply).
    private fun interstitialBanner(config: MultiformatAdRequestConfig): Boolean =
        config.isInterstitial &&
            (config.bannerApi != null || config.interstitialMinWidthPercentage != null ||
                config.interstitialMinHeightPercentage != null)

    private fun bannerParameters(config: MultiformatAdRequestConfig, sizes: List<AdSize>) =
        BannerParameters().apply {
            if (sizes.isNotEmpty()) adSizes = sizes.toSet()
            config.bannerApi?.filterNotNull()?.let { ids -> api = ids.map { Signals.Api(it.toInt()) } }
            config.interstitialMinWidthPercentage?.let { interstitialMinWidthPercentage = it.toInt() }
            config.interstitialMinHeightPercentage?.let { interstitialMinHeightPercentage = it.toInt() }
        }

    private fun adPosition(config: MultiformatAdRequestConfig): AdPosition? =
        config.adPosition?.let { pos -> AdPosition.values().firstOrNull { it.value.toLong() == pos } }

    private fun multiformatAdUnit(config: MultiformatAdRequestConfig): OriginalAdUnit {
        val unit = PrebidAdUnit(config.configId)
        if (config.trackInterstitialImpression) unit.activateInterstitialPrebidImpressionTracker(true)
        return MultiformatAdUnit(unit, buildRequest(config))
    }

    private fun buildRequest(config: MultiformatAdRequestConfig) = PrebidRequest().apply {
        config.gpid?.let(::setGpid)
        val sizes = bannerSizes(config)
        if (sizes.isNotEmpty() || interstitialBanner(config)) {
            setBannerParameters(bannerParameters(config, sizes))
        }
        config.videoConfig?.let { setVideoParameters(it.toVideoParameters()) }
        config.nativeConfig?.let { setNativeParameters(NativeRequestSettings(it).toParameters()) }
        setInterstitial(config.isInterstitial)
        setRewarded(config.isRewarded)
        adPosition(config)?.let(::setAdPosition)
        // supportSKOverlay: iOS only (SKAdNetwork). pbAdSlot and the ORTB
        // configs: PrebidAdUnit / PrebidRequest have no setters, so a
        // multiformat request goes without them on Android.
    }

    // Units with an auction running. Destroying one clears its result
    // listener, so the pending Dart Future would never complete: such a unit
    // is destroyed once its auction returns (iOS keeps it alive likewise).
    private val inFlight = mutableSetOf<OriginalAdUnit>()

    private fun release(adUnit: OriginalAdUnit) {
        if (adUnit !in inFlight) adUnit.destroy()
    }

    // Auto-refresh. Prebid Android 3.4's PrebidAdUnit can't refresh: it
    // rebuilds its inner ad unit (interval 0, no refresh listener) on every
    // fetchDemand. So the plugin re-runs the same auction on a timer, for
    // the legacy ad units too (one mechanism), and sends each result to Dart
    // as an event.
    private val refreshTasks = mutableMapOf<Long, Runnable>()

    private fun scheduleRefresh(adId: Long) {
        cancelRefresh(adId)
        val seconds = refreshSeconds[adId] ?: return
        if (adUnits[adId] == null) return
        val task = object : Runnable {
            override fun run() {
                val adUnit = adUnits[adId] ?: return
                inFlight += adUnit
                adUnit.fetchDemand { bidInfo ->
                    val result = bidInfo.toMultiformatResult()
                    mainHandler.post {
                        inFlight -= adUnit
                        if (adUnits[adId] === adUnit) {
                            flutterApi.onDemandRefreshed(adId, result) { reply ->
                                // No Dart handler (none registered, or gone
                                // after a hot restart): nothing can receive
                                // refreshes, so stop auctioning for them.
                                val error = reply.exceptionOrNull() as? FlutterError
                                if (error?.code == "channel-error" && adUnits[adId] === adUnit) {
                                    cancelRefresh(adId)
                                }
                            }
                        } else {
                            adUnit.destroy()
                        }
                    }
                }
                mainHandler.postDelayed(this, seconds * 1000L)
            }
        }
        refreshTasks[adId] = task
        mainHandler.postDelayed(task, seconds * 1000L)
    }

    private fun cancelRefresh(adId: Long) {
        refreshTasks.remove(adId)?.let { mainHandler.removeCallbacks(it) }
    }

    override fun setAutoRefreshInterval(adId: Long, seconds: Long) {
        // Same bounds as Prebid's auto-refresh.
        refreshSeconds[adId] = seconds.coerceIn(30, 120).toInt()
        // Also when set after fetchDemand returned (the usual order): the
        // timer starts from now. During an auction, the result starts it.
        val adUnit = adUnits[adId]
        if (refreshTasks.containsKey(adId) || (adUnit != null && adUnit !in inFlight)) {
            scheduleRefresh(adId)
        }
    }

    override fun stopAutoRefresh(adId: Long) {
        cancelRefresh(adId)
    }

    override fun resumeAutoRefresh(adId: Long) {
        if (!refreshTasks.containsKey(adId)) scheduleRefresh(adId)
    }

    override fun activateBannerImpressionTracker(adId: Long): Boolean {
        val adUnit = adUnits[adId] ?: return false
        val root = activity()?.window?.decorView ?: return false
        val banner = findGmaBannerViews(root).singleOrNull() ?: return false
        adUnit.activateBannerImpressionTracker(banner)
        return true
    }

    override fun findPrebidCreativeSize(adId: Long, callback: (Result<List<Long>?>) -> Unit) {
        val banner = activity()?.window?.decorView?.let { findGmaBannerViews(it).singleOrNull() }
            ?: return callback(Result.success(null))
        AdViewUtils.findPrebidCreativeSize(banner, object : AdViewUtils.PbFindSizeListener {
            override fun success(width: Int, height: Int) {
                mainHandler.post { callback(Result.success(listOf(width.toLong(), height.toLong()))) }
            }

            override fun failure(error: PbFindSizeError) {
                mainHandler.post { callback(Result.success(null)) }
            }
        })
    }

    // SKAdNetwork: iOS only.
    override fun activateBannerSKAdNetwork(adId: Long): Boolean = false
    override fun activateInterstitialSKAdNetwork(adId: Long) {}
    override fun activateSKOverlay(adId: Long) {}
    override fun dismissSKOverlay(adId: Long) {}

    override fun destroy(adId: Long) {
        cancelRefresh(adId)
        refreshSeconds.remove(adId)
        adUnits.remove(adId)?.let(::release)
    }

    fun destroyAll() {
        adUnits.keys.toList().forEach(::destroy)
    }

    /**
     * Google Mobile Ads banner views (AdView / AdManagerAdView) in [view]'s
     * tree, found by class name so the core plugin needn't depend on GMA.
     */
    private fun findGmaBannerViews(view: View): List<View> {
        var type: Class<*>? = view.javaClass
        while (type != null) {
            if (type.name == "com.google.android.gms.ads.BaseAdView") return listOf(view)
            type = type.superclass
        }
        if (view !is ViewGroup) return emptyList()
        return (0 until view.childCount).flatMap { findGmaBannerViews(view.getChildAt(it)) }
    }
}
