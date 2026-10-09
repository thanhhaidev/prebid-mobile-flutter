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

    /// The rendered, registered view of each ad. `registerView` creates new
    /// impression trackers on every call, so an ad is registered once and its
    /// view is moved into any platform view re-created for the same ad (e.g.
    /// after scrolling out of a list and back).
    val views = mutableMapOf<Long, View>()

    /// Held here: Prebid keeps only a WeakReference to the listener.
    val listeners = mutableMapOf<Long, PrebidNativeAdEventListener>()

    fun remove(adId: Long) {
        ads.remove(adId)
        listeners.remove(adId)
        views.remove(adId)?.let { (it.parent as? ViewGroup)?.removeView(it) }
    }
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

    init {
        val existing = NativeAdStore.views[adId]
        val ad = NativeAdStore.ads[adId]
        if (existing != null) {
            (existing.parent as? ViewGroup)?.removeView(existing)
            root.addView(existing, matchWidth())
            reportHeight(existing)
        } else if (ad != null) {
            render(ad)
        }
    }

    private fun eventListener(): PrebidNativeAdEventListener {
        val adId = adId
        val flutterApi = flutterApi
        // Prebid calls onAdImpression once per impression tracker URL, from a
        // background thread; report a single impression per ad, on main.
        val impressionReported = java.util.concurrent.atomic.AtomicBoolean(false)
        fun send(name: String) = Handler(Looper.getMainLooper()).post {
            flutterApi.onAdEvent(AdEvent(adId = adId, eventName = name)) {}
        }
        return object : PrebidNativeAdEventListener {
            override fun onAdClicked() { send("onAdClicked") }

            override fun onAdImpression() {
                if (impressionReported.compareAndSet(false, true)) send("onAdImpression")
            }

            override fun onAdExpired() { send("onAdExpired") }
        }
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

        root.addView(container, matchWidth())
        val listener = eventListener()
        NativeAdStore.listeners[adId] = listener
        NativeAdStore.views[adId] = container
        ad.registerView(
            container,
            listOf(iconView, titleView, imageView, bodyView, ctaView),
            listener,
        )
        reportHeight(container)
    }

    /// Reports the content's natural height (root is clamped to the current
    /// Flutter-side size) in logical pixels.
    private fun reportHeight(content: View) {
        root.post {
            content.measure(
                View.MeasureSpec.makeMeasureSpec(root.width, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            )
            val h = content.measuredHeight / context.resources.displayMetrics.density
            if (h > 0) {
                methodChannel.invokeMethod("onAdSize", mapOf("height" to h.toDouble()))
            }
        }
    }

    private fun matchWidth() = FrameLayout.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.WRAP_CONTENT,
    )

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
        // Keep the registered view for a re-created platform view; detach it
        // so it doesn't keep this one alive. NativeAdStore.remove drops it.
        root.removeAllViews()
    }
}
