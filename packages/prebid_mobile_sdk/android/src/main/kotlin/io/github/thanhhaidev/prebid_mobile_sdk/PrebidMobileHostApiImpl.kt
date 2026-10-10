package io.github.thanhhaidev.prebid_mobile_sdk

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import org.json.JSONObject
import org.prebid.mobile.EidsPlacement
import org.prebid.mobile.ExternalUserId
import org.prebid.mobile.Host
import org.prebid.mobile.LogUtil
import org.prebid.mobile.PrebidEventDelegate
import org.prebid.mobile.PrebidMobile
import org.prebid.mobile.TargetingParams
import org.prebid.mobile.api.data.InitializationStatus
import org.prebid.mobile.rendering.utils.helpers.AppInfoManager

/**
 * PrebidMobileHostApi: SDK initialization and the PrebidMobile settings.
 * [releaseAds] destroys every ad of this engine (Dart hot restart).
 */
internal class PrebidMobileHostApiImpl(
    private val context: Context,
    private val eventFlutterApi: PrebidEventFlutterApi,
    private val releaseAds: () -> Unit,
) : PrebidMobileHostApi {

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun releaseAds() = releaseAds.invoke()

    override fun initializeSdk(
        prebidServerUrl: String,
        accountId: String,
        nonTrackingUrl: String?, // iOS only (ATT); Prebid Android has no equivalent.
        callback: (Result<InitializationResult>) -> Unit,
    ) {
        PrebidMobile.setPrebidServerAccountId(accountId)
        // Prebid's SdkInitializer returns without calling the listener when the
        // SDK is already initialized (e.g. after a Dart hot restart) or still
        // initializing, which would leave this Future pending forever.
        if (PrebidMobile.isSdkInitialized()) {
            // Still applies the (possibly new) server URL; the listener is skipped.
            PrebidMobile.initializeSdk(context, prebidServerUrl) {}
            callback(Result.success(InitializationResult(status = "succeeded")))
            return
        }
        // Process-wide, like Prebid's init state: an init already running for
        // another engine also answers this one.
        pendingInitCallbacks += callback
        if (pendingInitCallbacks.size > 1) return
        PrebidMobile.initializeSdk(context, prebidServerUrl) { status ->
            val statusStr = when (status) {
                InitializationStatus.SUCCEEDED -> "succeeded"
                InitializationStatus.SERVER_STATUS_WARNING -> "serverStatusWarning"
                else -> "failed"
            }
            val result = InitializationResult(status = statusStr, error = status.description)
            mainHandler.post {
                val callbacks = pendingInitCallbacks.toList()
                pendingInitCallbacks.clear()
                callbacks.forEach { it(Result.success(result)) }
            }
        }
        // The first init (synchronously) replaces app.name with the app label.
        TargetingHostApiImpl.appNameOverride?.let { AppInfoManager.setAppName(it) }
        checkGmaCompatibility()
    }

    /**
     * With Google Mobile Ads linked (found by class name, so the core plugin
     * needn't depend on it), lets Prebid check its version is one it
     * supports: a warning in the log otherwise.
     */
    private fun checkGmaCompatibility() {
        gmaVersion("com.google.android.gms.ads.MobileAds")
            ?.let(PrebidMobile::checkGoogleMobileAdsCompatibility)
        gmaVersion("com.google.android.libraries.ads.mobile.sdk.MobileAds")
            ?.let(PrebidMobile::checkGoogleMobileAdsNextGenCompatibility)
    }

    private fun gmaVersion(mobileAds: String): String? = runCatching {
        Class.forName(mobileAds).getMethod("getVersion").invoke(null)?.toString()
    }.getOrNull()

    override fun setTimeoutMillis(timeoutMillis: Long) {
        PrebidMobile.setTimeoutMillis(timeoutMillis.toInt())
    }

    override fun setShareGeoLocation(share: Boolean) {
        PrebidMobile.setShareGeoLocation(share)
    }

    override fun setPbsDebug(enabled: Boolean) {
        PrebidMobile.setPbsDebug(enabled)
    }

    override fun setCustomHeaders(headers: Map<String, String>) {
        PrebidMobile.setCustomHeaders(HashMap(headers))
    }

    override fun setStoredAuctionResponse(response: String) {
        PrebidMobile.setStoredAuctionResponse(response)
    }

    override fun clearStoredAuctionResponse() {
        PrebidMobile.setStoredAuctionResponse(null)
    }

    override fun addStoredBidResponse(bidder: String, responseId: String) {
        PrebidMobile.addStoredBidResponse(bidder, responseId)
    }

    override fun clearStoredBidResponses() {
        PrebidMobile.clearStoredBidResponses()
    }

    override fun setLogLevel(level: Long) {
        // Dart PrebidLogLevel order: debug, verbose, info, warn, error,
        // severe, none. Android has no VERBOSE/SEVERE: verbose -> DEBUG,
        // severe -> ERROR (the closest levels).
        val logLevel = when (level.toInt()) {
            0, 1 -> PrebidMobile.LogLevel.DEBUG
            2 -> PrebidMobile.LogLevel.INFO
            3 -> PrebidMobile.LogLevel.WARN
            4, 5 -> PrebidMobile.LogLevel.ERROR
            6 -> PrebidMobile.LogLevel.NONE
            else -> PrebidMobile.LogLevel.DEBUG
        }
        PrebidMobile.setLogLevel(logLevel)
    }

    override fun setCreativeFactoryTimeout(timeout: Long) {
        PrebidMobile.setCreativeFactoryTimeout(timeout.toInt())
    }

    override fun setCreativeFactoryTimeoutPreRenderContent(timeout: Long) {
        PrebidMobile.setCreativeFactoryTimeoutPreRenderContent(timeout.toInt())
    }

    override fun getCreativeFactoryTimeout(): Long = PrebidMobile.getCreativeFactoryTimeout().toLong()

    override fun getCreativeFactoryTimeoutPreRenderContent(): Long =
        PrebidMobile.getCreativeFactoryTimeoutPreRenderContent().toLong()

    override fun setPrebidServerAccountId(accountId: String) {
        PrebidMobile.setPrebidServerAccountId(accountId)
    }

    override fun getPrebidServerAccountId(): String = PrebidMobile.getPrebidServerAccountId() ?: ""

    override fun setPrebidServerUrl(url: String) {
        // Updates the CUSTOM host singleton that every auction reads its URL from.
        Host.createCustomHost(url)
    }

    override fun getPrebidServerUrl(): String? = PrebidMobile.getPrebidServerHost()?.hostUrl?.takeIf { it.isNotEmpty() }

    override fun setUseCacheForReportingWithRenderingApi(use: Boolean) {
        PrebidMobile.setUseCacheForReportingWithRenderingApi(use)
    }

    override fun getUseCacheForReportingWithRenderingApi(): Boolean =
        PrebidMobile.isUseCacheForReportingWithRenderingApi()

    override fun setCustomStatusEndpoint(endpoint: String) {
        PrebidMobile.setCustomStatusEndpoint(endpoint)
    }

    override fun setShouldAssignNativeAssetId(assign: Boolean) {
        PrebidMobile.assignNativeAssetID(assign)
    }

    override fun setFilterOutUncachedBids(filter: Boolean) {
        PrebidMobile.setFilterOutUncachedBids(filter)
    }

    override fun setEidsPlacement(placement: String) {
        PrebidMobile.setEidsPlacement(
            when (placement) {
                "openRtb26" -> EidsPlacement.OPEN_RTB_2_6
                "openRtb25" -> EidsPlacement.OPEN_RTB_2_5
                else -> EidsPlacement.COMPATIBLE
            },
        )
    }

    override fun setIncludeWinners(include: Boolean) {
        PrebidMobile.setIncludeWinnersFlag(include)
    }

    override fun setIncludeBidderKeys(include: Boolean) {
        PrebidMobile.setIncludeBidderKeysFlag(include)
    }

    override fun setAuctionSettingsId(settingsId: String?) {
        PrebidMobile.setAuctionSettingsId(settingsId)
    }

    override fun setDisableStatusCheck(disable: Boolean) {
        PrebidMobile.setDisableStatusCheck(disable)
    }

    // Strong reference: Prebid holds the event delegate in a WeakReference.
    private var eventDelegate: PrebidEventDelegate? = null

    override fun setEventDelegateEnabled(enabled: Boolean) {
        if (!enabled) return clearEventDelegate()
        eventDelegate = PrebidEventDelegate { request, response ->
            // Called on a background thread; Flutter channels need main.
            val req = request?.toString()
            val res = response?.toString()
            mainHandler.post { eventFlutterApi.onBidResponse(req, res) {} }
        }
        PrebidMobile.setEventDelegate(eventDelegate)
    }

    private var logger: LogUtil.PrebidLogger? = null

    /** Prebid's logger before this engine set its own, restored on disable. */
    private var consoleLogger: LogUtil.PrebidLogger? = null

    override fun setLogListenerEnabled(enabled: Boolean) {
        if (!enabled) return clearLogger()
        if (logger == null) consoleLogger = PrebidMobile.getCustomLogger()
        val forwarder = object : LogUtil.PrebidLogger {
            override fun println(priority: Int, tag: String, message: String) {
                send(priority.toDartLogLevel(), message)
            }

            override fun e(tag: String, message: String, throwable: Throwable) {
                send(4, throwable.message?.let { "$message: $it" } ?: message)
            }
        }
        logger = forwarder
        PrebidMobile.setCustomLogger(forwarder)
    }

    // Prebid logs from any thread; Flutter channels need main.
    private fun send(level: Long, message: String) {
        mainHandler.post { eventFlutterApi.onLog(level, message) {} }
    }

    /** Restores the console logger, while the current one is still this engine's. */
    fun clearLogger() {
        val own = logger ?: return
        logger = null
        if (PrebidMobile.getCustomLogger() === own) consoleLogger?.let(PrebidMobile::setCustomLogger)
    }

    // Location updates are an iOS setting: Prebid Android only reads the
    // last known location (setShareGeoLocation).
    override fun setLocationUpdatesEnabled(enabled: Boolean) {}
    override fun getLocationUpdatesEnabled(): Boolean? = null

    // iOS only (Prebid Android has no log file).
    override fun setDebugLogFileEnabled(enabled: Boolean) {}
    override fun getDebugLogFileEnabled(): Boolean? = null

    // Prebid Android writes Prebid Server's timeout into timeoutMillis itself
    // (getTimeoutMillis) rather than keeping a separate dynamic value.
    override fun getTimeoutMillisDynamic(): Long? = null

    /**
     * Drops this engine's delegate. Prebid has a single process-wide one, so
     * it's only cleared there while it is still this engine's: another
     * engine (add-to-app) may have set its own since.
     */
    fun clearEventDelegate() {
        val own = eventDelegate ?: return
        eventDelegate = null
        if (PrebidMobile.getEventDelegate() === own) PrebidMobile.setEventDelegate(null)
    }

    // SharedID
    override fun setSendSharedId(send: Boolean) {
        TargetingParams.setSendSharedId(send)
    }

    override fun getSharedId(): ExternalUserIdData? = TargetingParams.getSharedId()?.toData()

    override fun resetSharedId() {
        TargetingParams.resetSharedId()
    }

    // External User IDs
    override fun setExternalUserIds(userIds: List<ExternalUserIdData>) {
        val ids = userIds.map { data ->
            val uniqueIds = data.uids.filterNotNull().map { uid ->
                ExternalUserId.UniqueId(uid.id, uid.atype.toInt()).apply {
                    uid.ext?.stringKeys()?.let(::setExt)
                }
            }
            ExternalUserId(data.source, uniqueIds).apply {
                data.ext?.stringKeys()?.let(::setExt)
                setInserter(data.inserter)
                setMatcher(data.matcher)
                setMm(data.mm?.toInt())
            }
        }
        TargetingParams.setExternalUserIds(ArrayList(ids))
    }

    override fun getExternalUserIds(): List<ExternalUserIdData> =
        TargetingParams.getExternalUserIds().orEmpty().map { it.toData() }

    private fun ExternalUserId.toData() = ExternalUserIdData(
        source = source,
        uids = uniqueIds.map { uid ->
            UserUniqueIdData(
                id = uid.id,
                atype = uid.atype.toLong(),
                ext = uid.json?.optJSONObject("ext")?.toMap(),
            )
        },
        ext = ext?.let { JSONObject(it).toMap() },
        inserter = inserter,
        matcher = matcher,
        mm = mm?.toLong(),
    )

    /** A Pigeon map without its null keys and values, as the Prebid setters want. */
    private fun Map<String?, Any?>.stringKeys(): Map<String, Any> =
        entries.mapNotNull { (k, v) -> if (k != null && v != null) k to v else null }.toMap()

    override fun clearExternalUserIds() {
        TargetingParams.setExternalUserIds(null)
    }

    override fun getTimeoutMillis(): Long = PrebidMobile.getTimeoutMillis().toLong()
    override fun getPbsDebug(): Boolean = PrebidMobile.getPbsDebug()
    override fun getShareGeoLocation(): Boolean = PrebidMobile.isShareGeoLocation()
    override fun getCustomHeaders(): Map<String, String> = PrebidMobile.getCustomHeaders().orEmpty()
    override fun getStoredAuctionResponse(): String? = PrebidMobile.getStoredAuctionResponse()
    override fun getStoredBidResponses(): Map<String, String> = PrebidMobile.getStoredBidResponses().orEmpty()
    override fun getCustomStatusEndpoint(): String? = PrebidMobile.getCustomStatusEndpoint()
    override fun getShouldAssignNativeAssetId(): Boolean = PrebidMobile.shouldAssignNativeAssetID()
    override fun getFilterOutUncachedBids(): Boolean = PrebidMobile.isFilterOutUncachedBids()
    override fun getIncludeWinners(): Boolean = PrebidMobile.getIncludeWinnersFlag()
    override fun getIncludeBidderKeys(): Boolean = PrebidMobile.getIncludeBidderKeysFlag()
    override fun getAuctionSettingsId(): String? = PrebidMobile.getAuctionSettingsId()
    override fun getDisableStatusCheck(): Boolean = PrebidMobile.shouldDisableStatusCheck()

    override fun getEidsPlacement(): String = when (PrebidMobile.getEidsPlacement()) {
        EidsPlacement.OPEN_RTB_2_6 -> "openRtb26"
        EidsPlacement.OPEN_RTB_2_5 -> "openRtb25"
        else -> "compatible"
    }

    override fun getSdkVersion(): String = PrebidMobile.SDK_VERSION

    override fun getOmsdkVersion(): String = PrebidMobile.OMSDK_VERSION

    private companion object {
        val pendingInitCallbacks = mutableListOf<(Result<InitializationResult>) -> Unit>()
    }
}

/** An android.util.Log priority as a Dart PrebidLogLevel index. */
private fun Int.toDartLogLevel(): Long = when (this) {
    Log.VERBOSE -> 1
    Log.INFO -> 2
    Log.WARN -> 3
    Log.ERROR -> 4
    Log.ASSERT -> 5
    else -> 0
}
