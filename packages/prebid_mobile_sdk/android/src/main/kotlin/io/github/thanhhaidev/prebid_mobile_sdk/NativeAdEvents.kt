package io.github.thanhhaidev.prebid_mobile_sdk

import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.view.View
import java.lang.ref.WeakReference
import java.util.concurrent.atomic.AtomicBoolean
import org.prebid.mobile.PrebidNativeAdEventListener

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
internal class NativeAdEvents(
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
