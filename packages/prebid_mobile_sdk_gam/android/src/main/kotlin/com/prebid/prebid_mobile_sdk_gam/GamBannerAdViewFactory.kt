package com.prebid.prebid_mobile_sdk_gam

import android.app.Activity
import android.content.Context
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.prebid.mobile.AdSize
import org.prebid.mobile.api.exceptions.AdException
import org.prebid.mobile.api.rendering.BannerView
import org.prebid.mobile.api.rendering.listeners.BannerViewListener
import org.prebid.mobile.eventhandlers.GamBannerEventHandler

/// PlatformView factory for GAM-rendered banners. Mirrors the core
/// BannerAdViewFactory but builds the BannerView with a [GamBannerEventHandler]
/// so Google Ad Manager renders the ad.
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
        val videoPlacement = when (params["videoPlacementType"] as? String) {
            "inArticle" -> org.prebid.mobile.api.data.VideoPlacementType.IN_ARTICLE
            "inFeed" -> org.prebid.mobile.api.data.VideoPlacementType.IN_FEED
            else -> org.prebid.mobile.api.data.VideoPlacementType.IN_BANNER
        }

        methodChannel = MethodChannel(messenger, "prebid_mobile_sdk_gam/banner_$viewId")

        val eventHandler = GamBannerEventHandler(context, gamAdUnitId, AdSize(width, height)).apply {
            gamCustomTargeting(params["customTargeting"])?.let { targeting ->
                // Prebid 3.4: app custom targeting on the GAM request; Prebid's
                // hb_* keys still take precedence.
                setAdManagerRequestConfiguration { builder ->
                    targeting.forEach { (k, v) -> builder.addCustomTargeting(k, v) }
                }
            }
        }
        bannerView = BannerView(context, configId, eventHandler)

        if (isVideo) {
            bannerView.videoPlacementType = videoPlacement
        }

        // 0 means a single request without auto-refresh (also Prebid's default).
        bannerView.setAutoRefreshDelay(if (refreshInterval != null && refreshInterval > 0) refreshInterval else 0)

        bannerView.setBannerListener(object : BannerViewListener {
            override fun onAdLoaded(view: BannerView) {
                view.bidResponse?.winningBid?.let { bid ->
                    methodChannel.invokeMethod(
                        "onAdSize",
                        mapOf(
                            "width" to bid.width.toDouble(),
                            "height" to bid.height.toDouble(),
                        ),
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

        bannerView.setBannerVideoListener(object : org.prebid.mobile.api.rendering.listeners.BannerVideoListener {
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

    override fun getView(): View = bannerView

    override fun dispose() {
        methodChannel.setMethodCallHandler(null)
        bannerView.destroy()
    }
}
