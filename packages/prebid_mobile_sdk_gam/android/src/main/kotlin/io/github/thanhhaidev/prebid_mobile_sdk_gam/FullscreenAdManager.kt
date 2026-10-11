package io.github.thanhhaidev.prebid_mobile_sdk_gam

import android.app.Activity
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.prebid.mobile.PrebidMobile

// Shared by the companion packages; tool/check_copies.sh keeps the copies
// identical.

/**
 * The method channel of one fullscreen ad kind (e.g.
 * `prebid_mobile_sdk_gam/interstitial`): `load`, `show`, `destroy` and
 * `releaseAll` calls for ads keyed by the `adId` the Dart side allocates,
 * and their events sent back over the same channel. A subclass builds,
 * loads, shows and frees its kind of ad ([A]) and reports through [send].
 */
internal abstract class FullscreenAdManager<A : Any>(
    messenger: BinaryMessenger,
    channelName: String,
    private val activityProvider: () -> Activity?,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, channelName)
    private val ads = mutableMapOf<Long, A>()

    /** Ads already shown: an ad shows once, whatever the SDK's own loaded
     * state says (an AdMob ad stays set after it is shown). */
    private val shown = mutableSetOf<Long>()

    /**
     * How long a loaded ad stays valid when its SDK lets it expire without
     * telling (AdMob: an hour), or null when the SDK reports it itself.
     * Past it, an ad not shown yet is freed and reports `onAdExpired`.
     */
    protected open val adLifetimeMs: Long? = null
    private val expiries = mutableMapOf<Long, Runnable>()
    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler(this)
    }

    /**
     * Why a load must be refused before the previous ad of its `adId` is
     * freed, or null to go ahead.
     */
    protected open fun refuseLoad(adId: Long, args: Map<*, *>): String? = null

    /** Builds the ad for [adId] from the `load` arguments, without loading it. */
    protected abstract fun create(adId: Long, args: Map<*, *>, activity: Activity): A

    /**
     * Starts loading [ad], already registered for [adId], and reports
     * `onAdLoaded` / `onAdFailed` when done (check [isCurrent] first).
     */
    protected abstract fun load(adId: Long, ad: A, activity: Activity)

    /** Whether [ad] has loaded and can be shown. */
    protected abstract fun isLoaded(ad: A): Boolean

    /** Shows the loaded [ad] from [activity]. */
    protected abstract fun show(adId: Long, ad: A, activity: Activity)

    /** Frees [ad], no longer registered for [adId], so it reports nothing more. */
    protected abstract fun destroy(adId: Long, ad: A)

    /**
     * Whether [ad] is still the one registered for [adId]: false once it was
     * destroyed or replaced by a newer load, whose events it must not send.
     */
    protected fun isCurrent(adId: Long, ad: A): Boolean = ads[adId] === ad

    /** Unregisters the ad of [adId] without freeing it, and returns it. */
    protected fun forget(adId: Long): A? = ads.remove(adId)

    /**
     * Frees every ad, reporting [reason] as `onAdFailed` for those not shown
     * yet: the Activity they were built with is gone for good, and holding
     * them would leak it until Dart calls destroy().
     */
    fun releaseAll(reason: String) {
        ads.keys.toList().forEach { adId ->
            val pending = adId !in shown
            release(adId)
            if (pending) send(adId, "onAdFailed", reason)
        }
    }

    /** Stops answering calls and frees every ad (engine detached). */
    fun dispose() {
        channel.setMethodCallHandler(null)
        releaseAll()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
        val adId = (args["adId"] as? Number)?.toLong()
        when (call.method) {
            "load" -> {
                if (adId == null) return result.error("no_ad_id", "Missing adId", null)
                load(adId, args)
            }

            "show" -> {
                if (adId == null) return result.error("no_ad_id", "Missing adId", null)
                show(adId)
            }

            "destroy" -> adId?.let { release(it) }

            "releaseAll" -> releaseAll()

            else -> return result.notImplemented()
        }
        result.success(null)
    }

    private fun load(adId: Long, args: Map<*, *>) {
        refuseLoad(adId, args)?.let { return send(adId, "onAdFailed", it) }
        // Reloading an adId replaces (and frees) its previous ad, also when
        // the new load fails below.
        release(adId)
        // Failures are reported through the listener, as iOS does, rather
        // than as a PlatformException from loadAd(). Prebid Android drops a
        // request made before initialization without calling back, so the
        // load would never finish.
        if (!PrebidMobile.isSdkInitialized()) {
            return send(adId, "onAdFailed", PluginErrors.NOT_INITIALIZED)
        }
        val activity = activityProvider() ?: return send(adId, "onAdFailed", PluginErrors.NO_ACTIVITY)
        val ad = create(adId, args, activity)
        ads[adId] = ad
        load(adId, ad, activity)
    }

    private fun show(adId: Long) {
        val ad = ads[adId]?.takeIf { adId !in shown && isLoaded(it) }
            ?: return send(adId, "onAdFailed", PluginErrors.NOT_LOADED)
        val activity = activityProvider() ?: return send(adId, "onAdFailed", PluginErrors.NO_ACTIVITY)
        shown += adId
        cancelExpiry(adId)
        show(adId, ad, activity)
    }

    private fun release(adId: Long) {
        cancelExpiry(adId)
        shown -= adId
        ads.remove(adId)?.let { destroy(adId, it) }
    }

    /**
     * Frees every ad. Also called from Dart before its first call: after a
     * hot restart this manager still holds the previous isolate's ads.
     */
    private fun releaseAll() {
        ads.keys.toList().forEach { release(it) }
    }

    /**
     * Sends [event] for [adId] with any [extras]; `onAdFailed` carries
     * [error] as its `error` (blank becomes "Unknown error").
     */
    private fun scheduleExpiry(adId: Long) {
        val lifetime = adLifetimeMs ?: return
        val ad = ads[adId] ?: return
        cancelExpiry(adId)
        val expiry = Runnable {
            expiries.remove(adId)
            if (ads[adId] !== ad || adId in shown) return@Runnable
            release(adId)
            send(adId, "onAdExpired")
        }
        expiries[adId] = expiry
        mainHandler.postDelayed(expiry, lifetime)
    }

    private fun cancelExpiry(adId: Long) {
        expiries.remove(adId)?.let(mainHandler::removeCallbacks)
    }

    protected fun send(adId: Long, event: String, error: String? = null, extras: Map<String, Any?> = emptyMap()) {
        if (event == "onAdLoaded") scheduleExpiry(adId)
        val payload = mutableMapOf<String, Any?>("adId" to adId)
        if (event == "onAdFailed" || error != null) payload["error"] = errorMessage(error)
        payload.putAll(extras)
        channel.invokeMethod(event, payload)
    }
}
