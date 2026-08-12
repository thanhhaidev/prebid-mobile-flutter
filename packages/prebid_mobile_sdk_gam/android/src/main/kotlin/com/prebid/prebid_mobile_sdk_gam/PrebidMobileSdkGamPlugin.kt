package com.prebid.prebid_mobile_sdk_gam

import android.app.Activity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/// Companion plugin that adds Google Ad Manager (GAM) rendering on top of the
/// core prebid_mobile_sdk plugin. Registers the GAM banner PlatformView factory
/// and the GAM interstitial method channel.
class PrebidMobileSdkGamPlugin : FlutterPlugin, ActivityAware {

    private var activity: Activity? = null
    private var interstitialManager: GamInterstitialManager? = null
    private var rewardedManager: GamRewardedManager? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        binding.platformViewRegistry.registerViewFactory(
            "prebid_mobile_sdk_gam/banner",
            GamBannerAdViewFactory(binding.binaryMessenger) { activity },
        )
        binding.platformViewRegistry.registerViewFactory(
            "prebid_mobile_sdk_gam/native",
            GamNativeAdViewFactory(binding.binaryMessenger),
        )
        interstitialManager = GamInterstitialManager(binding.binaryMessenger) { activity }
        rewardedManager = GamRewardedManager(binding.binaryMessenger) { activity }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
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
    }
}
