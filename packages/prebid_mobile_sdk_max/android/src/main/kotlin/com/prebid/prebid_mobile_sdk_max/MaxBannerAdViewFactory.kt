package com.prebid.prebid_mobile_sdk_max

import android.app.Activity
import android.content.Context
import android.view.View
import com.applovin.mediation.MaxAd
import com.applovin.mediation.MaxAdViewAdListener
import com.applovin.mediation.MaxError
import com.applovin.mediation.adapters.prebid.utils.MaxMediationBannerUtils
import com.applovin.mediation.ads.MaxAdView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.prebid.mobile.AdSize
import org.prebid.mobile.api.mediation.MediationBannerAdUnit

/// PlatformView factory for AppLovin MAX-mediated banners. The rendered view is
/// the MAX [MaxAdView]; Prebid's [MediationBannerAdUnit] runs the auction and
/// passes the winning bid to MAX via the Prebid MAX adapter.
class MaxBannerAdViewFactory(
    private val messenger: BinaryMessenger,
    private val activityProvider: () -> Activity?,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any>()
        return MaxBannerPlatformView(
            activityProvider() ?: context,
            viewId,
            messenger,
            params,
        )
    }
}

class MaxBannerPlatformView(
    context: Context,
    viewId: Int,
    messenger: BinaryMessenger,
    params: Map<*, *>,
) : PlatformView {

    private val adView: MaxAdView
    private val methodChannel: MethodChannel
    private var adUnit: MediationBannerAdUnit? = null

    // Set once Flutter disposes the view: an auction finishing later must not
    // load into the destroyed MaxAdView.
    private var disposed = false

    init {
        val configId = params["configId"] as? String ?: ""
        val maxAdUnitId = params["maxAdUnitId"] as? String ?: ""
        val width = params["width"] as? Int ?: 320
        val height = params["height"] as? Int ?: 50
        val autoLoad = params["autoLoad"] as? Boolean ?: true

        methodChannel = MethodChannel(messenger, "prebid_mobile_sdk_max/banner_$viewId")

        adView = MaxAdView(maxAdUnitId, context)
        adView.setListener(object : MaxAdViewAdListener {
            override fun onAdLoaded(ad: MaxAd) {
                methodChannel.invokeMethod(
                    "onAdSize",
                    mapOf("width" to width.toDouble(), "height" to height.toDouble()),
                )
                methodChannel.invokeMethod("onAdLoaded", null)
                methodChannel.invokeMethod("onAdDisplayed", null)
            }

            override fun onAdLoadFailed(adUnitId: String, error: MaxError) {
                methodChannel.invokeMethod("onAdFailed", error.message)
            }

            override fun onAdDisplayFailed(ad: MaxAd, error: MaxError) {
                methodChannel.invokeMethod("onAdFailed", error.message)
            }

            override fun onAdClicked(ad: MaxAd) {
                methodChannel.invokeMethod("onAdClicked", null)
            }

            override fun onAdHidden(ad: MaxAd) {
                methodChannel.invokeMethod("onAdClosed", null)
            }

            override fun onAdDisplayed(ad: MaxAd) {}
            override fun onAdExpanded(ad: MaxAd) {}
            override fun onAdCollapsed(ad: MaxAd) {}
        })

        // MAX reports revenue when the impression is recorded.
        adView.setRevenueListener { methodChannel.invokeMethod("onAdImpression", null) }

        val mediationUtils = MaxMediationBannerUtils(adView)
        adUnit = MediationBannerAdUnit(
            context,
            configId,
            AdSize(width, height),
            mediationUtils,
        )

        // Calls from PrebidBannerAdController.
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "loadAd" -> { load(); result.success(null) }
                "stopRefresh" -> {
                    adUnit?.stopRefresh()
                    adView.stopAutoRefresh()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        if (autoLoad) {
            load()
        }
    }

    private fun load() {
        adUnit?.fetchDemand {
            if (!disposed) adView.loadAd()
        }
    }

    override fun getView(): View = adView

    override fun dispose() {
        disposed = true
        methodChannel.setMethodCallHandler(null)
        adUnit?.destroy()
        adUnit = null
        adView.destroy()
    }
}
