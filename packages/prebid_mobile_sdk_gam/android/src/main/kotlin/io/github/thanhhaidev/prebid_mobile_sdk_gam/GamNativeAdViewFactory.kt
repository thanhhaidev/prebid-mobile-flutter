package io.github.thanhhaidev.prebid_mobile_sdk_gam

import android.content.Context
import android.graphics.Color
import android.graphics.Rect
import android.graphics.Typeface
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.gms.ads.AdListener
import com.google.android.gms.ads.AdLoader
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.admanager.AdManagerAdRequest
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import com.google.android.gms.ads.nativead.NativeCustomFormatAd
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.util.concurrent.Future
import java.util.concurrent.atomic.AtomicBoolean
import org.prebid.mobile.NativeAdUnit
import org.prebid.mobile.NativeDataAsset
import org.prebid.mobile.NativeImageAsset
import org.prebid.mobile.NativeTitleAsset
import org.prebid.mobile.PrebidMobile
import org.prebid.mobile.PrebidNativeAd
import org.prebid.mobile.PrebidNativeAdEventListener
import org.prebid.mobile.PrebidNativeAdListener
import org.prebid.mobile.ResultCode
import org.prebid.mobile.addendum.AdViewUtils

/**
 * PlatformView factory for GAM Original-API native ads (custom-template +
 * unified). Prebid runs the auction, GAM resolves the line item, and
 * [AdViewUtils.findNative] extracts the Prebid winning bid for app-side
 * rendering — matching Prebid's reference GAM native integration.
 */
internal class GamNativeAdViewFactory(private val messenger: BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any>()
        return GamNativePlatformView(context, messenger, params, viewId)
    }
}

/**
 * One GAM native ad view. It starts the auction as soon as it is created;
 * its events go over `prebid_mobile_sdk_gam/native_<channelId>`, which the
 * Dart widget listens to before creating the view.
 */
