package com.prebid.prebid_mobile_sdk_gam

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.gms.ads.AdLoader
import com.google.android.gms.ads.AdListener
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.admanager.AdManagerAdRequest
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class GamNativeAdViewFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any>()
        return GamNativePlatformView(context, messenger, params)
    }
}

class GamNativePlatformView(
    context: Context,
    messenger: BinaryMessenger,
    params: Map<*, *>,
) : PlatformView {

    private val logicalId = (params["logicalId"] as? Number)?.toLong() ?: 0L
    private val nativeAdView = NativeAdView(context)
    private val methodChannel = MethodChannel(messenger, "prebid_mobile_sdk_gam/native_$logicalId")
    private var nativeAd: NativeAd? = null

    private val iconView = ImageView(context)
    private val mediaView = MediaView(context)
    private val imageView = ImageView(context)
    private val advertiserView = TextView(context)
    private val headlineView = TextView(context)
    private val bodyView = TextView(context)
    private val ctaView = Button(context)

    init {
        buildLayout(context)
        val gamAdUnitId = params["gamAdUnitId"] as? String ?: ""
        val targeting = params["customTargeting"] as? Map<*, *> ?: emptyMap<String, Any>()

        val requestBuilder = AdManagerAdRequest.Builder()
        targeting.forEach { (key, value) ->
            if (key is String && value is String) {
                requestBuilder.addCustomTargeting(key, value)
            }
        }

        val loader = AdLoader.Builder(context, gamAdUnitId)
            .forNativeAd { ad ->
                nativeAd = ad
                bind(ad)
                methodChannel.invokeMethod("onAdLoaded", null)
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
        loader.loadAd(requestBuilder.build())
    }

    private fun buildLayout(context: Context) {
        headlineView.textSize = 15f
        headlineView.setTypeface(Typeface.DEFAULT, Typeface.BOLD)
        advertiserView.textSize = 11f
        advertiserView.setTextColor(Color.GRAY)
        bodyView.textSize = 13f
        bodyView.setTextColor(Color.DKGRAY)
        ctaView.isClickable = false
        ctaView.isAllCaps = false
        iconView.scaleType = ImageView.ScaleType.CENTER_CROP
        mediaView.layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            420,
        )
        imageView.scaleType = ImageView.ScaleType.CENTER_CROP
        imageView.visibility = View.GONE
        imageView.layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            420,
        )

        val header = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(
                iconView,
                LinearLayout.LayoutParams(96, 96).apply { rightMargin = 24 },
            )
            addView(
                LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    addView(advertiserView)
                    addView(headlineView)
                },
                LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f),
            )
        }

        val content = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(24, 24, 24, 24)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
            addView(mediaView)
            addView(imageView)
            addView(header)
            addView(bodyView)
            addView(ctaView)
        }

        nativeAdView.addView(content)
        nativeAdView.iconView = iconView
        nativeAdView.mediaView = mediaView
        nativeAdView.imageView = imageView
        nativeAdView.advertiserView = advertiserView
        nativeAdView.headlineView = headlineView
        nativeAdView.bodyView = bodyView
        nativeAdView.callToActionView = ctaView
    }

    private fun bind(ad: NativeAd) {
        headlineView.text = ad.headline
        advertiserView.text = ad.advertiser ?: "Sponsored"
        bodyView.text = ad.body
        ctaView.text = ad.callToAction
        ad.icon?.drawable?.let { iconView.setImageDrawable(it) }
        if (ad.mediaContent != null) {
            mediaView.mediaContent = ad.mediaContent
            mediaView.visibility = View.VISIBLE
            imageView.visibility = View.GONE
        } else {
            val image = ad.images.firstOrNull()?.drawable
            if (image != null) {
                imageView.setImageDrawable(image)
                imageView.visibility = View.VISIBLE
                mediaView.visibility = View.GONE
            } else {
                mediaView.visibility = View.GONE
                imageView.visibility = View.GONE
            }
        }
        nativeAdView.setNativeAd(ad)
    }

    override fun getView(): View = nativeAdView

    override fun dispose() {
        nativeAd?.destroy()
    }
}
