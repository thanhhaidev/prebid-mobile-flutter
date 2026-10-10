package io.github.thanhhaidev.prebid_mobile_sdk

import android.content.Context
import android.os.Handler
import android.os.Looper
import org.prebid.mobile.EidsPlacement
import org.prebid.mobile.ExternalUserId
import org.prebid.mobile.Host
import org.prebid.mobile.PrebidEventDelegate
import org.prebid.mobile.PrebidMobile
import org.prebid.mobile.TargetingParams
import org.prebid.mobile.api.data.InitializationStatus
import org.prebid.mobile.rendering.utils.helpers.AppInfoManager

/**
 * PrebidMobileHostApi: SDK initialization and the PrebidMobile settings.
 * [releaseAds] destroys every ad of this engine (Dart hot restart).
 */
class PrebidMobileHostApiImpl(
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
        callback: (Result<InitializationResult>) -> Unit
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
    }


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
        // Dart PrebidLogLevel order: debug, verbose, info, warn, error, severe.
        // Android has no VERBOSE/SEVERE: verbose -> DEBUG, severe -> ERROR
        // (closest levels; NONE would silence errors too).
        val logLevel = when (level.toInt()) {
            0, 1 -> PrebidMobile.LogLevel.DEBUG
            2 -> PrebidMobile.LogLevel.INFO
            3 -> PrebidMobile.LogLevel.WARN
            4, 5 -> PrebidMobile.LogLevel.ERROR
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

    override fun getCreativeFactoryTimeout(): Long =
        PrebidMobile.getCreativeFactoryTimeout().toLong()

    override fun getCreativeFactoryTimeoutPreRenderContent(): Long =
        PrebidMobile.getCreativeFactoryTimeoutPreRenderContent().toLong()

    override fun setPrebidServerAccountId(accountId: String) {
        PrebidMobile.setPrebidServerAccountId(accountId)
    }

    override fun getPrebidServerAccountId(): String =
        PrebidMobile.getPrebidServerAccountId() ?: ""

    override fun setPrebidServerUrl(url: String) {
        // Updates the CUSTOM host singleton that every auction reads its URL from.
        Host.createCustomHost(url)
    }

    override fun getPrebidServerUrl(): String? =
        PrebidMobile.getPrebidServerHost()?.hostUrl?.takeIf { it.isNotEmpty() }

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
            }
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

    override fun getSharedId(): ExternalUserIdData? {
        val id = TargetingParams.getSharedId() ?: return null
        val uid = id.uniqueIds.firstOrNull() ?: return null
        return ExternalUserIdData(
            source = id.source,
            identifier = uid.id,
            atype = uid.atype.toLong(),
        )
    }

    override fun resetSharedId() {
        TargetingParams.resetSharedId()
    }

    // External User IDs
    override fun setExternalUserIds(userIds: List<ExternalUserIdData>) {
        val ids = userIds.map { data ->
            val uniqueId = ExternalUserId.UniqueId(data.identifier, data.atype?.toInt() ?: 0)
            data.ext?.let { ext ->
                val extMap = HashMap<String, Any>()
                ext.forEach { (k, v) -> if (k != null && v != null) extMap[k] = v }
                uniqueId.setExt(extMap)
            }
            ExternalUserId(data.source, listOf(uniqueId)).apply {
                setInserter(data.inserter)
                setMatcher(data.matcher)
                setMm(data.mm?.toInt())
            }
        }
        TargetingParams.setExternalUserIds(ArrayList(ids))
    }

    override fun getExternalUserIds(): List<ExternalUserIdData> {
        val ids = TargetingParams.getExternalUserIds() ?: return emptyList()
        return ids.flatMap { uid ->
            val source = uid.source
            uid.uniqueIds.map { uniqueId ->
                ExternalUserIdData(
                    source = source,
                    identifier = uniqueId.id,
                    atype = uniqueId.atype.toLong(),
                    ext = uniqueId.json?.optJSONObject("ext")?.toMap(),
                    inserter = uid.inserter,
                    matcher = uid.matcher,
                    mm = uid.mm?.toLong(),
                )
            }
        }
    }

    override fun clearExternalUserIds() {
        TargetingParams.setExternalUserIds(null)
    }

    override fun getSdkVersion(): String {
        return PrebidMobile.SDK_VERSION
    }

    override fun getOmsdkVersion(): String = PrebidMobile.OMSDK_VERSION

    private companion object {
        val pendingInitCallbacks = mutableListOf<(Result<InitializationResult>) -> Unit>()
    }
}
