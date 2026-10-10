package io.github.thanhhaidev.prebid_mobile_sdk

import android.app.Activity
import android.content.Context
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.util.EnumSet
import org.prebid.mobile.AdSize
import org.prebid.mobile.PrebidMobile
import org.prebid.mobile.api.data.AdUnitFormat
import org.prebid.mobile.api.data.VideoPlacementType
import org.prebid.mobile.api.exceptions.AdException
import org.prebid.mobile.api.rendering.BannerView
import org.prebid.mobile.api.rendering.listeners.BannerVideoListener
import org.prebid.mobile.api.rendering.listeners.BannerViewListener
import org.prebid.mobile.rendering.bidding.data.bid.BidResponse
import org.prebid.mobile.rendering.models.AdPosition

internal class BannerAdViewFactory(
    private val messenger: BinaryMessenger,
    private val activityProvider: () -> Activity?,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any>()
        return BannerAdPlatformView(activityProvider() ?: context, viewId, messenger, params)
    }
}

internal class BannerAdPlatformView(
    private val context: Context,
    private val viewId: Int,
    messenger: BinaryMessenger,
    params: Map<*, *>
) : PlatformView {

    private val bannerView: BannerView
    private val methodChannel: MethodChannel

    init {
        val configId = params["configId"] as? String ?: ""
        val width = params["width"] as? Int ?: 320
        val height = params["height"] as? Int ?: 50
        val isVideo = params["isVideo"] as? Boolean ?: false
        val autoLoad = params["autoLoad"] as? Boolean ?: true
        val refreshInterval = params["refreshIntervalSeconds"] as? Int
        val adFormats = (params["adFormats"] as? List<*>)?.filterIsInstance<String>()
        val pbAdSlot = params["pbAdSlot"] as? String
        val impOrtbConfig = params["impOrtbConfig"] as? String
        val videoPlacement = videoPlacementType(params["videoPlacementType"] as? String)

        // Named by the Dart widget before this view exists (AdViewChannel).
        val channelId = (params["channelId"] as? Number)?.toLong() ?: viewId.toLong()
        methodChannel = MethodChannel(messenger, "prebid_mobile_sdk/banner_ad_$channelId")

        bannerView = BannerView(context, configId, AdSize(width, height))
        (params["additionalSizes"] as? List<*>)?.mapNotNull { (it as? Number)?.toInt() }
            ?.chunked(2)?.filter { it.size == 2 }
            ?.map { AdSize(it[0], it[1]) }
            ?.takeIf { it.isNotEmpty() }
            ?.let { bannerView.addAdditionalSizes(*it.toTypedArray()) }

        if (adFormats != null) {
            // Multiformat banner (Prebid 3.4): banner and/or video in one request.
            val formats = EnumSet.noneOf(AdUnitFormat::class.java)
            if ("banner" in adFormats) formats.add(AdUnitFormat.BANNER)
            if ("video" in adFormats) formats.add(AdUnitFormat.VIDEO)
            if (formats.isNotEmpty()) bannerView.setAdUnitFormats(formats)
            if ("video" in adFormats) {
                bannerView.videoPlacementType = videoPlacement ?: VideoPlacementType.IN_BANNER
            }
        } else if (isVideo) {
            bannerView.videoPlacementType = videoPlacement ?: VideoPlacementType.IN_BANNER
        }
        pbAdSlot?.let { bannerView.setPbAdSlot(it) }
        (params["adPosition"] as? Number)?.toInt()?.let { pos ->
            AdPosition.values().firstOrNull { it.value == pos }
                ?.let { bannerView.setAdPosition(it) }
        }
        // params["videoParameters"]: iOS only; Prebid Android's BannerView has
        // no video-parameters setter.
        impOrtbConfig?.let { bannerView.setImpOrtbConfig(it) }
        (params["globalOrtbConfig"] as? String)?.let { bannerView.setGlobalOrtbConfig(it) }

        if (refreshInterval != null && refreshInterval > 0) {
            bannerView.setAutoRefreshDelay(refreshInterval)
        }

        bannerView.setBannerListener(object : BannerViewListener {
            override fun onAdLoaded(view: BannerView) {
                // Report the won creative size so the Flutter slot can size
                // dynamically to whatever the SDK returns (e.g. a multisize
                // banner) instead of being clipped to the requested size.
                view.bidResponse?.winningBid?.let { bid ->
                    methodChannel.invokeMethod(
                        "onAdSize",
                        mapOf(
                            "width" to bid.width.toDouble(),
                            "height" to bid.height.toDouble(),
                        ),
                    )
                }
                methodChannel.invokeMethod("onAdLoaded", view.bidResponse?.toWinningBid())
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
                "loadAd" -> { load(); result.success(null) }
                "stopRefresh" -> { bannerView.stopRefresh(); result.success(null) }
                else -> result.notImplemented()
            }
        }

        if (autoLoad) {
            load()
        }
    }

    private fun load() {
        // Prebid drops a request made before the SDK has initialized without
        // calling back; report it instead.
        if (!PrebidMobile.isSdkInitialized()) {
            methodChannel.invokeMethod("onAdFailed", PluginErrors.NOT_INITIALIZED)
            return
        }
        bannerView.loadAd()
    }

    override fun getView(): View = bannerView

    override fun dispose() {
        methodChannel.setMethodCallHandler(null)
        bannerView.destroy()
    }
}

internal fun videoPlacementType(name: String?): VideoPlacementType? = when (name) {
    "inBanner" -> VideoPlacementType.IN_BANNER
    "inArticle" -> VideoPlacementType.IN_ARTICLE
    "inFeed" -> VideoPlacementType.IN_FEED
    else -> null
}

/** The winning bid of a loaded banner, as sent with `onAdLoaded`. */
private fun BidResponse.toWinningBid(): Map<String, Any?>? {
    val bid = winningBid ?: return null
    val keywords = targeting.orEmpty()
    return mapOf(
        "price" to bid.price,
        "bidder" to keywords["hb_bidder"],
        "width" to bid.width,
        "height" to bid.height,
        "targetingKeywords" to keywords,
    )
}
