package io.github.thanhhaidev.prebid_mobile_sdk_admob

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.widget.FrameLayout
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

// Shared by the companion packages; tool/check_copies.sh keeps the copies
// identical.

/**
 * A companion's preloaded banners (ADR-0008), created and destroyed from Dart
 * on [channelName]. Each is the package's own banner view, built by [create]
 * from the creation params a banner widget sends (`channelId` included) but
 * never handed to Flutter: it is kept until Dart destroys it, and shown by
 * whichever platform view created with `preloaded: true` shows it last.
 */
internal class PreloadedBanners(
    messenger: BinaryMessenger,
    channelName: String,
    private val create: (channelId: Long, params: Map<*, *>) -> PlatformView,
) {
    private val banners = mutableMapOf<Long, PlatformView>()
    private val channel = MethodChannel(messenger, channelName)

    init {
        channel.setMethodCallHandler { call, result ->
            val channelId = call.argument<Number>("channelId")?.toLong()
            when (call.method) {
                "create" -> {
                    if (channelId != null && channelId !in banners) {
                        banners[channelId] = create(channelId, call.argument<Map<*, *>>("config").orEmpty())
                    }
                    result.success(null)
                }

                "destroy" -> {
                    channelId?.let(::destroy)
                    result.success(null)
                }

                // After a Dart hot restart: the previous isolate's banners.
                "releaseAll" -> {
                    releaseAll()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    /** The platform view showing the banner of [channelId], if it exists. */
    fun platformView(context: Context, channelId: Long): PlatformView =
        PreloadedBannerPlatformView(context, banners[channelId]?.view)

    /** Stops listening and destroys every banner (engine detached). */
    fun dispose() {
        channel.setMethodCallHandler(null)
        releaseAll()
    }

    private fun destroy(channelId: Long) {
        banners.remove(channelId)?.let { banner ->
            banner.view?.let { (it.parent as? ViewGroup)?.removeView(it) }
            banner.dispose()
        }
    }

    private fun releaseAll() = banners.keys.toList().forEach(::destroy)
}

/**
 * Shows a preloaded banner's view in its own container. Disposing it takes
 * the banner out only if it is still there: a newer view may have taken it
 * over.
 */
private class PreloadedBannerPlatformView(
    context: Context,
    private val banner: View?,
) : PlatformView {
    private val container = FrameLayout(context)

    init {
        banner?.let {
            (it.parent as? ViewGroup)?.removeView(it)
            container.addView(it, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
        }
    }

    override fun getView(): View = container

    override fun dispose() {
        if (banner?.parent === container) container.removeView(banner)
    }
}
