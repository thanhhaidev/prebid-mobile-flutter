package com.prebid.prebid_mobile_sdk

import android.app.Activity
import android.content.Context
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.prebid.mobile.AdSize
import org.prebid.mobile.api.rendering.BannerView
import org.prebid.mobile.api.rendering.listeners.BannerViewListener
import org.prebid.mobile.api.exceptions.AdException

class BannerAdViewFactory(
    private val messenger: BinaryMessenger,
    private val activityProvider: () -> Activity?,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any>()
        return BannerAdPlatformView(activityProvider() ?: context, viewId, messenger, params)
    }
}

class BannerAdPlatformView(
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

        methodChannel = MethodChannel(messenger, "prebid_mobile_flutter/banner_ad_$viewId")

        bannerView = BannerView(context, configId, AdSize(width, height))

        if (isVideo) {
            bannerView.videoPlacementType = org.prebid.mobile.api.data.VideoPlacementType.IN_BANNER
        }

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
        })

        if (autoLoad) {
            bannerView.loadAd()
        }
    }

    override fun getView(): View = bannerView

    override fun dispose() {
        bannerView.destroy()
    }
}
