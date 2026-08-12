package com.prebid.prebid_mobile_sdk_admob

import android.app.Activity
import android.content.Context
import android.os.Bundle
import android.view.View
import com.google.android.gms.ads.AdListener
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.AdSize as GmaAdSize
import com.google.android.gms.ads.AdView
import com.google.android.gms.ads.LoadAdError
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.prebid.mobile.AdSize
import org.prebid.mobile.admob.AdMobMediationBannerUtils
import org.prebid.mobile.admob.PrebidBannerAdapter
import org.prebid.mobile.api.mediation.MediationBannerAdUnit

/// PlatformView factory for AdMob-mediated banners. The rendered view is the
/// Google Mobile Ads [AdView]; Prebid's [MediationBannerAdUnit] runs the auction
/// and passes the winning bid to AdMob via the Prebid AdMob adapter.
class AdMobBannerAdViewFactory(
    private val messenger: BinaryMessenger,
    private val activityProvider: () -> Activity?,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any>()
        return AdMobBannerPlatformView(
            activityProvider() ?: context,
            viewId,
            messenger,
            params,
        )
    }
}

class AdMobBannerPlatformView(
    context: Context,
    viewId: Int,
    messenger: BinaryMessenger,
    params: Map<*, *>,
) : PlatformView {

    private val adView: AdView = AdView(context)
    private val methodChannel: MethodChannel
    private var adUnit: MediationBannerAdUnit? = null

    init {
        val configId = params["configId"] as? String ?: ""
        val adMobAdUnitId = params["adMobAdUnitId"] as? String ?: ""
        val width = params["width"] as? Int ?: 320
        val height = params["height"] as? Int ?: 50
        val autoLoad = params["autoLoad"] as? Boolean ?: true

        methodChannel = MethodChannel(messenger, "prebid_mobile_sdk_admob/banner_$viewId")

        adView.setAdSize(GmaAdSize(width, height))
        adView.adUnitId = adMobAdUnitId
        adView.adListener = object : AdListener() {
            override fun onAdLoaded() {
                methodChannel.invokeMethod(
                    "onAdSize",
                    mapOf("width" to width.toDouble(), "height" to height.toDouble()),
                )
                methodChannel.invokeMethod("onAdLoaded", null)
                methodChannel.invokeMethod("onAdDisplayed", null)
            }

            override fun onAdFailedToLoad(error: LoadAdError) {
                methodChannel.invokeMethod("onAdFailed", error.message)
            }

            override fun onAdClicked() {
                methodChannel.invokeMethod("onAdClicked", null)
            }

            override fun onAdClosed() {
                methodChannel.invokeMethod("onAdClosed", null)
            }
        }

        // Prebid targeting keywords are written into this Bundle by the adapter.
        val extras = Bundle()
        val request = AdRequest.Builder()
            .addNetworkExtrasBundle(PrebidBannerAdapter::class.java, extras)
            .build()

        val mediationUtils = AdMobMediationBannerUtils(extras, adView)
        adUnit = MediationBannerAdUnit(
            context,
            configId,
            AdSize(width, height),
            mediationUtils,
        )

        if (autoLoad) {
            adUnit?.fetchDemand {
                // The bid (if any) is now attached to the request extras; let
                // AdMob run its waterfall and render.
                adView.loadAd(request)
            }
        }
    }

    override fun getView(): View = adView

    override fun dispose() {
        adUnit?.destroy()
        adUnit = null
        adView.destroy()
    }
}
