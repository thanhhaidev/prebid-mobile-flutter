package io.github.thanhhaidev.prebid_mobile_sdk

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import org.prebid.mobile.AdSize
import org.prebid.mobile.BannerParameters
import org.prebid.mobile.NativeAdUnit
import org.prebid.mobile.NativeAsset
import org.prebid.mobile.NativeDataAsset
import org.prebid.mobile.NativeEventTracker
import org.prebid.mobile.NativeImageAsset
import org.prebid.mobile.NativeParameters
import org.prebid.mobile.NativeTitleAsset
import org.prebid.mobile.PrebidMobile
import org.prebid.mobile.api.data.BidInfo
import org.prebid.mobile.api.original.PrebidAdUnit
import org.prebid.mobile.api.original.PrebidRequest
import org.prebid.mobile.rendering.models.AdPosition

/** MultiformatAdHostApi: the Original API (PrebidAdUnit fetchDemand → targeting keywords). */
class MultiformatAdHostApiImpl(
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

        // Build PrebidRequest using setters
        val request = PrebidRequest()
        config.gpid?.let { request.setGpid(it) }

        if (config.bannerSizes != null && config.bannerSizes.isNotEmpty()) {
            val params = BannerParameters()
            val sizes = mutableSetOf<AdSize>()
            val sizeList = config.bannerSizes.filterNotNull()
            var i = 0
            while (i + 1 < sizeList.size) {
                sizes.add(AdSize(sizeList[i].toInt(), sizeList[i + 1].toInt()))
                i += 2
            }
            params.adSizes = sizes
            request.setBannerParameters(params)
        }

        config.videoConfig?.let { request.setVideoParameters(it.toVideoParameters()) }

        // Build native params if provided
        config.nativeConfig?.let { nc ->
            val assets = mutableListOf<NativeAsset>()
            nc.assets?.filterNotNull()?.forEach { ac ->
                when (ac.assetType) {
                    "title" -> {
                        val a = NativeTitleAsset()
                        a.setLength(ac.titleLength?.toInt() ?: 90)
                        a.isRequired = ac.required_
                        assets.add(a)
                    }
                    "image" -> {
                        val a = NativeImageAsset(
                            ac.imageWidthMin?.toInt() ?: 0,
                            ac.imageHeightMin?.toInt() ?: 0,
                            ac.imageWidth?.toInt() ?: 0,
                            ac.imageHeight?.toInt() ?: 0
                        )
                        ac.imageType?.let { a.imageType = NativeImageAsset.IMAGE_TYPE.values().firstOrNull { t -> t.id == it.toInt() } }
                        a.isRequired = ac.required_
                        assets.add(a)
                    }
                    "data" -> {
                        val a = NativeDataAsset()
                        ac.dataType?.let { a.dataType = NativeDataAsset.DATA_TYPE.values().firstOrNull { d -> d.id == it.toInt() } }
                        ac.dataLength?.let { a.setLen(it.toInt()) }
                        a.isRequired = ac.required_
                        assets.add(a)
                    }
                }
            }
            val params = NativeParameters(assets)
            nc.context?.let { v ->
                NativeAdUnit.CONTEXT_TYPE.values().firstOrNull { it.id == v.toInt() }
                    ?.let { params.setContextType(it) }
            }
            nc.contextSubType?.let { v ->
                NativeAdUnit.CONTEXTSUBTYPE.values().firstOrNull { it.id == v.toInt() }
                    ?.let { params.setContextSubType(it) }
            }
            nc.placementType?.let { v ->
                NativeAdUnit.PLACEMENTTYPE.values().firstOrNull { it.id == v.toInt() }
                    ?.let { params.setPlacementType(it) }
            }

            // Event trackers
            nc.eventTrackers?.filterNotNull()?.forEach { tc ->
                val methods = ArrayList<NativeEventTracker.EVENT_TRACKING_METHOD>()
                tc.methods.forEach { m ->
                    NativeEventTracker.EVENT_TRACKING_METHOD.values()
                        .firstOrNull { it.id == m.toInt() }?.let { methods.add(it) }
                }
                val eventType = NativeEventTracker.EVENT_TYPE.values()
                    .firstOrNull { it.id == tc.eventType.toInt() }
                if (eventType != null) {
                    params.addEventTracker(NativeEventTracker(eventType, methods))
                }
            }
            request.setNativeParameters(params)
        }

        request.setInterstitial(config.isInterstitial)
        request.setRewarded(config.isRewarded)

        config.adPosition?.let { pos ->
            AdPosition.values().firstOrNull { it.value == pos.toInt() }
                ?.let { request.setAdPosition(it) }
        }

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

    override fun destroy(adId: Long) {
        cancelRefresh(adId)
        refreshSeconds.remove(adId)
        requests.remove(adId)
        adUnits.remove(adId)?.let(::release)
    }

    fun destroyAll() {
        adUnits.keys.toList().forEach(::destroy)
    }

    private fun BidInfo.toMultiformatResult() = MultiformatBidResult(
        resultCode = dartResultCode(),
        winningFormat = targetingKeywords?.get("hb_format"),
        targetingKeywords = targetingKeywords?.mapKeys { it.key } ?: emptyMap(),
        nativeAdCacheId = nativeCacheId,
        exp = exp?.toDouble(),
        topBidFiltered = isTopBidFiltered,
    )

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
