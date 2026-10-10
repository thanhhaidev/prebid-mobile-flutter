package io.github.thanhhaidev.prebid_mobile_sdk

import android.view.View
import android.view.ViewGroup
import java.util.concurrent.Future
import org.prebid.mobile.PrebidNativeAd

/**
 * Loaded In-App native ads of one Flutter engine, keyed by the Dart ad id,
 * so a [NativeAdPlatformView] can render and register the ad for tracking.
 * One store per engine: every engine numbers its ads from the same start.
 */
internal class NativeAdStore {
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

    /**
     * Clicks the ad's registered view (the custom-layout tracking view), as
     * a tap there would; false when the view isn't on screen.
     */
    fun performClick(adId: Long): Boolean {
        val view = views[adId]?.takeIf { it.isAttachedToWindow } ?: return false
        return view.performClick()
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
