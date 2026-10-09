package com.prebid.prebid_mobile_sdk

import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Typeface
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.net.URL
import org.prebid.mobile.PrebidNativeAd
import org.prebid.mobile.PrebidNativeAdEventListener

/// Loaded In-App native ads, keyed by the Dart ad id, so a
/// [NativeAdPlatformView] can render and register the ad for tracking.
object NativeAdStore {
    val ads = mutableMapOf<Long, PrebidNativeAd>()
}

/// PlatformView factory for `PrebidNativeAdView`: renders a loaded
/// [PrebidNativeAd] natively and calls `registerView` so Prebid tracks
/// viewability-based impressions and clicks.
class NativeAdViewFactory(
    private val messenger: BinaryMessenger,
    private val flutterApi: AdFlutterApi,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any>()
        return NativeAdPlatformView(context, viewId, messenger, flutterApi, params)
    }
}

class NativeAdPlatformView(
    private val context: Context,
    viewId: Int,
    messenger: BinaryMessenger,
    private val flutterApi: AdFlutterApi,
    params: Map<*, *>,
) : PlatformView {

    private val adId = (params["adId"] as? Number)?.toLong() ?: 0L
    private val methodChannel =
        MethodChannel(messenger, "prebid_mobile_flutter/native_ad_$viewId")
    private val root = FrameLayout(context)
    private val mainHandler = Handler(Looper.getMainLooper())

    // Prebid calls onAdImpression once per impression tracker URL; report a
    // single impression per ad.
    private val impressionReported = java.util.concurrent.atomic.AtomicBoolean(false)

    // Held as a field: Prebid keeps only a WeakReference to the listener.
    // Prebid fires impressions from a background thread, so hop to main.
    private val eventListener = object : PrebidNativeAdEventListener {
        override fun onAdClicked() = sendEvent("onAdClicked")

        override fun onAdImpression() {
            if (impressionReported.compareAndSet(false, true)) sendEvent("onAdImpression")
        }

        override fun onAdExpired() = sendEvent("onAdExpired")
    }

    init {
        val ad = NativeAdStore.ads[adId]
        if (ad != null) render(ad)
    }

    private fun render(ad: PrebidNativeAd) {
        val iconView = ImageView(context)
        val imageView = ImageView(context)
        val titleView = TextView(context)
        val sponsoredView = TextView(context)
        val bodyView = TextView(context)
        val ctaView = Button(context)

        titleView.text = ad.title
        titleView.textSize = 15f
        titleView.setTypeface(Typeface.DEFAULT, Typeface.BOLD)
        sponsoredView.text = ad.sponsoredBy
        sponsoredView.textSize = 11f
        sponsoredView.setTextColor(Color.GRAY)
        bodyView.text = ad.description
        bodyView.textSize = 13f
        bodyView.setTextColor(Color.DKGRAY)
        ctaView.text = ad.callToAction
        ctaView.isAllCaps = false
        iconView.scaleType = ImageView.ScaleType.FIT_CENTER
        imageView.scaleType = ImageView.ScaleType.CENTER_CROP
        imageView.layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(180),
        )
        if (ad.imageUrl.isNullOrEmpty()) imageView.visibility = View.GONE
        // Hide asset views the ad doesn't carry (e.g. data-only creatives).
        if (ad.iconUrl.isNullOrEmpty()) iconView.visibility = View.GONE
        if (ad.title.isNullOrEmpty()) titleView.visibility = View.GONE
        if (ad.sponsoredBy.isNullOrEmpty()) sponsoredView.visibility = View.GONE
        if (ad.description.isNullOrEmpty()) bodyView.visibility = View.GONE
        if (ad.callToAction.isNullOrEmpty()) ctaView.visibility = View.GONE
        downloadImage(ad.iconUrl, iconView)
        downloadImage(ad.imageUrl, imageView)

        val header = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(
                iconView,
                LinearLayout.LayoutParams(dp(40), dp(40)).apply { rightMargin = dp(8) },
            )
            addView(
                LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    addView(sponsoredView)
                    addView(titleView)
                },
                LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f),
            )
        }

        val container = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(12), dp(12), dp(12), dp(12))
            addView(imageView)
            addView(header, spaced())
            addView(bodyView, spaced())
            addView(ctaView, spaced())
        }

        root.addView(
            container,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ),
        )
        ad.registerView(
            container,
            listOf(iconView, titleView, imageView, bodyView, ctaView),
            eventListener,
        )

        // Report the content's natural height (root is clamped to the current
        // Flutter-side size) in logical pixels.
        root.post {
            container.measure(
                View.MeasureSpec.makeMeasureSpec(root.width, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            )
            val h = container.measuredHeight / context.resources.displayMetrics.density
            if (h > 0) {
                methodChannel.invokeMethod("onAdSize", mapOf("height" to h.toDouble()))
            }
        }
    }

    private fun sendEvent(name: String) {
        mainHandler.post {
            flutterApi.onAdEvent(AdEvent(adId = adId, eventName = name)) {}
        }
    }

    private fun spaced() = LinearLayout.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.WRAP_CONTENT,
    ).apply { topMargin = dp(8) }

    private fun dp(value: Int): Int =
        (value * context.resources.displayMetrics.density).toInt()

    private fun downloadImage(url: String?, target: ImageView) {
        if (url.isNullOrEmpty()) return
        Thread {
            try {
                val bitmap = URL(url).openStream().use { BitmapFactory.decodeStream(it) }
                if (bitmap != null) target.post { target.setImageBitmap(bitmap) }
            } catch (e: Exception) {
                // Best-effort image load; the ad still renders without it.
            }
        }.start()
    }

    override fun getView(): View = root

    override fun dispose() {
        mainHandler.removeCallbacksAndMessages(null)
    }
}
