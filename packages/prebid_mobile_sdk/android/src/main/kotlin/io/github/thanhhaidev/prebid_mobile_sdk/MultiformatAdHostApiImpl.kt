package io.github.thanhhaidev.prebid_mobile_sdk

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import org.prebid.mobile.AdSize
import org.prebid.mobile.BannerParameters
import org.prebid.mobile.PrebidMobile
import org.prebid.mobile.Signals
import org.prebid.mobile.addendum.AdViewUtils
import org.prebid.mobile.addendum.PbFindSizeError
import org.prebid.mobile.api.original.PrebidAdUnit
import org.prebid.mobile.api.original.PrebidRequest
import org.prebid.mobile.rendering.models.AdPosition

/** MultiformatAdHostApi: the Original API (PrebidAdUnit fetchDemand → targeting keywords). */
internal class MultiformatAdHostApiImpl(
    private val flutterApi: MultiformatFlutterApi,
    private val activity: () -> Activity?,
) : MultiformatAdHostApi {

    private val adUnits = mutableMapOf<Long, PrebidAdUnit>()
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
        val adUnit = PrebidAdUnit(config.configId)
        adUnits[adId] = adUnit
        // Must be set before the auction: Prebid starts the tracker when the
        // ad server's interstitial shows the Prebid creative.
        if (config.trackInterstitialImpression) adUnit.activateInterstitialPrebidImpressionTracker(true)
        val request = buildRequest(config)
        requests[adId] = request
        inFlight += adUnit
        adUnit.fetchDemand(request) { bidInfo ->
            val result = bidInfo.toMultiformatResult()
            mainHandler.post {
                inFlight -= adUnit
                callback(Result.success(result))
                if (adUnits[adId] === adUnit) scheduleRefresh(adId) else adUnit.destroy()
            }
        }
    }

    private fun buildRequest(config: MultiformatAdRequestConfig) = PrebidRequest().apply {
        config.gpid?.let(::setGpid)
        val sizes = config.bannerSizes.orEmpty().filterNotNull().chunked(2)
            .filter { it.size == 2 }
            .map { (w, h) -> AdSize(w.toInt(), h.toInt()) }
        // A banner without sizes is an interstitial's display format (its
        // minimum size and API frameworks still apply).
        val interstitialBanner = config.isInterstitial &&
            (config.bannerApi != null || config.interstitialMinWidthPercentage != null ||
                config.interstitialMinHeightPercentage != null)
        if (sizes.isNotEmpty() || interstitialBanner) {
            setBannerParameters(BannerParameters().apply {
                if (sizes.isNotEmpty()) adSizes = sizes.toSet()
                config.bannerApi?.filterNotNull()?.let { ids -> api = ids.map { Signals.Api(it.toInt()) } }
                config.interstitialMinWidthPercentage?.let { interstitialMinWidthPercentage = it.toInt() }
                config.interstitialMinHeightPercentage?.let { interstitialMinHeightPercentage = it.toInt() }
            })
        }
        config.videoConfig?.let { setVideoParameters(it.toVideoParameters()) }
        config.nativeConfig?.let { setNativeParameters(NativeRequestSettings(it).toParameters()) }
        setInterstitial(config.isInterstitial)
        setRewarded(config.isRewarded)
        config.adPosition?.let { pos ->
            AdPosition.values().firstOrNull { it.value.toLong() == pos }?.let(::setAdPosition)
        }
        // supportSKOverlay: iOS only (SKAdNetwork). pbAdSlot and the ORTB
        // configs: iOS only too, PrebidAdUnit / PrebidRequest have no setters.
    }

    // Units with an auction running. Destroying one clears its result
    // listener, so the pending Dart Future would never complete: such a unit
    // is destroyed once its auction returns (iOS keeps it alive likewise).
    private val inFlight = mutableSetOf<PrebidAdUnit>()

    private fun release(adUnit: PrebidAdUnit) {
        if (adUnit !in inFlight) adUnit.destroy()
    }

    // Auto-refresh. Prebid Android 3.4's PrebidAdUnit can't refresh: it
    // rebuilds its inner ad unit (interval 0, no refresh listener) on every
    // fetchDemand. So the plugin re-runs the same request on a timer and
    // sends each result to Dart as an event.
    private val requests = mutableMapOf<Long, PrebidRequest>()
    private val refreshTasks = mutableMapOf<Long, Runnable>()

    private fun scheduleRefresh(adId: Long) {
        cancelRefresh(adId)
        val seconds = refreshSeconds[adId] ?: return
        if (requests[adId] == null) return
        val task = object : Runnable {
            override fun run() {
                val adUnit = adUnits[adId] ?: return
                val request = requests[adId] ?: return
                inFlight += adUnit
                adUnit.fetchDemand(request) { bidInfo ->
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
        if (refreshTasks.containsKey(adId)) scheduleRefresh(adId)
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
        adUnit.activatePrebidImpressionTracker(banner)
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
        requests.remove(adId)
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
