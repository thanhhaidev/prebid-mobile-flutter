package io.github.thanhhaidev.prebid_mobile_sdk

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Rect
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
import java.io.ByteArrayOutputStream
import java.lang.ref.WeakReference
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.atomic.AtomicBoolean
import org.prebid.mobile.PrebidNativeAd
import org.prebid.mobile.PrebidNativeAdEventListener

/**
 * Loaded In-App native ads of one Flutter engine, keyed by the Dart ad id,
 * so a [NativeAdPlatformView] can render and register the ad for tracking.
 * One store per engine: every engine numbers its ads from the same start.
 */
class NativeAdStore {
    val ads = mutableMapOf<Long, PrebidNativeAd>()

    /**
     * The rendered, registered view of each ad. `registerView` creates new
     * impression trackers on every call, so an ad is registered once and its
     * view is moved into any platform view re-created for the same ad (e.g.
     * after scrolling out of a list and back).
     */
    val views = mutableMapOf<Long, View>()

    /** Held here: Prebid keeps only a WeakReference to the listener. */
    val listeners = mutableMapOf<Long, NativeAdEvents>()

    /** Image downloads of each ad's rendered view, cancelled with the ad. */
    val imageLoads = mutableMapOf<Long, MutableList<Future<*>>>()

    /** Platform views currently showing each ad id, newest last. */
    private val platformViews = mutableMapOf<Long, MutableList<NativeAdPlatformView>>()

    /**
     * Stores a newly loaded ad and shows it in the newest platform view
     * already on screen for its id (a reload keeps the same Dart widget).
     */
    fun put(adId: Long, ad: PrebidNativeAd) {
        ads[adId] = ad
        platformViews[adId]?.lastOrNull()?.show()
    }

    fun remove(adId: Long) {
        ads.remove(adId)
        listeners.remove(adId)?.stopWatching()
        imageLoads.remove(adId)?.forEach { it.cancel(true) }
        views.remove(adId)?.let { (it.parent as? ViewGroup)?.removeView(it) }
    }

    fun clear() {
        (ads.keys + views.keys + listeners.keys + imageLoads.keys).toSet().forEach(::remove)
        platformViews.clear()
    }

    fun attach(view: NativeAdPlatformView) {
        platformViews.getOrPut(view.adId) { mutableListOf() } += view
    }

    fun detach(view: NativeAdPlatformView) {
        platformViews[view.adId]?.let {
            it.remove(view)
            if (it.isEmpty()) platformViews.remove(view.adId)
        }
    }
}

/**
 * PlatformView factory for `PrebidNativeAdView`: renders a loaded
 * [PrebidNativeAd] natively and calls `registerView` so Prebid tracks
 * viewability-based impressions and clicks.
 */
class NativeAdViewFactory(
    private val messenger: BinaryMessenger,
    private val flutterApi: AdFlutterApi,
    private val store: NativeAdStore,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any>()
        return NativeAdPlatformView(context, viewId, messenger, flutterApi, store, params)
    }
}

