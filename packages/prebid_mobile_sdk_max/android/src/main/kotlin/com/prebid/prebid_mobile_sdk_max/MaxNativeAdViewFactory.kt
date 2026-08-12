package com.prebid.prebid_mobile_sdk_max

import android.app.Activity
import android.content.Context
import android.view.View
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

    init {
        val configId = params["configId"] as? String ?: ""
        val maxAdUnitId = params["maxAdUnitId"] as? String ?: ""

        methodChannel = MethodChannel(messenger, "prebid_mobile_sdk_max/native_$viewId")

        nativeAdLoader = MaxNativeAdLoader(maxAdUnitId, context)
        nativeAdLoader.setNativeAdListener(object : MaxNativeAdListener() {
            override fun onNativeAdLoaded(nativeAdView: MaxNativeAdView?, ad: MaxAd) {
                loadedNativeAd?.let { nativeAdLoader.destroy(it) }
                loadedNativeAd = ad
                container.removeAllViews()
                if (nativeAdView != null) container.addView(nativeAdView)
                methodChannel.invokeMethod("onAdLoaded", null)
                container.post {
                    val h = container.height
                    if (h > 0) {
                        methodChannel.invokeMethod("onAdSize", mapOf("height" to h.toDouble()))
                    }
                }
            }

            override fun onNativeAdLoadFailed(adUnitId: String, error: MaxError) {
                methodChannel.invokeMethod("onAdFailed", error.message)
            }

            override fun onNativeAdClicked(ad: MaxAd) {
                methodChannel.invokeMethod("onAdClicked", null)
            }
        })

        nativeAdUnit = NativeAdUnit(configId)
        configureNativeAdUnit(nativeAdUnit)

        nativeAdUnit.fetchDemand(nativeAdLoader) {
            nativeAdLoader.loadAd(createNativeAdView())
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

    private fun configureNativeAdUnit(nativeAdUnit: NativeAdUnit) {
        nativeAdUnit.setContextType(NativeAdUnit.CONTEXT_TYPE.SOCIAL_CENTRIC)
        nativeAdUnit.setPlacementType(NativeAdUnit.PLACEMENTTYPE.CONTENT_FEED)
        nativeAdUnit.setContextSubType(NativeAdUnit.CONTEXTSUBTYPE.GENERAL_SOCIAL)

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

        nativeAdUnit.addEventTracker(
            NativeEventTracker(
                NativeEventTracker.EVENT_TYPE.IMPRESSION,
                arrayListOf(
                    NativeEventTracker.EVENT_TRACKING_METHOD.IMAGE,
                    NativeEventTracker.EVENT_TRACKING_METHOD.JS,
                ),
            ),
        )
    }

    override fun getView(): View = container

    override fun dispose() {
        loadedNativeAd?.let { nativeAdLoader.destroy(it) }
        nativeAdLoader.destroy()
        nativeAdUnit.destroy()
    }
}
