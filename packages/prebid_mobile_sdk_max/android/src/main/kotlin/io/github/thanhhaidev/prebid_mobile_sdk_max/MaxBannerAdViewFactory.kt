package io.github.thanhhaidev.prebid_mobile_sdk_max

import android.app.Activity
import android.content.Context
import android.view.View
import com.applovin.mediation.MaxAd
import com.applovin.mediation.MaxAdFormat
import com.applovin.mediation.MaxAdViewAdListener
import com.applovin.mediation.MaxError
import com.applovin.mediation.adapters.PrebidMaxMediationAdapter
import com.applovin.mediation.adapters.prebid.utils.MaxMediationBannerUtils
import com.applovin.mediation.ads.MaxAdView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.prebid.mobile.AdSize
import org.prebid.mobile.PrebidMobile
import org.prebid.mobile.api.mediation.MediationBannerAdUnit
import org.prebid.mobile.rendering.models.AdPosition

/**
 * PlatformView factory for AppLovin MAX-mediated banners. The rendered view is
 * the MAX [MaxAdView]; Prebid's [MediationBannerAdUnit] runs the auction and
 * passes the winning bid to MAX via the Prebid MAX adapter.
 */
internal class MaxBannerAdViewFactory(
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

/**
 * One MAX banner: a [MaxAdView] that the Prebid [MediationBannerAdUnit]'s
 * auction bids into. Events go to the widget over
 * `prebid_mobile_sdk_max/banner_<channelId>`.
 */
internal class MaxBannerPlatformView(
    context: Context,
    viewId: Int,
    messenger: BinaryMessenger,
    params: Map<*, *>,
) : PlatformView {

    private val adView: MaxAdView
    private val methodChannel: MethodChannel
    private var adUnit: MediationBannerAdUnit? = null
    private val dropBidProbability: Double

    // Set once Flutter disposes the view: an auction finishing later must not
    // load into the destroyed MaxAdView.
    private var disposed = false

    init {
        val configId = params["configId"] as? String ?: ""
        val maxAdUnitId = params["maxAdUnitId"] as? String ?: ""
        val width = params["width"] as? Int ?: 320
        val height = params["height"] as? Int ?: 50
        val autoLoad = params["autoLoad"] as? Boolean ?: true
        val refreshInterval = params["refreshIntervalSeconds"] as? Int
        // Flat [w, h, w, h, ...] list of extra Prebid request sizes.
        val additionalSizes = (params["additionalSizes"] as? List<*>).orEmpty()
            .mapNotNull { (it as? Number)?.toInt() }
            .chunked(2)
            .filter { it.size == 2 }
            .map { (w, h) -> AdSize(w, h) }
        dropBidProbability = debugDropBidProbability(params["debugDropBidProbability"])

        methodChannel = MethodChannel(messenger, viewChannelName("prebid_mobile_sdk_max/banner", params, viewId))

        // MaxAdView defaults to the banner format; an MREC ad unit needs the
        // MREC format or MAX rejects it.
        val isMrec = width == 300 && height == 250
        val format = if (isMrec) {
            MaxAdFormat.MREC
        } else {
            MaxAdFormat.BANNER
        }
        adView = MaxAdView(maxAdUnitId, format, context)
        // Adaptive banner (banner format only): full measured width, at the
        // height MAX computes for it — as the original Prebid test app does.
        var viewWidth = width
        var viewHeight = height
        if (params["adaptive"] as? Boolean == true && !isMrec) {
            val adaptiveWidth = (params["adaptiveWidth"] as? Number)?.toInt() ?: width
            adView.setExtraParameter("adaptive_banner", "true")
            val size = format.getAdaptiveSize(adaptiveWidth, context)
            viewWidth = adaptiveWidth
            if (size.height > 0) viewHeight = size.height
        }
        adView.setListener(object : MaxAdViewAdListener {
            override fun onAdLoaded(ad: MaxAd) {
                methodChannel.invokeMethod(
                    "onAdSize",
                    mapOf("width" to viewWidth.toDouble(), "height" to viewHeight.toDouble()),
                )
                methodChannel.invokeMethod("onAdLoaded", null)
                methodChannel.invokeMethod("onAdDisplayed", null)
            }

            override fun onAdLoadFailed(adUnitId: String, error: MaxError) {
                methodChannel.invokeMethod("onAdFailed", failure(error.message))
            }

            override fun onAdDisplayFailed(ad: MaxAd, error: MaxError) {
                // Dart reports it through onAdFailed too.
                methodChannel.invokeMethod("onAdDisplayFailed", failure(error.message))
            }

            override fun onAdClicked(ad: MaxAd) {
                methodChannel.invokeMethod("onAdClicked", null)
            }

            override fun onAdHidden(ad: MaxAd) {
                methodChannel.invokeMethod("onAdClosed", null)
            }

            override fun onAdExpanded(ad: MaxAd) {
                methodChannel.invokeMethod("onAdExpanded", null)
            }

            override fun onAdCollapsed(ad: MaxAd) {
                methodChannel.invokeMethod("onAdCollapsed", null)
            }

            override fun onAdDisplayed(ad: MaxAd) {}
        })

        // MAX reports revenue when the impression is recorded.
        adView.setRevenueListener { ad ->
            methodChannel.invokeMethod("onAdImpression", null)
            methodChannel.invokeMethod("onAdRevenuePaid", revenuePayload(ad))
        }

        val mediationUtils = MaxMediationBannerUtils(adView)
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
        // The mediation banner has no video-parameters setter on Android, so a
        // video format is requested with the SDK's default video signals.
        adUnitFormatsFrom(params["adFormats"])?.let { adUnit?.setAdUnitFormats(it) }
        if (additionalSizes.isNotEmpty()) adUnit?.addAdditionalSizes(*additionalSizes.toTypedArray())
        // 0 means a single request without auto-refresh (also Prebid's
        // default); positive values are clamped by Prebid to 30–120 s.
        refreshInterval?.let { adUnit?.setRefreshInterval(if (it > 0) it else 0) }

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
        // Prebid Android drops requests made before init without calling
        // back: report it instead of leaving the slot empty and silent.
        if (!PrebidMobile.isSdkInitialized()) {
            methodChannel.invokeMethod("onAdFailed", failure(PluginErrors.NOT_INITIALIZED))
            return
        }
        adUnit?.fetchDemand {
            if (disposed) return@fetchDemand
            if (shouldDropBid(dropBidProbability)) {
                adView.setLocalExtraParameter(PrebidMaxMediationAdapter.EXTRA_RESPONSE_ID, "")
            }
            adView.loadAd()
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
