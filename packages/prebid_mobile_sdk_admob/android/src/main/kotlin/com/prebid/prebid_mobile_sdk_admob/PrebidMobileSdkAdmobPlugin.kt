package com.prebid.prebid_mobile_sdk_admob

import android.app.Activity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/// Companion plugin that adds Google AdMob mediation on top of the core
/// prebid_mobile_sdk plugin. Registers the AdMob banner PlatformView factory and
/// the AdMob interstitial method channel.
class PrebidMobileSdkAdmobPlugin : FlutterPlugin, ActivityAware {

    private var activity: Activity? = null
    private var interstitialManager: AdMobInterstitialManager? = null
    private var rewardedManager: AdMobRewardedManager? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        binding.platformViewRegistry.registerViewFactory(
            "prebid_mobile_sdk_admob/banner",
            AdMobBannerAdViewFactory(binding.binaryMessenger) { activity },
        )
        binding.platformViewRegistry.registerViewFactory(
            "prebid_mobile_sdk_admob/native",
            AdMobNativeAdViewFactory(binding.binaryMessenger),
        )
        interstitialManager = AdMobInterstitialManager(binding.binaryMessenger) { activity }
        rewardedManager = AdMobRewardedManager(binding.binaryMessenger) { activity }
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
