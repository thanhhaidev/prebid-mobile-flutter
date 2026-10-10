package io.github.thanhhaidev.prebid_mobile_sdk_max

import android.app.Activity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/**
 * Companion plugin that adds AppLovin MAX mediation on top of the core
 * prebid_mobile_sdk plugin. Registers the MAX banner and native platform views
 * (`prebid_mobile_sdk_max/banner`, `prebid_mobile_sdk_max/native`) and the
 * interstitial and rewarded method channels (`prebid_mobile_sdk_max/interstitial`,
 * `prebid_mobile_sdk_max/rewarded`).
 */
class PrebidMobileSdkMaxPlugin : FlutterPlugin, ActivityAware {

    private var activity: Activity? = null
    private var interstitialManager: MaxInterstitialManager? = null
    private var rewardedManager: MaxRewardedManager? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        binding.platformViewRegistry.registerViewFactory(
            "prebid_mobile_sdk_max/banner",
            MaxBannerAdViewFactory(binding.binaryMessenger) { activity },
        )
        binding.platformViewRegistry.registerViewFactory(
            "prebid_mobile_sdk_max/native",
            MaxNativeAdViewFactory(binding.binaryMessenger) { activity },
        )
        interstitialManager = MaxInterstitialManager(binding.binaryMessenger) { activity }
        rewardedManager = MaxRewardedManager(binding.binaryMessenger) { activity }
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
