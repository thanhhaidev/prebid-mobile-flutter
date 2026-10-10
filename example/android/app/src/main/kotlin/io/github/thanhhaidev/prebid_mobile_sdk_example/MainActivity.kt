package io.github.thanhhaidev.prebid_mobile_sdk_example

import android.content.SharedPreferences
import android.os.Bundle
import android.webkit.WebView
import androidx.preference.PreferenceManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.prebid.mobile.PrebidMobile

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // As the original PrebidInternalTestApp: debuggable WebViews (creatives).
        WebView.setWebContentsDebuggingEnabled(true)
        super.onCreate(savedInstanceState)
    }

    /**
     * The original's plugin renderer, registered while a "[Custom Renderer]"
     * screen is open (lib/services/custom_renderer.dart).
     */
    private val customRenderer = SampleCustomRenderer()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "prebid_example/custom_renderer",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "register" -> {
                    PrebidMobile.registerPluginRenderer(customRenderer)
                    result.success(null)
                }
                "unregister" -> {
                    PrebidMobile.unregisterPluginRenderer(customRenderer)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "prebid_example/iab_consent_store",
        ).setMethodCallHandler { call, result ->
            // The default SharedPreferences (<applicationId>_preferences) — where
            // the Prebid SDK reads the IAB consent keys from.
            val prefs: SharedPreferences = PreferenceManager.getDefaultSharedPreferences(this)
            val key = call.argument<String>("key")
            if (key == null) {
                result.error("bad_args", "missing key", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "get" -> result.success(prefs.all[key])
                "setInt" -> {
                    val value = call.argument<Number>("value")?.toInt()
                    prefs.edit().apply {
                        if (value == null) remove(key) else putInt(key, value)
                    }.apply()
                    result.success(null)
                }
                "setString" -> {
                    val value = call.argument<String>("value")
                    prefs.edit().apply {
                        if (value == null) remove(key) else putString(key, value)
                    }.apply()
                    result.success(null)
                }
                "setBool" -> {
                    val value = call.argument<Boolean>("value")
                    prefs.edit().apply {
                        if (value == null) remove(key) else putBoolean(key, value)
                    }.apply()
                    result.success(null)
                }
                "remove" -> {
                    prefs.edit().remove(key).apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
