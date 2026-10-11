package io.github.thanhhaidev.prebid_mobile_sdk_gam

import android.app.Activity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/**
 * Companion plugin that adds Google Ad Manager (GAM) rendering on top of the
 * core prebid_mobile_sdk plugin. Registers the GAM banner and native platform
 * view factories and the GAM interstitial and rewarded method channels.
 */
class PrebidMobileSdkGamPlugin :
    FlutterPlugin,
    ActivityAware {

    private var activity: Activity? = null
    private var interstitialManager: GamInterstitialManager? = null
    private var rewardedManager: GamRewardedManager? = null
    private var preloadedBanners: PreloadedBanners? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val preloaded =
            PreloadedBanners(binding.binaryMessenger, "prebid_mobile_sdk_gam/preloaded_banner") { channelId, params ->
                GamBannerPlatformView(
                    activity ?: binding.applicationContext,
                    channelId.toInt(),
                    binding.binaryMessenger,
                    params,
                )
            }
        preloadedBanners = preloaded
        binding.platformViewRegistry.registerViewFactory(
            "prebid_mobile_sdk_gam/banner",
            GamBannerAdViewFactory(binding.binaryMessenger, preloaded) { activity },
        )
        binding.platformViewRegistry.registerViewFactory(
            "prebid_mobile_sdk_gam/native",
            GamNativeAdViewFactory(binding.binaryMessenger),
        )
        interstitialManager = GamInterstitialManager(binding.binaryMessenger) { activity }
        rewardedManager = GamRewardedManager(binding.binaryMessenger) { activity }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        preloadedBanners?.dispose()
        preloadedBanners = null
        // The engine disposes the platform views; the managers own their ads.
        interstitialManager?.dispose()
        interstitialManager = null
        rewardedManager?.dispose()
        rewardedManager = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onDetachedFromActivity() {
        activity = null
        // Fullscreen ads hold the Activity they were built with; release them
        // with it, as the core plugin does.
        interstitialManager?.releaseAll(PluginErrors.ACTIVITY_DESTROYED)
        rewardedManager?.releaseAll(PluginErrors.ACTIVITY_DESTROYED)
    }
}
