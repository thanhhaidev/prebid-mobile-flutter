package io.github.thanhhaidev.prebid_mobile_sdk_gam

import android.app.Activity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.prebid.mobile.PrebidMobile
import org.prebid.mobile.api.rendering.BaseInterstitialAdUnit

/**
 * The method channel of one fullscreen ad kind (e.g.
 * `prebid_mobile_sdk_gam/interstitial`): `load`, `show`, `destroy` and
 * `releaseAll` calls for ads keyed by the `adId` the Dart side allocates,
 * and their events sent back over the same channel. Subclasses only build
 * the ad unit and wire its listener to [send].
 */
internal abstract class FullscreenAdManager<T : BaseInterstitialAdUnit>(
    messenger: BinaryMessenger,
    channelName: String,
    private val activityProvider: () -> Activity?,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, channelName)
    private val ads = mutableMapOf<Long, T>()

    init {
        channel.setMethodCallHandler(this)
    }

    /**
     * Builds the ad unit for [adId] from the `load` [args], with its listener
     * reporting through [send]. Not loaded yet.
     */
    protected abstract fun create(activity: Activity, adId: Long, args: Map<*, *>): T

    /** Stops answering calls and destroys every ad (engine detached). */
    fun dispose() {
        channel.setMethodCallHandler(null)
        releaseAll()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        val adId = (args?.get("adId") as? Number)?.toLong()
        when (call.method) {
            "load" -> {
                if (adId == null) return result.error("no_ad_id", "Missing adId", null)
                load(adId, args)
            }
            "show" -> {
                if (adId == null) return result.error("no_ad_id", "Missing adId", null)
                show(adId)
            }
            "destroy" -> adId?.let { ads.remove(it)?.destroy() }
            "releaseAll" -> releaseAll()
            else -> return result.notImplemented()
        }
        result.success(null)
    }

    private fun load(adId: Long, args: Map<*, *>) {
        // Reloading an adId replaces (and frees) its previous ad unit, also
        // when the new load fails below.
        ads.remove(adId)?.destroy()
        // Failures are reported through the listener, as iOS does, rather
        // than as a PlatformException from loadAd().
        if (!PrebidMobile.isSdkInitialized()) {
            // Prebid Android drops a request made before initialization
            // without calling back, so the load would never finish.
            return send(adId, "onAdFailed", PluginErrors.NOT_INITIALIZED)
        }
        val activity = activityProvider() ?: return send(adId, "onAdFailed", PluginErrors.NO_ACTIVITY)
        val adUnit = create(activity, adId, args)
        ads[adId] = adUnit
        adUnit.loadAd()
    }

    private fun show(adId: Long) {
        val adUnit = ads[adId]
        when {
            adUnit == null || !adUnit.isLoaded -> send(adId, "onAdFailed", PluginErrors.NOT_LOADED)
            // Prebid shows from the Activity the ad unit was loaded with.
            activityProvider() == null -> send(adId, "onAdFailed", PluginErrors.NO_ACTIVITY)
            else -> adUnit.show()
        }
    }

    /**
     * Destroys every ad. Also called from Dart before its first call: after
     * a hot restart this manager still holds the previous isolate's ads.
     */
    private fun releaseAll() {
        ads.values.forEach { it.destroy() }
        ads.clear()
    }

    /** Sends [event] for [adId], with an `error` and any [extras]. */
    protected fun send(
        adId: Long,
        event: String,
        error: String? = null,
        extras: Map<String, Any?> = emptyMap(),
    ) {
        val payload = mutableMapOf<String, Any?>("adId" to adId)
        if (error != null) payload["error"] = error
        payload.putAll(extras)
        channel.invokeMethod(event, payload)
    }
}
