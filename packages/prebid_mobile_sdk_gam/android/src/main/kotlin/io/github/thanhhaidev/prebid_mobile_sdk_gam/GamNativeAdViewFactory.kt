package io.github.thanhhaidev.prebid_mobile_sdk_gam

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
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
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.atomic.AtomicBoolean
import org.prebid.mobile.NativeAdUnit
import org.prebid.mobile.NativeDataAsset
import org.prebid.mobile.NativeEventTracker
import org.prebid.mobile.NativeImageAsset
import org.prebid.mobile.NativeTitleAsset
import org.prebid.mobile.PrebidNativeAd
import org.prebid.mobile.PrebidNativeAdEventListener
import org.prebid.mobile.PrebidMobile
import org.prebid.mobile.PrebidNativeAdListener
import org.prebid.mobile.ResultCode
import org.prebid.mobile.addendum.AdViewUtils

/**
 * PlatformView factory for GAM Original-API native ads (custom-template +
 * unified). Prebid runs the auction, GAM resolves the line item, and
 * [AdViewUtils.findNative] extracts the Prebid winning bid for app-side
 * rendering — matching Prebid's reference GAM native integration.
 */
internal class GamNativeAdViewFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any>()
        return GamNativePlatformView(context, messenger, params)
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
) : PlatformView {

    private val channelId = (params["channelId"] as? Number)?.toLong() ?: 0L
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

    private val methodChannel =
        MethodChannel(messenger, "prebid_mobile_sdk_gam/native_$channelId")
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
        // Prebid adds its hb_* keys to this request after the app's, so they
        // win on conflict.
        val adRequest = AdManagerAdRequest.Builder().apply {
            customTargeting?.forEach { (k, v) -> addCustomTargeting(k, v) }
        }.build()

        val nativeAdUnit = NativeAdUnit(configId)
        nativeAdUnit.setContextType(NativeAdUnit.CONTEXT_TYPE.SOCIAL_CENTRIC)
        nativeAdUnit.setPlacementType(NativeAdUnit.PLACEMENTTYPE.CONTENT_FEED)
        nativeAdUnit.setContextSubType(NativeAdUnit.CONTEXTSUBTYPE.GENERAL_SOCIAL)
        nativeContext.context?.let { nativeAdUnit.setContextType(it) }
        nativeContext.subType?.let { nativeAdUnit.setContextSubType(it) }
        nativeContext.placement?.let { nativeAdUnit.setPlacementType(it) }
        addNativeAssets(nativeAdUnit)
        gpid?.let { nativeAdUnit.setGpid(it) }
        pbAdSlot?.let { nativeAdUnit.setPbAdSlot(it) }
        impOrtbConfig?.let { nativeAdUnit.setImpOrtbConfig(it) }
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
                    send("primaryAdFailed", error.message)
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
            (customTrackers ?: defaultTrackers()).forEach { adUnit.addEventTracker(it) }
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

        (customTrackers ?: defaultTrackers()).forEach { adUnit.addEventTracker(it) }
    }

    private fun defaultTrackers(): List<NativeEventTracker> = listOfNotNull(
        runCatching {
            NativeEventTracker(
                NativeEventTracker.EVENT_TYPE.IMPRESSION,
                arrayListOf(
                    NativeEventTracker.EVENT_TRACKING_METHOD.IMAGE,
                    NativeEventTracker.EVENT_TRACKING_METHOD.JS,
                ),
            )
        }.getOrNull(),
    )

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
            420,
        )
        downloadImage(ad.iconUrl, iconView, 96, 96)
        downloadImage(ad.imageUrl, imageView, context.resources.displayMetrics.widthPixels, 420)

        val header = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(
                iconView,
                LinearLayout.LayoutParams(96, 96).apply { rightMargin = 24 },
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
            setPadding(24, 24, 24, 24)
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
            420,
        )
        ad.mediaContent?.let { mediaView.mediaContent = it }

        val header = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(
                iconView,
                LinearLayout.LayoutParams(96, 96).apply { rightMargin = 24 },
            )
            addView(headlineView)
        }

        val content = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(24, 24, 24, 24)
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
     * Prebid creative. Records the impression so GAM tracking stays intact.
     */
    private fun renderCustomTemplate(ad: NativeCustomFormatAd) {
        val label = TextView(context).apply {
            text = ad.getText("title") ?: "Ad"
            textSize = 15f
            setPadding(24, 24, 24, 24)
        }
        setContent(label)
        ad.recordImpression()
    }

    private fun setContent(view: View) {
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
            view.measure(
                View.MeasureSpec.makeMeasureSpec(root.width, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            )
            val h = view.measuredHeight / context.resources.displayMetrics.density
            if (h > 0) {
                send("onAdSize", mapOf("height" to h.toDouble()))
            }
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
            mainHandler.post { methodChannel.invokeMethod(method, args) }
        }
    }

    override fun getView(): View = root

    override fun dispose() {
        disposed = true
        mainHandler.removeCallbacksAndMessages(null)
        imageLoads.forEach { it.cancel(true) }
        imageLoads.clear()
        adUnit?.destroy()
        unifiedNativeAd?.destroy()
        customFormatAd?.destroy()
    }
}

/** Downloads native ad images off the main thread, on a small shared pool. */
internal object NativeImageLoader {
    val executor: ExecutorService = Executors.newFixedThreadPool(2) { task ->
        Thread(task, "PrebidGamNativeImage").apply { isDaemon = true }
    }

    private const val TIMEOUT_MS = 10_000
    private const val MAX_BYTES = 10 * 1024 * 1024

    /**
     * Downloads and decodes [url], downsampled to about [width] x [height]
     * pixels; null on any failure, past [MAX_BYTES], or when cancelled.
     */
    fun load(url: String, width: Int, height: Int): Bitmap? = try {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = TIMEOUT_MS
        connection.readTimeout = TIMEOUT_MS
        val bytes = try {
            connection.inputStream.use { input ->
                val out = ByteArrayOutputStream()
                val buffer = ByteArray(16 * 1024)
                while (true) {
                    if (Thread.currentThread().isInterrupted) return null
                    val n = input.read(buffer)
                    if (n < 0) break
                    out.write(buffer, 0, n)
                    if (out.size() > MAX_BYTES) return null
                }
                out.toByteArray()
            }
        } finally {
            connection.disconnect()
        }
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        val options = BitmapFactory.Options().apply {
            inSampleSize = calculateInSampleSize(bounds.outWidth, bounds.outHeight, width, height)
        }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
    } catch (e: Exception) {
        null
    }
}

/**
 * The largest power-of-two `inSampleSize` that keeps a [width] x [height]
 * image at least [reqWidth] x [reqHeight] (so it still fills a cropping
 * view); 1 when either size is unknown.
 */
internal fun calculateInSampleSize(width: Int, height: Int, reqWidth: Int, reqHeight: Int): Int {
    if (width <= 0 || height <= 0 || reqWidth <= 0 || reqHeight <= 0) return 1
    var sampleSize = 1
    while (width / (sampleSize * 2) >= reqWidth && height / (sampleSize * 2) >= reqHeight) {
        sampleSize *= 2
    }
    return sampleSize
}
