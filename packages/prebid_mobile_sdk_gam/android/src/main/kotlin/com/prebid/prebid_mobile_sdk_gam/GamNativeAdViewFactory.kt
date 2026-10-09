package com.prebid.prebid_mobile_sdk_gam

import android.content.Context
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
import java.net.URL
import org.prebid.mobile.NativeAdUnit
import org.prebid.mobile.NativeDataAsset
import org.prebid.mobile.NativeEventTracker
import org.prebid.mobile.NativeImageAsset
import org.prebid.mobile.NativeTitleAsset
import org.prebid.mobile.PrebidNativeAd
import org.prebid.mobile.PrebidNativeAdEventListener
import org.prebid.mobile.PrebidNativeAdListener
import org.prebid.mobile.ResultCode
import org.prebid.mobile.addendum.AdViewUtils

/// PlatformView factory for GAM Original-API native ads (custom-template +
/// unified). Prebid runs the auction, GAM resolves the line item, and
/// [AdViewUtils.findNative] extracts the Prebid winning bid for app-side
/// rendering — matching Prebid's reference GAM native integration.
class GamNativeAdViewFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any>()
        return GamNativePlatformView(context, messenger, params)
    }
}

class GamNativePlatformView(
    private val context: Context,
    messenger: BinaryMessenger,
    params: Map<*, *>,
) : PlatformView {

    private val logicalId = (params["logicalId"] as? Number)?.toLong() ?: 0L
    private val configId = params["configId"] as? String ?: ""
    private val gamAdUnitId = params["gamAdUnitId"] as? String ?: ""
    private val customFormatId = params["customFormatId"] as? String ?: ""

    private val methodChannel =
        MethodChannel(messenger, "prebid_mobile_sdk_gam/native_$logicalId")
    private val root = FrameLayout(context)
    private val mainHandler = Handler(Looper.getMainLooper())

    private var adUnit: NativeAdUnit? = null
    private var adLoader: AdLoader? = null
    private var unifiedNativeAd: NativeAd? = null
    private var prebidNativeAd: PrebidNativeAd? = null

    // Held as a strong-referenced field: PrebidMobile keeps only a WeakReference
    // to the event listener, so an inline/anonymous instance would be GC'd and
    // impression/click callbacks would never fire.
    private val nativeEventListener = object : PrebidNativeAdEventListener {
        override fun onAdClicked() {
            send("onAdClicked")
        }

        override fun onAdImpression() {
            send("onAdImpression")
        }

        override fun onAdExpired() {}
    }

    init {
        val adRequest = AdManagerAdRequest.Builder().build()

        val nativeAdUnit = NativeAdUnit(configId)
        nativeAdUnit.setContextType(NativeAdUnit.CONTEXT_TYPE.SOCIAL_CENTRIC)
        nativeAdUnit.setPlacementType(NativeAdUnit.PLACEMENTTYPE.CONTENT_FEED)
        nativeAdUnit.setContextSubType(NativeAdUnit.CONTEXTSUBTYPE.GENERAL_SOCIAL)
        addNativeAssets(nativeAdUnit)
        adUnit = nativeAdUnit

        val loader = buildAdLoader()
        adLoader = loader

        nativeAdUnit.fetchDemand(adRequest) { resultCode: ResultCode ->
            if (resultCode == ResultCode.SUCCESS) {
                send("fetchDemandSuccess")
            } else {
                send("fetchDemandFailed", resultCode.name)
            }
            loader.loadAd(adRequest)
        }
    }

    private fun buildAdLoader(): AdLoader {
        val builder = AdLoader.Builder(context, gamAdUnitId)
            .forNativeAd { ad: NativeAd ->
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
                    send("customAdLoaded")
                    AdViewUtils.findNative(
                        customAd,
                        object : PrebidNativeAdListener {
                            override fun onPrebidNativeLoaded(ad: PrebidNativeAd) {
                                send("nativeAdLoaded")
                                renderPrebidNative(ad)
                            }

                            override fun onPrebidNativeNotFound() {
                                send("primaryAdWinCustom")
                                renderCustomTemplate(customAd)
                            }

                            override fun onPrebidNativeNotValid() {
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

        val methods = arrayListOf(
            NativeEventTracker.EVENT_TRACKING_METHOD.IMAGE,
            NativeEventTracker.EVENT_TRACKING_METHOD.JS,
        )
        try {
            adUnit.addEventTracker(
                NativeEventTracker(NativeEventTracker.EVENT_TYPE.IMPRESSION, methods),
            )
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /// Renders the Prebid winning native creative and registers the view so
    /// Prebid tracks impressions/clicks.
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
        downloadImage(ad.iconUrl, iconView)
        downloadImage(ad.imageUrl, imageView)

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
        ad.registerView(
            container,
            listOf(iconView, titleView, imageView, bodyView, ctaView),
            nativeEventListener,
        )
    }

    /// Renders a GAM unified native ad (no Prebid creative present).
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

    /// Minimal fallback rendering for a GAM custom-format ad that carries no
    /// Prebid creative. Records the impression so GAM tracking stays intact.
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

    private fun downloadImage(url: String?, target: ImageView) {
        if (url.isNullOrEmpty()) return
        Thread {
            try {
                val stream = URL(url).openStream()
                val bitmap = BitmapFactory.decodeStream(stream)
                stream.close()
                if (bitmap != null) target.post { target.setImageBitmap(bitmap) }
            } catch (e: Exception) {
                // Best-effort image download for the demo; ignore failures.
            }
        }.start()
    }

    /// Invokes a Dart callback on the main thread. Prebid fires native
    /// impression/click events from a background thread, and MethodChannel
    /// must only be used from the platform thread.
    private fun send(method: String, args: Any? = null) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            methodChannel.invokeMethod(method, args)
        } else {
            mainHandler.post { methodChannel.invokeMethod(method, args) }
        }
    }

    override fun getView(): View = root

    override fun dispose() {
        mainHandler.removeCallbacksAndMessages(null)
        adUnit?.destroy()
        unifiedNativeAd?.destroy()
    }
}
