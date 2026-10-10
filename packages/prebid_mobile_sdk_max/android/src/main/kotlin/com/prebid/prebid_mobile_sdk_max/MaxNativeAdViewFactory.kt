package com.prebid.prebid_mobile_sdk_max

import android.app.Activity
import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.applovin.mediation.MaxAd
import com.applovin.mediation.MaxError
import com.applovin.mediation.nativeAds.MaxNativeAdListener
import com.applovin.mediation.nativeAds.MaxNativeAdLoader
import com.applovin.mediation.nativeAds.MaxNativeAdView
import com.applovin.mediation.nativeAds.MaxNativeAdViewBinder
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.prebid.mobile.NativeAdUnit
import org.prebid.mobile.NativeDataAsset
import org.prebid.mobile.NativeEventTracker
import org.prebid.mobile.NativeImageAsset
import org.prebid.mobile.NativeTitleAsset

/// PlatformView factory for AppLovin MAX-mediated native ads. Prebid's
/// [NativeAdUnit] runs the auction and hands demand to the MAX
/// [MaxNativeAdLoader], which renders into a [MaxNativeAdView] bound via
/// [MaxNativeAdViewBinder] (layout `prebid_max_native_ad`).
class MaxNativeAdViewFactory(
    private val messenger: BinaryMessenger,
    private val activityProvider: () -> Activity?,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any>()
        return MaxNativePlatformView(
            activityProvider() ?: context,
            viewId,
            messenger,
            params,
        )
    }
}

