package io.github.thanhhaidev.prebid_mobile_sdk

import android.app.Activity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/**
 * Entry point of the core plugin: registers the Pigeon host APIs and the
 * banner / native platform views, and ties fullscreen ads to the Activity.
 */
class PrebidMobileSdkPlugin : FlutterPlugin, ActivityAware {

    private var activity: Activity? = null
    private lateinit var flutterApi: AdFlutterApi
    private lateinit var prebidMobileApi: PrebidMobileHostApiImpl
    private lateinit var interstitialApi: InterstitialAdHostApiImpl
    private lateinit var rewardedApi: RewardedAdHostApiImpl
    private lateinit var nativeApi: NativeAdHostApiImpl
    private lateinit var multiformatApi: MultiformatAdHostApiImpl
    private lateinit var instreamApi: InstreamVideoAdHostApiImpl
    private val nativeAdStore = NativeAdStore()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val messenger = binding.binaryMessenger
        val context = binding.applicationContext
        flutterApi = AdFlutterApi(messenger)

        prebidMobileApi = PrebidMobileHostApiImpl(context, PrebidEventFlutterApi(messenger), ::releaseAds)
        interstitialApi = InterstitialAdHostApiImpl(flutterApi) { activity }
        rewardedApi = RewardedAdHostApiImpl(flutterApi) { activity }
        nativeApi = NativeAdHostApiImpl(flutterApi, nativeAdStore)
        multiformatApi = MultiformatAdHostApiImpl(MultiformatFlutterApi(messenger)) { activity }
        instreamApi = InstreamVideoAdHostApiImpl()

        PrebidMobileHostApi.setUp(messenger, prebidMobileApi)
        TargetingHostApi.setUp(messenger, TargetingHostApiImpl(context))
        InterstitialAdHostApi.setUp(messenger, interstitialApi)
        RewardedAdHostApi.setUp(messenger, rewardedApi)
        NativeAdHostApi.setUp(messenger, nativeApi)
        MultiformatAdHostApi.setUp(messenger, multiformatApi)
        InstreamVideoAdHostApi.setUp(messenger, instreamApi)

        binding.platformViewRegistry.registerViewFactory(
            BANNER_VIEW_TYPE,
            BannerAdViewFactory(messenger) { activity },
        )
        binding.platformViewRegistry.registerViewFactory(
            NATIVE_VIEW_TYPE,
            NativeAdViewFactory(messenger, flutterApi, nativeAdStore),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val messenger = binding.binaryMessenger
        PrebidMobileHostApi.setUp(messenger, null)
        TargetingHostApi.setUp(messenger, null)
        InterstitialAdHostApi.setUp(messenger, null)
        RewardedAdHostApi.setUp(messenger, null)
        NativeAdHostApi.setUp(messenger, null)
        MultiformatAdHostApi.setUp(messenger, null)
        InstreamVideoAdHostApi.setUp(messenger, null)
        prebidMobileApi.clearEventDelegate()
        // Stop auto-refresh timers and viewability polls, which would
        // otherwise keep running (and the engine's objects alive) for the
        // rest of the process.
        releaseAds()
    }

    private fun releaseAds() {
        destroyFullscreenAds(reason = null)
        nativeApi.destroyAll()
        multiformatApi.destroyAll()
        instreamApi.destroyAll()
        nativeAdStore.clear()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
        // The Activity is destroyed and re-created; units built with it
        // (Prebid shows them in a Dialog on that Activity) can't be shown on
        // the new one, so release them like onDetachedFromActivity.
        destroyFullscreenAds(reason = "The Activity was re-created for a configuration change")
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
        // Fullscreen ad units hold the Activity they were built with; release
        // them with it instead of leaking it until Dart calls destroy().
        destroyFullscreenAds(reason = "The Activity was destroyed")
    }

    private fun destroyFullscreenAds(reason: String?) {
        val ids = interstitialApi.destroyAll() + rewardedApi.destroyAll()
        if (reason != null) ids.forEach { flutterApi.sendAdFailed(it, reason) }
    }

    private companion object {
        const val BANNER_VIEW_TYPE = "prebid_mobile_sdk/banner_ad"
        const val NATIVE_VIEW_TYPE = "prebid_mobile_sdk/native_ad"
    }
}