class NativeAdPlatformView(
    private val context: Context,
    viewId: Int,
    messenger: BinaryMessenger,
    private val flutterApi: AdFlutterApi,
    private val store: NativeAdStore,
    params: Map<*, *>,
) : PlatformView {

    val adId = (params["adId"] as? Number)?.toLong() ?: 0L
    private val methodChannel =
        MethodChannel(messenger, "prebid_mobile_sdk/native_ad_$viewId")
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
            root.addView(existing, matchWidth())
            reportHeight(existing)
        } else if (ad != null) {
            render(ad)
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
        if (!registered) {
            // The bid expired before the ad was shown: Prebid won't track
            // it, and its expiry callback needs a registered view.
            store.ads.remove(adId)
            events.onAdExpired()
            return
        }
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

/**
 * `PrebidNativeAdEventListener` → Flutter, one per ad (it outlives platform
 * views).
 *
 * Prebid calls onAdImpression once per impression tracker request, from a
 * background thread, and not at all when the response has no impression
 * trackers. So the impression is reported from the IAB viewability rule
 * Prebid applies before firing its trackers (at least half the view on
 * screen for 1 s, checked every 0.25 s; same as iOS), with the listener as a
 * fallback, once per ad, on main.
 */
class NativeAdEvents(
    private val adId: Long,
    private val flutterApi: AdFlutterApi,
) : PrebidNativeAdEventListener {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val impressionReported = AtomicBoolean(false)
    private var watchedView: WeakReference<View>? = null
    private var viewableChecks = 0
    private var stopped = false

    /**
     * The fraction of the view Flutter paints on screen, reported by the
     * Dart widget; 1 until the first report.
     */
    var flutterVisibleFraction = 1.0

    /**
     * Polls only while the view is in a window: the store keeps it while
     * it's off screen (e.g. scrolled out of a list), where it can't be seen.
     */
    private val attachListener = object : View.OnAttachStateChangeListener {
        override fun onViewAttachedToWindow(v: View) {
            if (stopped || impressionReported.get()) return
            viewableChecks = 0
            mainHandler.removeCallbacks(check)
            mainHandler.postDelayed(check, CHECK_INTERVAL_MS)
        }

        override fun onViewDetachedFromWindow(v: View) {
            mainHandler.removeCallbacks(check)
            viewableChecks = 0
        }
    }

    private val check = object : Runnable {
        override fun run() {
            val view = watchedView?.get() ?: return
            viewableChecks = if (isAtLeastHalfViewable(view)) viewableChecks + 1 else 0
            if (viewableChecks >= REQUIRED_VIEWABLE_CHECKS) {
                reportImpression()
            } else {
                mainHandler.postDelayed(this, CHECK_INTERVAL_MS)
            }
        }
    }

    fun watchViewability(view: View) {
        if (stopped || impressionReported.get()) return
        watchedView?.get()?.removeOnAttachStateChangeListener(attachListener)
        watchedView = WeakReference(view)
        view.addOnAttachStateChangeListener(attachListener)
        viewableChecks = 0
        mainHandler.removeCallbacks(check)
        if (view.isAttachedToWindow) mainHandler.postDelayed(check, CHECK_INTERVAL_MS)
    }

    /** Stops for good (impression reported, ad expired or destroyed). */
    fun stopWatching() {
        stopped = true
        mainHandler.removeCallbacks(check)
        watchedView?.get()?.removeOnAttachStateChangeListener(attachListener)
        watchedView = null
    }

    private fun reportImpression() {
        stopWatching()
        if (impressionReported.compareAndSet(false, true)) send("onAdImpression")
    }

    private fun isAtLeastHalfViewable(view: View): Boolean {
        if (flutterVisibleFraction < 0.5) return false
        if (!view.isShown || view.windowToken == null) return false
        val area = view.width.toLong() * view.height
        if (area <= 0) return false
        val visible = Rect()
        if (!view.getGlobalVisibleRect(visible)) return false
        return visible.width().toLong() * visible.height() * 2 >= area
    }

    override fun onAdClicked() = send("onAdClicked")

    override fun onAdImpression() {
        mainHandler.post { reportImpression() }
    }

    override fun onAdExpired() {
        // Prebid stops tracking an expired ad; so does the watcher.
        mainHandler.post { stopWatching() }
        send("onAdExpired")
    }

    private fun send(name: String) {
        mainHandler.post {
            flutterApi.onAdEvent(AdEvent(adId = adId, eventName = name)) {}
        }
    }

    private companion object {
        const val CHECK_INTERVAL_MS = 250L
        const val REQUIRED_VIEWABLE_CHECKS = 5 // 1 s / 0.25 s + 1, as Prebid iOS
    }
}

/** Downloads native ad images off the main thread, on a small shared pool. */
internal object NativeImageLoader {
    val mainHandler = Handler(Looper.getMainLooper())

    val executor: ExecutorService = Executors.newFixedThreadPool(2) { task ->
        Thread(task, "PrebidNativeImage").apply { isDaemon = true }
    }

    private const val TIMEOUT_MS = 10_000
    private const val MAX_BYTES = 10 * 1024 * 1024

    /**
     * Downloads and decodes [url], downsampled to about [width] x [height]
     * pixels; null on any failure.
     */
    fun load(url: String, width: Int, height: Int): Bitmap? = try {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = TIMEOUT_MS
        connection.readTimeout = TIMEOUT_MS
        val bytes = try {
            connection.inputStream.use { input ->
                val out = ByteArrayOutputStream()
                val buffer = ByteArray(16 * 1024)
                while (true) {
                    if (Thread.currentThread().isInterrupted) return null
                    val n = input.read(buffer)
                    if (n < 0) break
                    out.write(buffer, 0, n)
                    if (out.size() > MAX_BYTES) return null
                }
                out.toByteArray()
            }
        } finally {
            connection.disconnect()
        }
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        val options = BitmapFactory.Options().apply {
            inSampleSize = calculateInSampleSize(bounds.outWidth, bounds.outHeight, width, height)
        }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
    } catch (e: Exception) {
        null
    }
}

/**
 * The largest power-of-two `inSampleSize` that keeps a [width] x [height]
 * image at least [reqWidth] x [reqHeight] (so it still fills a cropping
 * view); 1 when either size is unknown.
 */
internal fun calculateInSampleSize(width: Int, height: Int, reqWidth: Int, reqHeight: Int): Int {
    if (width <= 0 || height <= 0 || reqWidth <= 0 || reqHeight <= 0) return 1
    var sampleSize = 1
    while (width / (sampleSize * 2) >= reqWidth && height / (sampleSize * 2) >= reqHeight) {
        sampleSize *= 2
    }
    return sampleSize
}