class MaxNativePlatformView(
    private val context: Context,
    viewId: Int,
    messenger: BinaryMessenger,
    params: Map<*, *>,
) : PlatformView {

    private val container = FrameLayout(context)
    private val methodChannel: MethodChannel
    private val nativeAdLoader: MaxNativeAdLoader
    private val nativeAdUnit: NativeAdUnit
    private var loadedNativeAd: MaxAd? = null

    // Set once Flutter disposes the view: async SDK callbacks that land later
    // must not load, render or report anything.
    private var disposed = false

    init {
        val configId = params["configId"] as? String ?: ""
        val maxAdUnitId = params["maxAdUnitId"] as? String ?: ""

        methodChannel = MethodChannel(messenger, "prebid_mobile_sdk_max/native_$viewId")

        nativeAdLoader = MaxNativeAdLoader(maxAdUnitId, context)
        nativeAdLoader.setNativeAdListener(object : MaxNativeAdListener() {
            override fun onNativeAdLoaded(nativeAdView: MaxNativeAdView?, ad: MaxAd) {
                if (disposed) {
                    nativeAdLoader.destroy(ad)
                    return
                }
                loadedNativeAd?.let { nativeAdLoader.destroy(it) }
                loadedNativeAd = ad
                container.removeAllViews()
                if (nativeAdView != null) {
                    container.addView(
                        nativeAdView,
                        FrameLayout.LayoutParams(
                            ViewGroup.LayoutParams.MATCH_PARENT,
                            ViewGroup.LayoutParams.WRAP_CONTENT,
                        ),
                    )
                }
                methodChannel.invokeMethod("onAdLoaded", null)
                if (nativeAdView != null) reportContentHeight(nativeAdView)
            }

            override fun onNativeAdLoadFailed(adUnitId: String, error: MaxError) {
                methodChannel.invokeMethod("onAdFailed", error.message)
            }

            override fun onNativeAdClicked(ad: MaxAd) {
                methodChannel.invokeMethod("onAdClicked", null)
            }
        })

        // MAX reports revenue when the impression is recorded.
        nativeAdLoader.setRevenueListener { ad ->
            methodChannel.invokeMethod("onAdImpression", null)
            methodChannel.invokeMethod("onAdRevenuePaid", revenuePayload(ad))
        }

        nativeAdUnit = NativeAdUnit(configId)
        configureNativeAdUnit(nativeAdUnit, params)

        nativeAdUnit.fetchDemand(nativeAdLoader) {
            if (!disposed) nativeAdLoader.loadAd(createNativeAdView())
        }
    }

    /// Measures the content's natural height (the container is clamped to the
    /// current Flutter-side size, so its own height would only echo that) and
    /// reports it in logical pixels.
    private fun reportContentHeight(content: View) {
        container.post {
            if (disposed) return@post
            content.measure(
                View.MeasureSpec.makeMeasureSpec(container.width, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            )
            val h = content.measuredHeight / container.resources.displayMetrics.density
            if (h > 0) {
                methodChannel.invokeMethod("onAdSize", mapOf("height" to h.toDouble()))
            }
        }
    }

    private fun createNativeAdView(): MaxNativeAdView {
        val binder = MaxNativeAdViewBinder.Builder(R.layout.prebid_max_native_ad)
            .setTitleTextViewId(R.id.prebid_native_title)
            .setBodyTextViewId(R.id.prebid_native_body)
            .setIconImageViewId(R.id.prebid_native_icon)
            .setMediaContentViewGroupId(R.id.prebid_native_media)
            .setCallToActionButtonId(R.id.prebid_native_cta)
            .build()
        return MaxNativeAdView(binder, context)
    }

    private fun configureNativeAdUnit(nativeAdUnit: NativeAdUnit, params: Map<*, *>) {
        nativeAdUnit.setContextType(NativeAdUnit.CONTEXT_TYPE.SOCIAL_CENTRIC)
        nativeAdUnit.setPlacementType(NativeAdUnit.PLACEMENTTYPE.CONTENT_FEED)
        nativeAdUnit.setContextSubType(NativeAdUnit.CONTEXTSUBTYPE.GENERAL_SOCIAL)
        NativeContext.from(params).let { c ->
            c.context?.let { nativeAdUnit.setContextType(it) }
            c.subType?.let { nativeAdUnit.setContextSubType(it) }
            c.placement?.let { nativeAdUnit.setPlacementType(it) }
        }

        val customAssets = nativeAssetsFrom(params["assets"])
        if (customAssets != null) {
            customAssets.forEach { nativeAdUnit.addAsset(it) }
            (nativeTrackersFrom(params["eventTrackers"]) ?: listOf(defaultTracker()))
                .forEach { nativeAdUnit.addEventTracker(it) }
            return
        }

        val title = NativeTitleAsset().apply { setLength(90); isRequired = true }
        nativeAdUnit.addAsset(title)

        val icon = NativeImageAsset(20, 20, 20, 20).apply {
            imageType = NativeImageAsset.IMAGE_TYPE.ICON
            isRequired = true
        }
        nativeAdUnit.addAsset(icon)

        val sponsored = NativeDataAsset().apply {
            dataType = NativeDataAsset.DATA_TYPE.SPONSORED
            isRequired = true
        }
        nativeAdUnit.addAsset(sponsored)

        val body = NativeDataAsset().apply {
            dataType = NativeDataAsset.DATA_TYPE.DESC
            isRequired = true
        }
        nativeAdUnit.addAsset(body)

        val cta = NativeDataAsset().apply {
            dataType = NativeDataAsset.DATA_TYPE.CTATEXT
            isRequired = true
        }
        nativeAdUnit.addAsset(cta)

        (nativeTrackersFrom(params["eventTrackers"]) ?: listOf(defaultTracker()))
            .forEach { nativeAdUnit.addEventTracker(it) }
    }

    private fun defaultTracker() = NativeEventTracker(
        NativeEventTracker.EVENT_TYPE.IMPRESSION,
        arrayListOf(
            NativeEventTracker.EVENT_TRACKING_METHOD.IMAGE,
            NativeEventTracker.EVENT_TRACKING_METHOD.JS,
        ),
    )

    override fun getView(): View = container

    override fun dispose() {
        disposed = true
        loadedNativeAd?.let { nativeAdLoader.destroy(it) }
        loadedNativeAd = null
        nativeAdLoader.destroy()
        nativeAdUnit.destroy()
    }
}
