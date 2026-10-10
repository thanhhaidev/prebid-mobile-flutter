package io.github.thanhhaidev.prebid_mobile_sdk

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import org.prebid.mobile.ResultCode

// Shared by the core package and the GAM package; tool/check_copies.sh
// keeps the copies identical.

/** Downloads native ad images off the main thread, on a small shared pool. */
internal object NativeImageLoader {
    val mainHandler = Handler(Looper.getMainLooper())

    val executor: ExecutorService = Executors.newFixedThreadPool(2) { task ->
        Thread(task, "PrebidNativeImage").apply { isDaemon = true }
    }

    private const val TIMEOUT_MS = 10_000
    private const val MAX_BYTES = 10 * 1024 * 1024

    /**
     * Downloads and decodes [url], downsampled to about [width] x [height]
     * pixels; null on any failure.
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

/**
 * Maps an Android [ResultCode] to the result-code names the
 * Dart API uses (the iOS `ResultCode` case names), so both platforms report
 * the same strings and `isSuccess` works everywhere.
 */
internal fun ResultCode.toDartCode(): String = when (this) {
    ResultCode.SUCCESS -> "prebidDemandFetchSuccess"
    ResultCode.INVALID_ACCOUNT_ID -> "prebidInvalidAccountId"
    ResultCode.INVALID_CONFIG_ID -> "prebidInvalidConfigId"
    ResultCode.INVALID_SIZE -> "prebidInvalidSize"
    ResultCode.INVALID_HOST_URL -> "prebidServerURLInvalid"
    ResultCode.NETWORK_ERROR -> "prebidNetworkError"
    ResultCode.PREBID_SERVER_ERROR -> "prebidServerError"
    ResultCode.NO_BIDS -> "prebidDemandNoBids"
    ResultCode.NO_CACHED_BIDS -> "prebidDemandNoCachedBids"
    ResultCode.TIMEOUT -> "prebidDemandTimedOut"
    ResultCode.INVALID_CONTEXT -> "prebidInvalidContext"
    ResultCode.INVALID_AD_OBJECT -> "prebidInvalidAdObject"
    ResultCode.INVALID_NATIVE_REQUEST -> "prebidInvalidNativeRequest"
    ResultCode.INVALID_PREBID_REQUEST_OBJECT -> "prebidInvalidRequest"
}
