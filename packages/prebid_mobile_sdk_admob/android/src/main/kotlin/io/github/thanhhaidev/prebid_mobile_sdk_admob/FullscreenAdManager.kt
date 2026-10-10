package io.github.thanhhaidev.prebid_mobile_sdk_admob

import android.app.Activity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.prebid.mobile.PrebidMobile

/**
 * Base of the interstitial and rewarded managers: one method channel shared
 * by every ad of a kind, each ad keyed by the `adId` the Dart side allocates.
 * Answers `load` / `show` / `destroy` / `releaseAll` and pushes the ads'
 * events back over the same channel; a subclass builds, loads, shows and
 * frees its kind of ad ([A]).
 */
internal abstract class FullscreenAdManager<A : Any>(
    messenger: BinaryMessenger,
    channelName: String,
    private val activityProvider: () -> Activity?,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, channelName)
    private val ads = mutableMapOf<Long, A>()

    init {
        channel.setMethodCallHandler(this)
    }

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

    /** Frees [ad] and detaches its callbacks, so it reports nothing more. */
    protected abstract fun destroy(ad: A)

    /**
     * Whether [ad] is still the one registered for [adId]: false once it was
     * destroyed or replaced by a newer load, whose events it must not send.
     */
    protected fun isCurrent(adId: Long, ad: A): Boolean = ads[adId] === ad

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
        // Reloading an adId replaces (and frees) its previous ad.
        release(adId)
        // Prebid Android drops requests made before initialization without
        // calling back, so the load would hang and AdMob's waterfall never run.
        if (!PrebidMobile.isSdkInitialized()) {
            return send(adId, "onAdFailed", SDK_NOT_INITIALIZED)
        }
        // Reported through the listener, as iOS does, rather than as a
        // PlatformException from loadAd().
        val activity = activityProvider() ?: return send(adId, "onAdFailed", NO_ACTIVITY)
        val ad = create(adId, args, activity)
        ads[adId] = ad
        load(adId, ad, activity)
    }

    private fun show(adId: Long) {
        val ad = ads[adId]?.takeIf { isLoaded(it) } ?: return send(adId, "onAdFailed", NOT_LOADED)
        val activity = activityProvider() ?: return send(adId, "onAdFailed", NO_ACTIVITY)
        show(adId, ad, activity)
    }

    private fun release(adId: Long) {
        ads.remove(adId)?.let { destroy(it) }
    }

    private fun releaseAll() {
        val all = ads.values.toList()
        ads.clear()
        all.forEach { destroy(it) }
    }

    /**
     * Sends [event] for [adId], with [error] for `onAdFailed` (blank becomes
     * "Unknown error") and any [extra] payload keys.
     */
    protected fun send(
        adId: Long,
        event: String,
        error: String? = null,
        extra: Map<String, Any?> = emptyMap(),
    ) {
        val payload = mutableMapOf<String, Any?>("adId" to adId)
        if (event == "onAdFailed") payload["error"] = errorMessage(error)
        payload.putAll(extra)
        channel.invokeMethod(event, payload)
    }

    private companion object {
        const val NOT_LOADED = "The ad is not loaded"
        const val NO_ACTIVITY = "No Activity is attached to the Flutter engine"
    }
}
