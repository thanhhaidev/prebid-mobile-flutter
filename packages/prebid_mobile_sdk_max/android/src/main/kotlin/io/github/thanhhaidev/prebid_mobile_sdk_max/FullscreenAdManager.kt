package io.github.thanhhaidev.prebid_mobile_sdk_max

import android.app.Activity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.prebid.mobile.PrebidMobile

/**
 * The method channel of one fullscreen ad kind (`prebid_mobile_sdk_max/interstitial`,
 * `prebid_mobile_sdk_max/rewarded`): `load`, `show`, `destroy` and `releaseAll`
 * calls keyed by the `adId` the Dart side allocates, with events sent back over
 * the same channel. A subclass builds, starts, shows and destroys its ads of
 * type [T].
 */
internal abstract class FullscreenAdManager<T : Any>(
    messenger: BinaryMessenger,
    channelName: String,
    private val activityProvider: () -> Activity?,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, channelName)

    /** The live ads by `adId`. */
    protected val ads = mutableMapOf<Long, T>()

    init {
        channel.setMethodCallHandler(this)
    }

    /**
     * Why a load must be refused before the previous ad of its `adId` is
     * freed, or null to go ahead.
     */
    protected open fun refuseLoad(adId: Long, args: Map<*, *>): String? = null

    /** Builds the ad for [adId]; it is stored before [start] runs. */
    protected abstract fun create(adId: Long, args: Map<*, *>, activity: Activity): T

    /** Starts loading [ad] (the Prebid auction, then the MAX load). */
    protected abstract fun start(adId: Long, ad: T)

    /** Whether [ad] has loaded and can be shown. */
    protected abstract fun isReady(ad: T): Boolean

    /** Shows [ad] from [activity]. */
    protected abstract fun show(ad: T, activity: Activity)

    /** Frees [ad], already removed from [ads]. */
    protected abstract fun destroy(adId: Long, ad: T)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
        val adId = (args["adId"] as? Number)?.toLong()
        when (call.method) {
            "load" -> {
                if (adId == null) return result.error("no_ad_id", "Missing adId", null)
                load(adId, args)
                result.success(null)
            }
            "show" -> {
                if (adId == null) return result.error("no_ad_id", "Missing adId", null)
                show(adId)
                result.success(null)
            }
            "destroy" -> {
                adId?.let { release(it) }
                result.success(null)
            }
            "releaseAll" -> {
                releaseAll()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun load(adId: Long, args: Map<*, *>) {
        refuseLoad(adId, args)?.let { return send(adId, "onAdFailed", it) }
        // Reloading an adId replaces (and frees) its previous ad.
        release(adId)
        // Prebid Android drops requests made before init without calling back,
        // so the load would hang and the MAX waterfall would never run.
        if (!PrebidMobile.isSdkInitialized()) return send(adId, "onAdFailed", NOT_INITIALIZED)
        // Reported through the listener, as iOS does and as `show` does,
        // rather than as a PlatformException from loadAd().
        val activity = activityProvider() ?: return send(adId, "onAdFailed", NO_ACTIVITY)
        val ad = create(adId, args, activity)
        ads[adId] = ad
        start(adId, ad)
    }

    private fun show(adId: Long) {
        val ad = ads[adId]
        val activity = activityProvider()
        when {
            ad == null || !isReady(ad) -> send(adId, "onAdFailed", NOT_LOADED)
            activity == null -> send(adId, "onAdFailed", NO_ACTIVITY)
            // Show from the current Activity, not the one used to load.
            else -> show(ad, activity)
        }
    }

    /** Frees the ad of [adId], if any. */
    protected fun release(adId: Long) {
        ads.remove(adId)?.let { destroy(adId, it) }
    }

    /** Frees every ad: the Dart side restarted (hot restart) and owns none. */
    private fun releaseAll() {
        ads.keys.toList().forEach { release(it) }
    }

    /** Stops answering calls and frees every ad (engine detached). */
    fun dispose() {
        channel.setMethodCallHandler(null)
        releaseAll()
    }

    /** Sends [event] for [adId], with [error] as the payload's `error`. */
    protected fun send(adId: Long, event: String, error: String? = null) {
        send(adId, event, if (error != null) mapOf("error" to error) else emptyMap())
    }

    /** Sends [event] for [adId] with [payload]. */
    protected fun send(adId: Long, event: String, payload: Map<String, Any?>) {
        channel.invokeMethod(event, payload + ("adId" to adId))
    }

    companion object {
        const val NOT_INITIALIZED = "The Prebid SDK is not initialized"
        const val NO_ACTIVITY = "No Activity is attached to the Flutter engine"
        const val NOT_LOADED = "The ad is not loaded"
    }
}