internal class GamNativePlatformView(
    private val context: Context,
    messenger: BinaryMessenger,
    params: Map<*, *>,
    viewId: Int,
) : PlatformView {

    private val configId = params["configId"] as? String ?: ""
    private val gamAdUnitId = params["gamAdUnitId"] as? String ?: ""
    private val customFormatId = params["customFormatId"] as? String ?: ""
    private val customAssets = nativeAssetsFrom(params["assets"])
    private val nativeContext = NativeContext.from(params)
    private val customTrackers = nativeTrackersFrom(params["eventTrackers"])
    private val customTargeting = gamCustomTargeting(params["customTargeting"])
    private val gpid = params["gpid"] as? String
    private val pbAdSlot = params["pbAdSlot"] as? String
    private val impOrtbConfig = params["impOrtbConfig"] as? String
    private val globalOrtbConfig = params["globalOrtbConfig"] as? String
    private val requestOptions = NativeRequestOptions(params)

    private val methodChannel =
        MethodChannel(messenger, viewChannelName("prebid_mobile_sdk_gam/native", params, viewId))
    private val root = FrameLayout(context)
    private val mainHandler = Handler(Looper.getMainLooper())

    private var adUnit: NativeAdUnit? = null
    private var unifiedNativeAd: NativeAd? = null
    private var customFormatAd: NativeCustomFormatAd? = null

    /**
     * Keep-alive reference to the rendered Prebid ad: its impression tracking
     * and [nativeEventListener] (which it holds) must live as long as this
     * view, not only as long as the views it set click listeners on.
     */
    private var prebidNativeAd: PrebidNativeAd? = null

    /** Image downloads of the rendered ad, cancelled on [dispose]. */
    private val imageLoads = mutableListOf<Future<*>>()

    // Set once Flutter disposes the view: async SDK callbacks that land later
    // must not load, render or report anything.
    @Volatile
    private var disposed = false

    /** The pending viewability check of a custom-format ad's impression. */
    private var impressionCheck: Runnable? = null

    /**
     * The fraction of the view Flutter paints on screen, from the Dart
     * widget (Flutter's clips reach a platform view as a mask the native
     * check can't read); 1 until the first report.
     */
    private var flutterVisibleFraction = 1.0

    // Prebid calls onAdImpression once per impression tracker URL; report one.
    private val prebidImpressionReported = AtomicBoolean(false)

    private val nativeEventListener = object : PrebidNativeAdEventListener {
        override fun onAdClicked() {
            send("onAdClicked")
        }

        override fun onAdImpression() {
            if (prebidImpressionReported.compareAndSet(false, true)) send("onAdImpression")
        }

        override fun onAdExpired() {
            send("onAdExpired")
        }
    }

    init {
        methodChannel.setMethodCallHandler { call, result ->
            if (call.method == "setVisibleFraction") {
                flutterVisibleFraction = (call.arguments as? Number)?.toDouble() ?: 1.0
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
        // Prebid adds its hb_* keys to this request after the app's, so they
        // win on conflict.
        val adRequest = AdManagerAdRequest.Builder().apply {
            customTargeting?.forEach { (k, v) -> addCustomTargeting(k, v) }
        }.build()

        val nativeAdUnit = NativeAdUnit(configId)
        nativeContext.applyTo(nativeAdUnit)
        addNativeAssets(nativeAdUnit)
        gpid?.let { nativeAdUnit.setGpid(it) }
        pbAdSlot?.let { nativeAdUnit.setPbAdSlot(it) }
        impOrtbConfig?.let { nativeAdUnit.setImpOrtbConfig(it) }
        globalOrtbConfig?.let { nativeAdUnit.setGlobalOrtbConfig(it) }
        requestOptions.applyTo(nativeAdUnit)
        adUnit = nativeAdUnit

        val loader = buildAdLoader()
        if (!PrebidMobile.isSdkInitialized()) {
            // Prebid Android drops a fetch made before initialization without
            // calling back, which would also hold back the GAM request.
            send("fetchDemandFailed", PluginErrors.NOT_INITIALIZED_CODE)
            loader.loadAd(adRequest)
        } else {
            nativeAdUnit.fetchDemand(adRequest) { resultCode: ResultCode ->
                if (disposed) return@fetchDemand
                // Prebid Android reports SUCCESS even when no bid won (iOS
                // reports no-bids); without hb_* keys on the request there is
                // no Prebid demand, so report it as no-bids on both platforms.
                val hasBid = adRequest.customTargeting.keySet().any { it.startsWith("hb_") }
                when {
                    resultCode != ResultCode.SUCCESS -> send("fetchDemandFailed", resultCode.toDartCode())
                    hasBid -> send("fetchDemandSuccess")
                    else -> send("fetchDemandFailed", "prebidDemandNoBids")
                }
                loader.loadAd(adRequest)
            }
        }
    }

    private fun buildAdLoader(): AdLoader {
        val builder = AdLoader.Builder(context, gamAdUnitId)
            .forNativeAd { ad: NativeAd ->
                if (disposed) {
                    ad.destroy()
                    return@forNativeAd
                }
                send("unifiedAdLoaded")
                unifiedNativeAd = ad
                // Unified native ads are GAM's own demand (no Prebid creative to
                // extract), so the primary ad server wins directly.
                send("primaryAdWinUnified")
                renderUnified(ad)
            }

        // Custom-format (native template) ads carry Prebid demand. Only register
        // the handler when a template id is provided (unified-only cases omit it).
        if (customFormatId.isNotEmpty()) {
            builder.forCustomFormatAd(
                customFormatId,
                { customAd: NativeCustomFormatAd ->
                    if (disposed) {
                        customAd.destroy()
                        return@forCustomFormatAd
                    }
                    customFormatAd?.destroy()
                    customFormatAd = customAd
                    send("customAdLoaded")
                    AdViewUtils.findNative(
                        customAd,
                        object : PrebidNativeAdListener {
                            override fun onPrebidNativeLoaded(ad: PrebidNativeAd) {
                                if (disposed) return
                                send("nativeAdLoaded")
                                renderPrebidNative(ad)
                            }

                            override fun onPrebidNativeNotFound() {
                                if (disposed) return
                                send("primaryAdWinCustom")
                                renderCustomTemplate(customAd)
                            }

                            override fun onPrebidNativeNotValid() {
                                if (disposed) return
                                send("primaryAdWinCustom")
                                renderCustomTemplate(customAd)
                            }
                        },
                    )
                },
                { _: NativeCustomFormatAd, _: String -> },
            )
        }

        return builder
            .withAdListener(object : AdListener() {
                override fun onAdFailedToLoad(error: LoadAdError) {
                    send("primaryAdFailed", failure(error.message))
                }

                override fun onAdImpression() {
                    send("onAdImpression")
                }

                override fun onAdClicked() {
                    send("onAdClicked")
                }
            })
            .build()
    }

    private fun addNativeAssets(adUnit: NativeAdUnit) {
        if (customAssets != null) {
            customAssets.forEach { adUnit.addAsset(it) }
            (customTrackers ?: defaultNativeTrackers()).forEach { adUnit.addEventTracker(it) }
            return
        }
        val title = NativeTitleAsset()
        title.setLength(90)
        title.isRequired = true
        adUnit.addAsset(title)

        val icon = NativeImageAsset(20, 20, 20, 20)
        icon.imageType = NativeImageAsset.IMAGE_TYPE.ICON
        icon.isRequired = true
        adUnit.addAsset(icon)

        val image = NativeImageAsset(200, 200, 200, 200)
        image.imageType = NativeImageAsset.IMAGE_TYPE.MAIN
        image.isRequired = true
        adUnit.addAsset(image)

        val sponsored = NativeDataAsset()
        sponsored.len = 90
        sponsored.dataType = NativeDataAsset.DATA_TYPE.SPONSORED
        sponsored.isRequired = true
        adUnit.addAsset(sponsored)

        val body = NativeDataAsset()
        body.isRequired = true
        body.dataType = NativeDataAsset.DATA_TYPE.DESC
        adUnit.addAsset(body)

        val cta = NativeDataAsset()
        cta.isRequired = true
        cta.dataType = NativeDataAsset.DATA_TYPE.CTATEXT
        adUnit.addAsset(cta)

        (customTrackers ?: defaultNativeTrackers()).forEach { adUnit.addEventTracker(it) }
    }

    /**
     * Renders the Prebid winning native creative and registers the view so
     * Prebid tracks impressions/clicks.
     */
    private fun renderPrebidNative(ad: PrebidNativeAd) {
        prebidNativeAd = ad

        val iconView = ImageView(context)
        val imageView = ImageView(context)
        val titleView = TextView(context)
        val sponsoredView = TextView(context)
        val bodyView = TextView(context)
        val ctaView = Button(context)

        titleView.text = ad.title
        titleView.textSize = 15f
        titleView.setTypeface(Typeface.DEFAULT, Typeface.BOLD)
        sponsoredView.text = ad.sponsoredBy
        sponsoredView.textSize = 11f
        sponsoredView.setTextColor(Color.GRAY)
        bodyView.text = ad.description
        bodyView.textSize = 13f
        bodyView.setTextColor(Color.DKGRAY)
        ctaView.text = ad.callToAction
        ctaView.isAllCaps = false
        iconView.scaleType = ImageView.ScaleType.CENTER_CROP
        imageView.scaleType = ImageView.ScaleType.CENTER_CROP
        imageView.layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            context.dp(180),
        )
        downloadImage(ad.iconUrl, iconView, context.dp(40), context.dp(40))
        downloadImage(ad.imageUrl, imageView, context.resources.displayMetrics.widthPixels, context.dp(180))

        val header = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(
                iconView,
                LinearLayout.LayoutParams(context.dp(40), context.dp(40)).apply { rightMargin = context.dp(8) },
            )
            addView(
                LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    addView(sponsoredView)
                    addView(titleView)
                },
                LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f),
            )
        }

        val container = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(context.dp(12), context.dp(12), context.dp(12), context.dp(12))
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
            addView(imageView)
            addView(header)
            addView(bodyView)
            addView(ctaView)
        }

        setContent(container)
        val registered = ad.registerView(
            container,
            listOf(iconView, titleView, imageView, bodyView, ctaView),
            nativeEventListener,
        )
        // Prebid refuses an expired ad (the bid outlived `bid.exp` while GAM
        // loaded); nothing would be tracked, so report the expiry.
        if (!registered) send("onAdExpired")
    }

    /** Renders a GAM unified native ad (no Prebid creative present). */
    private fun renderUnified(ad: NativeAd) {
        val nativeAdView = NativeAdView(context)
        val iconView = ImageView(context)
        val mediaView = MediaView(context)
        val headlineView = TextView(context)
        val bodyView = TextView(context)
        val ctaView = Button(context)

        headlineView.text = ad.headline
        headlineView.textSize = 15f
        headlineView.setTypeface(Typeface.DEFAULT, Typeface.BOLD)
        bodyView.text = ad.body
        bodyView.textSize = 13f
        bodyView.setTextColor(Color.DKGRAY)
        ctaView.text = ad.callToAction
        ctaView.isAllCaps = false
        ctaView.isClickable = false
        ad.icon?.drawable?.let { iconView.setImageDrawable(it) }
        mediaView.layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            context.dp(180),
        )
        ad.mediaContent?.let { mediaView.mediaContent = it }

        val header = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(
                iconView,
                LinearLayout.LayoutParams(context.dp(40), context.dp(40)).apply { rightMargin = context.dp(8) },
            )
            addView(headlineView)
        }

        val content = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(context.dp(12), context.dp(12), context.dp(12), context.dp(12))
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
            addView(mediaView)
            addView(header)
            addView(bodyView)
            addView(ctaView)
        }

        nativeAdView.addView(content)
        nativeAdView.iconView = iconView
        nativeAdView.mediaView = mediaView
        nativeAdView.headlineView = headlineView
        nativeAdView.bodyView = bodyView
        nativeAdView.callToActionView = ctaView
        nativeAdView.setNativeAd(ad)

        setContent(nativeAdView)
    }

    /**
     * Minimal fallback rendering for a GAM custom-format ad that carries no
     * Prebid creative. GAM leaves its impression to the app: it is recorded
     * once half the ad has been on screen for a second, as Prebid's own.
     */
    private fun renderCustomTemplate(ad: NativeCustomFormatAd) {
        val label = TextView(context).apply {
            text = ad.getText("title") ?: "Ad"
            textSize = 15f
            setPadding(context.dp(12), context.dp(12), context.dp(12), context.dp(12))
        }
        setContent(label)
        recordImpressionWhenViewable(ad)
    }

    private fun recordImpressionWhenViewable(ad: NativeCustomFormatAd) {
        var viewableChecks = 0
        val check = object : Runnable {
            override fun run() {
                if (disposed || impressionCheck !== this) return
                viewableChecks = if (isAtLeastHalfOnScreen(root)) viewableChecks + 1 else 0
                if (viewableChecks >= REQUIRED_VIEWABLE_CHECKS) {
                    impressionCheck = null
                    ad.recordImpression()
                } else {
                    mainHandler.postDelayed(this, CHECK_INTERVAL_MS)
                }
            }
        }
        impressionCheck = check
        mainHandler.postDelayed(check, CHECK_INTERVAL_MS)
    }

    private fun isAtLeastHalfOnScreen(view: View): Boolean {
        if (flutterVisibleFraction < 0.5) return false
        if (!view.isShown || view.windowToken == null) return false
        val area = view.width.toLong() * view.height
        if (area <= 0) return false
        val visible = Rect()
        if (!view.getGlobalVisibleRect(visible)) return false
        return visible.width().toLong() * visible.height() * 2 >= area
    }

    private fun setContent(view: View) {
        // A new ad replaces the one awaiting its impression.
        impressionCheck?.let { mainHandler.removeCallbacks(it) }
        impressionCheck = null
        destroyNativeAdViews()
        root.removeAllViews()
        root.addView(
            view,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ),
        )
        // Measure the content's natural height (the root is clamped to the
        // current Flutter-side size) and report it in logical pixels.
        root.post {
            val h = naturalHeight(view, root.width)
            if (h > 0) send("onAdSize", mapOf("height" to h))
        }
    }

    /** Best-effort image load: the ad still renders without it. */
    private fun downloadImage(url: String?, target: ImageView, width: Int, height: Int) {
        if (url.isNullOrEmpty()) return
        imageLoads += NativeImageLoader.executor.submit {
            val bitmap = NativeImageLoader.load(url, width, height) ?: return@submit
            mainHandler.post { if (!disposed) target.setImageBitmap(bitmap) }
        }
    }

    /**
     * Invokes a Dart callback on the main thread. Prebid fires native
     * impression/click events from a background thread, and MethodChannel
     * must only be used from the platform thread.
     */
    private fun send(method: String, args: Any? = null) {
        if (disposed) return
        if (Looper.myLooper() == Looper.getMainLooper()) {
            methodChannel.invokeMethod(method, args)
        } else {
            mainHandler.post { if (!disposed) methodChannel.invokeMethod(method, args) }
        }
    }

    override fun getView(): View = root

    override fun dispose() {
        disposed = true
        methodChannel.setMethodCallHandler(null)
        mainHandler.removeCallbacksAndMessages(null)
        imageLoads.forEach { it.cancel(true) }
        imageLoads.clear()
        adUnit?.destroy()
        unifiedNativeAd?.destroy()
        customFormatAd?.destroy()
        destroyNativeAdViews()
    }

    /** Frees a shown unified ad's view (its media view), as Google asks. */
    private fun destroyNativeAdViews() {
        for (i in 0 until root.childCount) (root.getChildAt(i) as? NativeAdView)?.destroy()
    }
}

private const val CHECK_INTERVAL_MS = 250L
private const val REQUIRED_VIEWABLE_CHECKS = 5 // 1 s / 0.25 s + 1, as Prebid iOS
