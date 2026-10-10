package io.github.thanhhaidev.prebid_mobile_sdk

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
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
import org.prebid.mobile.PrebidNativeAd

/**
 * PlatformView factory for `PrebidNativeAdView`: renders a loaded
 * [PrebidNativeAd] natively and calls `registerView` so Prebid tracks
 * viewability-based impressions and clicks.
 */
internal class NativeAdViewFactory(
    private val messenger: BinaryMessenger,
    private val flutterApi: AdFlutterApi,
    private val store: NativeAdStore,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any>()
        return NativeAdPlatformView(context, viewId, messenger, flutterApi, store, params)
    }
}

/**
 * A `PrebidNativeAdView`: renders the ad natively, or (custom layout) adds
 * a transparent view under the app's Flutter layout and registers it, so
 * Prebid tracks the impression and [NativeAdStore.performClick] reports
 * taps on the Flutter layout as clicks.
 */
internal class NativeAdPlatformView(
    private val context: Context,
    viewId: Int,
    messenger: BinaryMessenger,
    private val flutterApi: AdFlutterApi,
    private val store: NativeAdStore,
    params: Map<*, *>,
) : PlatformView {

    val adId = (params["adId"] as? Number)?.toLong() ?: 0L
    private val customLayout = params["layout"] == "custom"
    private val channelId = (params["channelId"] as? Number)?.toLong() ?: viewId.toLong()
    private val methodChannel =
        MethodChannel(messenger, "prebid_mobile_sdk/native_ad_$channelId")
    private val root = FrameLayout(context)

    init {
        // The fraction of the view Flutter paints on screen, from
        // PrebidNativeAdView: Flutter's clips (scroll viewports, ClipRect)
        // are invisible to the native viewability check.
        methodChannel.setMethodCallHandler { call, result ->
            if (call.method == "setVisibleFraction") {
                (call.arguments as? Number)?.toDouble()?.let {
                    store.listeners[adId]?.flutterVisibleFraction = it
                }
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
        store.attach(this)
        show()
    }

    /**
     * Shows the ad's registered view, or renders and registers the ad the
     * first time; also called by the store when the ad is reloaded.
     */
    fun show() {
        root.removeAllViews()
        val existing = store.views[adId]
        val ad = store.ads[adId]
        if (existing != null) {
            (existing.parent as? ViewGroup)?.removeView(existing)
            if (customLayout) {
                root.addView(existing, matchParent())
            } else {
                root.addView(existing, matchWidth())
                reportHeight(existing)
            }
        } else if (ad != null) {
            if (customLayout) track(ad) else render(ad)
        }
    }

    /** Custom layout: registers an empty view that fills the Flutter layout. */
    private fun track(ad: PrebidNativeAd) {
        val container = FrameLayout(context)
        val events = NativeAdEvents(adId, flutterApi)
        if (!ad.registerView(container, listOf(container), events)) return expire(events)
        root.addView(container, matchParent())
        store.listeners[adId] = events
        store.views[adId] = container
        events.watchViewability(container)
    }

    /** The bid expired before the ad was shown: Prebid won't track it. */
    private fun expire(events: NativeAdEvents) {
        store.ads.remove(adId)
        events.onAdExpired()
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

        val events = NativeAdEvents(adId, flutterApi)
        val registered = ad.registerView(
            container,
            listOf(iconView, titleView, imageView, bodyView, ctaView),
            events,
        )
        // An expired bid can't be registered, and its expiry callback needs
        // a registered view: report the expiry here.
        if (!registered) return expire(events)
        root.addView(container, matchWidth())
        store.listeners[adId] = events
        store.views[adId] = container
        events.watchViewability(container)
        reportHeight(container)
        // Decoded at the size the views draw them (icon 40dp square, image
        // full width x 180dp).
        downloadImage(ad.iconUrl, iconView, container, dp(40), dp(40))
        downloadImage(ad.imageUrl, imageView, container, context.resources.displayMetrics.widthPixels, dp(180))
    }

    /**
     * Reports the content's natural height (root is clamped to the current
     * Flutter-side size) in logical pixels.
     */
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

    private fun matchParent() = FrameLayout.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.MATCH_PARENT,
    )

    private fun matchWidth() = FrameLayout.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.WRAP_CONTENT,
    )

    private fun spaced() = LinearLayout.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.WRAP_CONTENT,
    ).apply { topMargin = dp(8) }

    private fun dp(value: Int): Int = (value * context.resources.displayMetrics.density).toInt()

    /**
     * Best-effort image load: the ad still renders without it. Skipped once
     * the ad is destroyed or reloaded ([container] no longer its view).
     */
    private fun downloadImage(url: String?, target: ImageView, container: View, width: Int, height: Int) {
        if (url.isNullOrEmpty()) return
        val load = NativeImageLoader.executor.submit {
            val bitmap = NativeImageLoader.load(url, width, height) ?: return@submit
            NativeImageLoader.mainHandler.post {
                if (store.views[adId] === container) target.setImageBitmap(bitmap)
            }
        }
        store.imageLoads.getOrPut(adId) { mutableListOf() } += load
    }

    override fun getView(): View = root

    override fun dispose() {
        // Keep the registered view for a re-created platform view; detach it
        // so it doesn't keep this one alive. NativeAdStore.remove drops it.
        methodChannel.setMethodCallHandler(null)
        store.detach(this)
        root.removeAllViews()
    }
}
