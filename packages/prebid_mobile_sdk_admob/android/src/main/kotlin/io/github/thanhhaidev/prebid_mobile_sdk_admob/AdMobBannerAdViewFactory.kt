package io.github.thanhhaidev.prebid_mobile_sdk_admob

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
import org.prebid.mobile.PrebidMobile
import org.prebid.mobile.admob.AdMobMediationBannerUtils
import org.prebid.mobile.admob.PrebidBannerAdapter
import org.prebid.mobile.api.mediation.MediationBannerAdUnit
import org.prebid.mobile.rendering.models.AdPosition

/**
 * PlatformView factory for AdMob-mediated banners. The rendered view is the
 * Google Mobile Ads [AdView]; Prebid's [MediationBannerAdUnit] runs the auction
 * and passes the winning bid to AdMob via the Prebid AdMob adapter.
 */
internal class AdMobBannerAdViewFactory(
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

/**
 * One AdMob banner: a Google Mobile Ads [AdView] loaded after each Prebid
 * auction of its [MediationBannerAdUnit], reporting to Dart over
 * `prebid_mobile_sdk_admob/banner_<channelId>`.
 */
internal class AdMobBannerPlatformView(
    context: Context,
    viewId: Int,
    messenger: BinaryMessenger,
    params: Map<*, *>,
) : PlatformView {

    private val adView: AdView = AdView(context)
    private val methodChannel: MethodChannel
    private var adUnit: MediationBannerAdUnit? = null
    private val request: AdRequest
    private val extras = Bundle()
    private val dropBidProbability: Double

    // Set once Flutter disposes the view: an auction finishing later must not
    // load into the destroyed AdView.
    private var disposed = false

    init {
        val configId = params["configId"] as? String ?: ""
        val adMobAdUnitId = params["adMobAdUnitId"] as? String ?: ""
        val width = params["width"] as? Int ?: 320
        val height = params["height"] as? Int ?: 50
        val autoLoad = params["autoLoad"] as? Boolean ?: true
        val adaptive = params["adaptive"] as? Boolean ?: false
        val refreshInterval = params["refreshIntervalSeconds"] as? Int
        // Flat [w, h, w, h, ...] list of extra Prebid request sizes.
        val additionalSizes = (params["additionalSizes"] as? List<*>).orEmpty()
            .mapNotNull { (it as? Number)?.toInt() }
            .chunked(2)
            .filter { it.size == 2 }
            .map { (w, h) -> AdSize(w, h) }
        dropBidProbability = debugDropBidProbability(params["debugDropBidProbability"])

        methodChannel = MethodChannel(messenger, viewChannelName("prebid_mobile_sdk_admob/banner", params, viewId))

        if (adaptive) {
            // Landscape inline adaptive size for the width Flutter measured
            // (the original Prebid test app uses the full width).
            val adaptiveWidth = (params["adaptiveWidth"] as? Number)?.toInt() ?: width
            adView.setAdSize(GmaAdSize.getLandscapeInlineAdaptiveBannerAdSize(context, adaptiveWidth))
        } else {
            adView.setAdSize(GmaAdSize(width, height))
        }
        adView.adUnitId = adMobAdUnitId
        adView.adListener = object : AdListener() {
            override fun onAdLoaded() {
                // An adaptive banner's actual height is known once it loads.
                val loaded = adView.adSize?.takeIf { adaptive && it.width > 0 && it.height > 0 }
                methodChannel.invokeMethod(
                    "onAdSize",
                    mapOf(
                        "width" to (loaded?.width ?: width).toDouble(),
                        "height" to (loaded?.height ?: height).toDouble(),
                    ),
                )
                methodChannel.invokeMethod("onAdLoaded", null)
                methodChannel.invokeMethod("onAdDisplayed", null)
            }

            override fun onAdFailedToLoad(error: LoadAdError) {
                methodChannel.invokeMethod("onAdFailed", failure(error.message))
            }

            override fun onAdClicked() {
                methodChannel.invokeMethod("onAdClicked", null)
            }

            override fun onAdImpression() {
                methodChannel.invokeMethod("onAdImpression", null)
            }

            override fun onAdClosed() {
                methodChannel.invokeMethod("onAdClosed", null)
            }
        }

        // Prebid writes the bid's response id into `extras` for the adapter.
        request = AdRequest.Builder()
            .addNetworkExtrasBundle(PrebidBannerAdapter::class.java, extras)
            .build()

        val mediationUtils = AdMobMediationBannerUtils(extras, adView)
        adUnit = MediationBannerAdUnit(
            context,
            configId,
            AdSize(width, height),
            mediationUtils,
        )
        (params["adPosition"] as? Number)?.toInt()?.let { pos ->
            AdPosition.values().firstOrNull { it.value == pos }
                ?.let { adUnit?.setAdPosition(it) }
        }
        (params["impOrtbConfig"] as? String)?.let { adUnit?.setImpOrtbConfig(it) }
        (params["globalOrtbConfig"] as? String)?.let { adUnit?.setGlobalOrtbConfig(it) }
        (params["pbAdSlot"] as? String)?.let { adUnit?.setPbAdSlot(it) }
        if (additionalSizes.isNotEmpty()) adUnit?.addAdditionalSizes(*additionalSizes.toTypedArray())
        // `videoParameters` has no counterpart here: Prebid Android's
        // mediation banner has no video-parameters setter, so a video banner
        // sends the SDK's defaults.
        if (params["adFormats"] != null) {
            adUnit?.setAdUnitFormats(adUnitFormats(params["adFormats"], isVideo = false))
        }
        // 0 means a single request without auto-refresh (also Prebid's
        // default); positive values are clamped by Prebid to 30–120 s.
        refreshInterval?.let { adUnit?.setRefreshInterval(if (it > 0) it else 0) }

        // Calls from PrebidBannerAdController.
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "loadAd" -> {
                    load()
                    result.success(null)
                }

                "stopRefresh" -> {
                    adUnit?.stopRefresh()
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
        // Prebid Android drops requests made before initialization without
        // calling back, so AdMob's waterfall would never run.
        if (!PrebidMobile.isSdkInitialized()) {
            methodChannel.invokeMethod("onAdFailed", failure(PluginErrors.NOT_INITIALIZED))
            return
        }
        adUnit?.fetchDemand {
            if (disposed) return@fetchDemand
            maybeDropBid(dropBidProbability, extras, PrebidBannerAdapter.EXTRA_RESPONSE_ID)
            // The bid (if any) is now attached to the request extras; let
            // AdMob run its waterfall and render.
            adView.loadAd(request)
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
