package io.github.thanhhaidev.prebid_mobile_sdk_gam

import android.app.Activity
import android.content.Context
import android.view.View
import com.google.android.gms.ads.BaseAdView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.util.EnumSet
import org.prebid.mobile.AdSize
import org.prebid.mobile.api.data.AdUnitFormat
import org.prebid.mobile.api.data.VideoPlacementType
import org.prebid.mobile.api.exceptions.AdException
import org.prebid.mobile.api.rendering.BannerView
import org.prebid.mobile.api.rendering.listeners.BannerVideoListener
import org.prebid.mobile.api.rendering.listeners.BannerViewListener
import org.prebid.mobile.eventhandlers.GamBannerEventHandler
import org.prebid.mobile.rendering.models.AdPosition

/**
 * PlatformView factory for GAM-rendered banners. Mirrors the core
 * BannerAdViewFactory but builds the BannerView with a [GamBannerEventHandler]
 * so Google Ad Manager renders the ad.
 */
class GamBannerAdViewFactory(
    private val messenger: BinaryMessenger,
    private val activityProvider: () -> Activity?,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any>()
        return GamBannerPlatformView(activityProvider() ?: context, viewId, messenger, params)
    }
}

class GamBannerPlatformView(
    context: Context,
    viewId: Int,
    messenger: BinaryMessenger,
    params: Map<*, *>,
) : PlatformView {

    private val bannerView: BannerView
    private val methodChannel: MethodChannel

    init {
        val configId = params["configId"] as? String ?: ""
        val gamAdUnitId = params["gamAdUnitId"] as? String ?: ""
        val width = params["width"] as? Int ?: 320
        val height = params["height"] as? Int ?: 50
        val isVideo = params["isVideo"] as? Boolean ?: false
        val autoLoad = params["autoLoad"] as? Boolean ?: true
        val refreshInterval = params["refreshIntervalSeconds"] as? Int
        val adFormats = (params["adFormats"] as? List<*>)?.filterIsInstance<String>()
        val pbAdSlot = params["pbAdSlot"] as? String
        val impOrtbConfig = params["impOrtbConfig"] as? String
        // Flat [w, h, w, h, ...] list of extra sizes for a multisize banner.
        val additionalSizes = (params["additionalSizes"] as? List<*>).orEmpty()
            .mapNotNull { (it as? Number)?.toInt() }
            .chunked(2)
            .filter { it.size == 2 }
            .map { (w, h) -> AdSize(w, h) }
        val videoPlacement = when (params["videoPlacementType"] as? String) {
            "inArticle" -> VideoPlacementType.IN_ARTICLE
            "inFeed" -> VideoPlacementType.IN_FEED
            else -> VideoPlacementType.IN_BANNER
        }

        methodChannel = MethodChannel(messenger, "prebid_mobile_sdk_gam/banner_$viewId")

        // The BannerView requests every size the GAM event handler accepts.
        val adSizes = (listOf(AdSize(width, height)) + additionalSizes).toTypedArray()
        val eventHandler = GamBannerEventHandler(context, gamAdUnitId, *adSizes).apply {
            gamCustomTargeting(params["customTargeting"])?.let { targeting ->
                // Prebid 3.4: app custom targeting on the GAM request; Prebid's
                // hb_* keys still take precedence.
                setAdManagerRequestConfiguration { builder ->
                    targeting.forEach { (k, v) -> builder.addCustomTargeting(k, v) }
                }
            }
        }
        bannerView = BannerView(context, configId, eventHandler)
        (params["adPosition"] as? Number)?.toInt()?.let { pos ->
            AdPosition.values().firstOrNull { it.value == pos }
                ?.let { bannerView.setAdPosition(it) }
        }

        if (adFormats != null) {
            // Multiformat banner (Prebid 3.4): banner and/or video in one request.
            val formats = EnumSet.noneOf(AdUnitFormat::class.java)
            if ("banner" in adFormats) formats.add(AdUnitFormat.BANNER)
            if ("video" in adFormats) formats.add(AdUnitFormat.VIDEO)
            if (formats.isNotEmpty()) bannerView.setAdUnitFormats(formats)
            if ("video" in adFormats) bannerView.videoPlacementType = videoPlacement
        } else if (isVideo) {
            bannerView.videoPlacementType = videoPlacement
        }
        pbAdSlot?.let { bannerView.setPbAdSlot(it) }
        impOrtbConfig?.let { bannerView.setImpOrtbConfig(it) }
        // `videoParameters` is iOS only: Prebid Android's BannerView has no
        // video-parameters setter.

        // 0 means a single request without auto-refresh (also Prebid's default).
        bannerView.setAutoRefreshDelay(if (refreshInterval != null && refreshInterval > 0) refreshInterval else 0)

        bannerView.setBannerListener(object : BannerViewListener {
            override fun onAdLoaded(view: BannerView) {
                renderedSize(view)?.let { (w, h) ->
                    methodChannel.invokeMethod(
                        "onAdSize",
                        mapOf("width" to w.toDouble(), "height" to h.toDouble()),
                    )
                }
                methodChannel.invokeMethod("onAdLoaded", null)
            }

            override fun onAdDisplayed(view: BannerView) {
                methodChannel.invokeMethod("onAdDisplayed", null)
            }

            override fun onAdFailed(view: BannerView, exception: AdException?) {
                methodChannel.invokeMethod("onAdFailed", exception?.message ?: "Unknown error")
            }

            override fun onAdClicked(view: BannerView) {
                methodChannel.invokeMethod("onAdClicked", null)
            }

            override fun onAdClosed(view: BannerView) {
                methodChannel.invokeMethod("onAdClosed", null)
            }

            override fun onAdExpired(view: BannerView) {
                methodChannel.invokeMethod("onAdExpired", null)
            }
        })

        bannerView.setBannerVideoListener(object : BannerVideoListener {
            override fun onVideoCompleted(view: BannerView) { methodChannel.invokeMethod("onVideoCompleted", null) }
            override fun onVideoPaused(view: BannerView) { methodChannel.invokeMethod("onVideoPaused", null) }
            override fun onVideoResumed(view: BannerView) { methodChannel.invokeMethod("onVideoResumed", null) }
            override fun onVideoUnMuted(view: BannerView) { methodChannel.invokeMethod("onVideoUnmuted", null) }
            override fun onVideoMuted(view: BannerView) { methodChannel.invokeMethod("onVideoMuted", null) }
        })

        // Calls from PrebidBannerAdController.
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "loadAd" -> { bannerView.loadAd(); result.success(null) }
                "stopRefresh" -> { bannerView.stopRefresh(); result.success(null) }
                else -> result.notImplemented()
            }
        }

        if (autoLoad) {
            bannerView.loadAd()
        }
    }

    /**
     * The size of the creative on screen. When GAM's own ad wins, the
     * banner holds GAM's ad view (BannerView clears its children before
     * showing either winner) and the Prebid bid, if any, lost.
     */
    private fun renderedSize(view: BannerView): Pair<Int, Int>? {
        val gamView = (0 until view.childCount).map { view.getChildAt(it) }
            .firstOrNull { it is BaseAdView } as BaseAdView?
        gamView?.adSize?.let { size ->
            if (size.width > 0 && size.height > 0) return size.width to size.height
        }
        val bid = view.bidResponse?.winningBid ?: return null
        return bid.width to bid.height
    }

    override fun getView(): View = bannerView

    override fun dispose() {
        methodChannel.setMethodCallHandler(null)
        bannerView.destroy()
    }
}
