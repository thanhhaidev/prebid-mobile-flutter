package io.github.thanhhaidev.prebid_mobile_sdk_admob

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
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdOptions
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.prebid.mobile.NativeAdUnit
import org.prebid.mobile.NativeDataAsset
import org.prebid.mobile.NativeImageAsset
import org.prebid.mobile.NativeTitleAsset
import org.prebid.mobile.PrebidMobile
import org.prebid.mobile.admob.PrebidNativeAdapter

/**
 * PlatformView factory for AdMob-mediated native ads. The rendered view is a
 * Google Mobile Ads [NativeAdView] populated with the winning ad's assets;
 * a Prebid [NativeAdUnit] runs the auction and hands the bid to the Prebid
 * native adapter through the AdMob request's extras. Rendering through the SDK's native view keeps impression/click
 * tracking intact.
 */
internal class AdMobNativeAdViewFactory(private val messenger: BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any>()
        return AdMobNativePlatformView(context, viewId, messenger, params)
    }
}

/**
 * One AdMob native ad: the [NativeAdView] populated with the ad AdMob loads
 * after the Prebid auction, reporting to Dart over
 * `prebid_mobile_sdk_admob/native_<channelId>`.
 */
internal class AdMobNativePlatformView(
    context: Context,
    viewId: Int,
    messenger: BinaryMessenger,
    params: Map<*, *>,
) : PlatformView {

    private val nativeAdView = NativeAdView(context)
    private val methodChannel: MethodChannel
    private var adUnit: NativeAdUnit? = null
    private var nativeAd: NativeAd? = null

    // Set once Flutter disposes the view: async SDK callbacks that land later
    // must not load, bind or report anything.
    private var disposed = false

    private val iconView = ImageView(context)
    private val mediaView = MediaView(context)
    private val headlineView = TextView(context)
    private val bodyView = TextView(context)
    private val ctaView = Button(context)

    init {
        val configId = params["configId"] as? String ?: ""
        val adMobAdUnitId = params["adMobAdUnitId"] as? String ?: ""

        methodChannel = MethodChannel(messenger, viewChannelName("prebid_mobile_sdk_admob/native", params, viewId))

        buildLayout(context)

        val extras = Bundle()
        // What Prebid's MediationNativeAdUnit does (fetchDemand with the extras
        // bundle), without its wrapper, which hides the ORTB config setters.
        val adUnit = NativeAdUnit(configId)
        NativeContext.from(params).applyTo(adUnit)
        NativeRequestOptions(params).applyTo(adUnit)
        (params["impOrtbConfig"] as? String)?.let(adUnit::setImpOrtbConfig)
        (params["globalOrtbConfig"] as? String)?.let(adUnit::setGlobalOrtbConfig)
        (nativeAssetsFrom(params["assets"]) ?: nativeAssets()).forEach { adUnit.addAsset(it) }
        (nativeTrackersFrom(params["eventTrackers"]) ?: defaultNativeTrackers()).forEach { adUnit.addEventTracker(it) }
        this.adUnit = adUnit

        val adLoader = AdLoader.Builder(context, adMobAdUnitId)
            .forNativeAd { ad ->
                if (disposed) {
                    ad.destroy()
                    return@forNativeAd
                }
                nativeAd?.destroy()
                nativeAd = ad
                bind(ad)
                methodChannel.invokeMethod("onAdLoaded", null)
                // Measure the natural content height (the view itself is clamped
                // to the current Flutter-side size) and report logical pixels.
                nativeAdView.post {
                    if (disposed) return@post
                    val content = nativeAdView.getChildAt(0) ?: return@post
                    val h = naturalHeight(content, nativeAdView.width)
                    if (h > 0) methodChannel.invokeMethod("onAdSize", mapOf("height" to h))
                }
            }
            .withAdListener(object : AdListener() {
                override fun onAdFailedToLoad(error: LoadAdError) {
                    if (disposed) return
                    methodChannel.invokeMethod("onAdFailed", failure(error.message))
                }

                override fun onAdImpression() {
                    methodChannel.invokeMethod("onAdImpression", null)
                }

                override fun onAdClicked() {
                    methodChannel.invokeMethod("onAdClicked", null)
                }

                override fun onAdOpened() {
                    methodChannel.invokeMethod("onAdOpened", null)
                }
            })
            .withNativeAdOptions(NativeAdOptions.Builder().build())
            .build()

        val request = AdRequest.Builder()
            .addNetworkExtrasBundle(PrebidNativeAdapter::class.java, extras)
            .build()

        // Prebid Android drops requests made before initialization without
        // calling back, so AdMob's waterfall would never run.
        if (!PrebidMobile.isSdkInitialized()) {
            methodChannel.invokeMethod("onAdFailed", failure(PluginErrors.NOT_INITIALIZED))
        } else {
            adUnit.fetchDemand(extras) {
                if (disposed) return@fetchDemand
                adLoader.loadAd(request)
            }
        }
    }

    private fun buildLayout(context: Context) {
        headlineView.textSize = 15f
        bodyView.textSize = 13f
        ctaView.isClickable = false
        ctaView.isAllCaps = false
        iconView.scaleType = ImageView.ScaleType.CENTER_CROP
        mediaView.layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            context.dp(180),
        )

        val header = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(
                iconView,
                LinearLayout.LayoutParams(context.dp(40), context.dp(40)).apply { rightMargin = context.dp(8) },
            )
            addView(headlineView)
        }

        val content = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(context.dp(12), context.dp(12), context.dp(12), context.dp(12))
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
            addView(mediaView)
            addView(header)
            addView(bodyView)
            addView(ctaView)
        }

        nativeAdView.addView(content)
        nativeAdView.iconView = iconView
        nativeAdView.mediaView = mediaView
        nativeAdView.headlineView = headlineView
        nativeAdView.bodyView = bodyView
        nativeAdView.callToActionView = ctaView
    }

    private fun bind(ad: NativeAd) {
        headlineView.text = ad.headline
        bodyView.text = ad.body
        ctaView.text = ad.callToAction
        ad.icon?.drawable?.let { iconView.setImageDrawable(it) }
        ad.mediaContent?.let { mediaView.mediaContent = it }
        nativeAdView.setNativeAd(ad)
    }

    private fun nativeAssets() = listOf(
        NativeTitleAsset().apply {
            setLength(90)
            isRequired = true
        },
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
        disposed = true
        nativeAd?.destroy()
        nativeAd = null
        // Frees its media view's resources, as Google asks.
        nativeAdView.destroy()
        adUnit?.destroy()
    }
}
