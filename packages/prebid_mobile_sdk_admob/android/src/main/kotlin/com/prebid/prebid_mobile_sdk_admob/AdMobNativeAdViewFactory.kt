package com.prebid.prebid_mobile_sdk_admob

import android.content.Context
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.gms.ads.AdListener
import com.google.android.gms.ads.AdLoader
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.prebid.mobile.NativeDataAsset
import org.prebid.mobile.NativeEventTracker
import org.prebid.mobile.NativeImageAsset
import org.prebid.mobile.NativeTitleAsset
import org.prebid.mobile.admob.PrebidNativeAdapter
import org.prebid.mobile.api.mediation.MediationNativeAdUnit

/// PlatformView factory for AdMob-mediated native ads. The rendered view is a
/// Google Mobile Ads [NativeAdView] populated with the winning ad's assets;
/// Prebid's [MediationNativeAdUnit] runs the auction via the Prebid native
/// adapter. Rendering through the SDK's native view keeps impression/click
/// tracking intact.
class AdMobNativeAdViewFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any>()
        return AdMobNativePlatformView(context, viewId, messenger, params)
    }
}

class AdMobNativePlatformView(
    context: Context,
    viewId: Int,
    messenger: BinaryMessenger,
    params: Map<*, *>,
) : PlatformView {

    private val nativeAdView = NativeAdView(context)
    private val methodChannel: MethodChannel
    private var adUnit: MediationNativeAdUnit? = null
    private var nativeAd: NativeAd? = null

    private val iconView = ImageView(context)
    private val headlineView = TextView(context)
    private val bodyView = TextView(context)
    private val ctaView = Button(context)

    init {
        val configId = params["configId"] as? String ?: ""
        val adMobAdUnitId = params["adMobAdUnitId"] as? String ?: ""

        methodChannel = MethodChannel(messenger, "prebid_mobile_sdk_admob/native_$viewId")

        buildLayout(context)

        val extras = Bundle()
        val adUnit = MediationNativeAdUnit(configId, extras)
        nativeAssets().forEach { adUnit.addAsset(it) }
        adUnit.addEventTracker(
            NativeEventTracker(
                NativeEventTracker.EVENT_TYPE.IMPRESSION,
                arrayListOf(
                    NativeEventTracker.EVENT_TRACKING_METHOD.IMAGE,
                    NativeEventTracker.EVENT_TRACKING_METHOD.JS,
                ),
            ),
        )
        this.adUnit = adUnit

        val adLoader = AdLoader.Builder(context, adMobAdUnitId)
            .forNativeAd { ad ->
                nativeAd = ad
                bind(ad)
                methodChannel.invokeMethod("onAdLoaded", null)
                nativeAdView.post {
                    val h = nativeAdView.height
                    if (h > 0) {
                        methodChannel.invokeMethod("onAdSize", mapOf("height" to h.toDouble()))
                    }
                }
            }
            .withAdListener(object : AdListener() {
                override fun onAdFailedToLoad(error: LoadAdError) {
                    methodChannel.invokeMethod("onAdFailed", error.message)
                }

                override fun onAdClicked() {
                    methodChannel.invokeMethod("onAdClicked", null)
                }
            })
            .build()

        val request = AdRequest.Builder()
            .addNetworkExtrasBundle(PrebidNativeAdapter::class.java, extras)
            .build()

        adUnit.fetchDemand {
            adLoader.loadAd(request)
        }
    }

    private fun buildLayout(context: Context) {
        headlineView.textSize = 15f
        bodyView.textSize = 13f
        ctaView.isClickable = false

        val header = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(
                iconView,
                LinearLayout.LayoutParams(96, 96).apply { rightMargin = 24 },
            )
            addView(headlineView)
        }

        val content = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(24, 24, 24, 24)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
            addView(header)
            addView(bodyView)
            addView(ctaView)
        }

        nativeAdView.addView(content)
        nativeAdView.iconView = iconView
        nativeAdView.headlineView = headlineView
        nativeAdView.bodyView = bodyView
        nativeAdView.callToActionView = ctaView
    }

    private fun bind(ad: NativeAd) {
        headlineView.text = ad.headline
        bodyView.text = ad.body
        ctaView.text = ad.callToAction
        ad.icon?.drawable?.let { iconView.setImageDrawable(it) }
        nativeAdView.setNativeAd(ad)
    }

    private fun nativeAssets() = listOf(
        NativeTitleAsset().apply { setLength(90); isRequired = true },
        NativeImageAsset(20, 20, 20, 20).apply {
            imageType = NativeImageAsset.IMAGE_TYPE.ICON
            isRequired = true
        },
        NativeDataAsset().apply {
            dataType = NativeDataAsset.DATA_TYPE.SPONSORED
            isRequired = true
        },
        NativeDataAsset().apply {
            dataType = NativeDataAsset.DATA_TYPE.DESC
            isRequired = true
        },
        NativeDataAsset().apply {
            dataType = NativeDataAsset.DATA_TYPE.CTATEXT
            isRequired = true
        },
    )

    override fun getView(): View = nativeAdView

    override fun dispose() {
        nativeAd?.destroy()
        adUnit?.destroy()
    }
}
