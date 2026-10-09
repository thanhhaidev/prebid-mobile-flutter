package com.prebid.prebid_mobile_sdk

import android.app.Activity
import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import org.prebid.mobile.ExternalUserId
import org.prebid.mobile.PrebidMobile
import org.prebid.mobile.TargetingParams
import org.prebid.mobile.api.data.InitializationStatus

class PrebidMobileFlutterPlugin : FlutterPlugin, ActivityAware,
    PrebidMobileHostApi, TargetingHostApi, InterstitialAdHostApi {

    private lateinit var context: Context
    private var activity: Activity? = null
    private lateinit var flutterApi: AdFlutterApi
    private lateinit var eventFlutterApi: PrebidEventFlutterApi
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

    fun getActivity(): Activity? = activity

    private val interstitialAds = mutableMapOf<Long, org.prebid.mobile.api.rendering.InterstitialAdUnit>()
    private lateinit var rewardedApi: RewardedAdHostApiImpl

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        flutterApi = AdFlutterApi(binding.binaryMessenger)
        eventFlutterApi = PrebidEventFlutterApi(binding.binaryMessenger)

        // Register Pigeon APIs
        PrebidMobileHostApi.setUp(binding.binaryMessenger, this)
        TargetingHostApi.setUp(binding.binaryMessenger, this)
        InterstitialAdHostApi.setUp(binding.binaryMessenger, this)
        rewardedApi = RewardedAdHostApiImpl(flutterApi, this)
        RewardedAdHostApi.setUp(binding.binaryMessenger, rewardedApi)
        NativeAdHostApi.setUp(binding.binaryMessenger, NativeAdHostApiImpl(flutterApi))

        // Register multiformat handler as separate class
        MultiformatAdHostApi.setUp(
            binding.binaryMessenger,
            MultiformatAdHostApiImpl(MultiformatFlutterApi(binding.binaryMessenger), this),
        )
        InstreamVideoAdHostApi.setUp(binding.binaryMessenger, InstreamVideoAdHostApiImpl())

        // Register the BannerAd PlatformView factory
        binding.platformViewRegistry.registerViewFactory(
            "prebid_mobile_flutter/banner_ad",
            BannerAdViewFactory(binding.binaryMessenger) { activity }
        )
        binding.platformViewRegistry.registerViewFactory(
            "prebid_mobile_flutter/native_ad",
            NativeAdViewFactory(binding.binaryMessenger, flutterApi)
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        PrebidMobileHostApi.setUp(binding.binaryMessenger, null)
        TargetingHostApi.setUp(binding.binaryMessenger, null)
        InterstitialAdHostApi.setUp(binding.binaryMessenger, null)
        RewardedAdHostApi.setUp(binding.binaryMessenger, null)
        NativeAdHostApi.setUp(binding.binaryMessenger, null)
        MultiformatAdHostApi.setUp(binding.binaryMessenger, null)
        InstreamVideoAdHostApi.setUp(binding.binaryMessenger, null)
        PrebidMobile.setEventDelegate(null)
        eventDelegate = null
        destroyFullscreenAds(reason = null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }
    override fun onDetachedFromActivity() {
        activity = null
        // Fullscreen ad units hold the Activity they were built with; release
        // them with it instead of leaking it until Dart calls destroy().
        destroyFullscreenAds(reason = "The Activity was destroyed")
    }

    private fun destroyFullscreenAds(reason: String?) {
        val ids = interstitialAds.keys.toList()
        ids.forEach { interstitialAds.remove(it)?.destroy() }
        val rewardedIds = rewardedApi.destroyAll()
        if (reason != null) {
            (ids + rewardedIds).forEach { sendAdFailed(it, reason) }
        }
    }

    internal fun sendAdFailed(adId: Long, error: String) {
        flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdFailed", error = error)) {}
    }

    // =========================================================================
    // PrebidMobileHostApi
    // =========================================================================

    override fun initializeSdk(
        prebidServerUrl: String,
        accountId: String,
        nonTrackingUrl: String?, // iOS only (ATT); Prebid Android has no equivalent.
        callback: (Result<com.prebid.prebid_mobile_sdk.InitializationResult>) -> Unit
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
    }

    private val pendingInitCallbacks =
        mutableListOf<(Result<InitializationResult>) -> Unit>()

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
                "openRtb26" -> org.prebid.mobile.EidsPlacement.OPEN_RTB_2_6
                "openRtb25" -> org.prebid.mobile.EidsPlacement.OPEN_RTB_2_5
                else -> org.prebid.mobile.EidsPlacement.COMPATIBLE
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
    private var eventDelegate: org.prebid.mobile.PrebidEventDelegate? = null

    override fun setEventDelegateEnabled(enabled: Boolean) {
        eventDelegate = if (!enabled) null else org.prebid.mobile.PrebidEventDelegate { request, response ->
            // Called on a background thread; Flutter channels need main.
            val req = request?.toString()
            val res = response?.toString()
            mainHandler.post { eventFlutterApi.onBidResponse(req, res) {} }
        }
        PrebidMobile.setEventDelegate(eventDelegate)
    }

    // SharedID
    override fun setSendSharedId(send: Boolean) {
        TargetingParams.setSendSharedId(send)
    }

    override fun getSharedId(): ExternalUserIdData? {
        val id = TargetingParams.getSharedId() ?: return null
        val uid = id.uniqueIds?.firstOrNull() ?: return null
        return ExternalUserIdData(
            source = id.source ?: "",
            identifier = uid.id ?: "",
            atype = uid.atype?.toLong(),
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
            val source = uid.source ?: ""
            uid.uniqueIds?.map { uniqueId ->
                ExternalUserIdData(
                    source = source,
                    identifier = uniqueId.id ?: "",
                    atype = uniqueId.atype?.toLong(),
                    ext = uniqueId.json?.optJSONObject("ext")?.toMap(),
                    inserter = uid.inserter,
                    matcher = uid.matcher,
                    mm = uid.mm?.toLong(),
                )
            } ?: emptyList()
        }
    }

    override fun clearExternalUserIds() {
        TargetingParams.setExternalUserIds(null)
    }

    override fun getSdkVersion(): String {
        return PrebidMobile.SDK_VERSION
    }

    // =========================================================================
    // TargetingHostApi
    // =========================================================================

    override fun setSubjectToCOPPA(value: Boolean?) {
        TargetingParams.setSubjectToCOPPA(value)
    }
    override fun getSubjectToCOPPA(): Boolean? = TargetingParams.isSubjectToCOPPA()

    override fun setSubjectToGDPR(value: Boolean?) {
        TargetingParams.setSubjectToGDPR(value)
    }
    override fun getSubjectToGDPR(): Boolean? = TargetingParams.isSubjectToGDPR()

    override fun setGDPRConsentString(value: String?) {
        TargetingParams.setGDPRConsentString(value)
    }
    override fun getGDPRConsentString(): String? = TargetingParams.getGDPRConsentString()

    override fun setPurposeConsents(value: String?) {
        TargetingParams.setPurposeConsents(value)
    }
    override fun getPurposeConsents(): String? = TargetingParams.getPurposeConsents()
    override fun getPurposeConsent(index: Long): Boolean? = TargetingParams.getPurposeConsent(index.toInt())
    override fun getDeviceAccessConsent(): Boolean? = TargetingParams.getDeviceAccessConsent()

    // US Privacy / CCPA. Prebid's UserConsentManager reads (and listens to)
    // IABUSPrivacy_String in the default shared preferences, the IAB location.
    override fun setUSPrivacyString(value: String?) {
        val prefs = defaultPreferences()
        if (value != null) {
            prefs.edit().putString("IABUSPrivacy_String", value).apply()
        } else {
            prefs.edit().remove("IABUSPrivacy_String").apply()
        }
    }
    override fun getUSPrivacyString(): String? =
        defaultPreferences().getString("IABUSPrivacy_String", null)

    // Same file as the deprecated PreferenceManager.getDefaultSharedPreferences.
    private fun defaultPreferences() =
        context.getSharedPreferences("${context.packageName}_preferences", Context.MODE_PRIVATE)

    override fun addUserKeyword(keyword: String) { TargetingParams.addUserKeyword(keyword) }
    override fun addUserKeywords(keywords: List<String>) { keywords.forEach { TargetingParams.addUserKeyword(it) } }
    override fun removeUserKeyword(keyword: String) { TargetingParams.removeUserKeyword(keyword) }
    override fun clearUserKeywords() { TargetingParams.clearUserKeywords() }
    override fun getUserKeywords(): List<String> {
        val kw = TargetingParams.getUserKeywords()
        return if (kw.isNullOrEmpty()) emptyList() else kw.split(",").map { it.trim() }
    }

    // Prebid Android has no app-keyword API (iOS only). Don't silently rewrite
    // them as user keywords; set `app.keywords` via the global ORTB config.
    override fun addAppKeyword(keyword: String) = warnAppKeywordsUnsupported()
    override fun addAppKeywords(keywords: List<String>) = warnAppKeywordsUnsupported()
    override fun removeAppKeyword(keyword: String) = warnAppKeywordsUnsupported()
    override fun clearAppKeywords() = warnAppKeywordsUnsupported()

    private fun warnAppKeywordsUnsupported() {
        android.util.Log.w(
            "PrebidFlutter",
            "App keywords are not supported by Prebid Android; " +
                "use setGlobalOrtbConfig with app.keywords instead.",
        )
    }

    override fun addAppExtData(key: String, value: String) {
        try { TargetingParams.addExtData(key, value) } catch (_: Exception) {}
    }
    override fun updateAppExtData(key: String, value: List<String>) {
        try { TargetingParams.updateExtData(key, HashSet(value)) } catch (_: Exception) {}
    }
    override fun removeAppExtData(key: String) {
        try { TargetingParams.removeExtData(key) } catch (_: Exception) {}
    }
    override fun clearAppExtData() {
        try { TargetingParams.clearExtData() } catch (_: Exception) {}
    }

    // User Ext Data (user.ext.data). Tracked locally and written to
    // TargetingParams.userExt["data"], which Prebid merges into user.ext —
    // leaving the global ORTB config and any other user.ext keys untouched.
    private val userExtDataMap = mutableMapOf<String, MutableSet<String>>()

    override fun addUserExtData(key: String, value: String) {
        userExtDataMap.getOrPut(key) { mutableSetOf() }.add(value)
        syncUserExtData()
    }
    override fun updateUserExtData(key: String, value: List<String>) {
        userExtDataMap[key] = value.toMutableSet()
        syncUserExtData()
    }
    override fun removeUserExtData(key: String) {
        userExtDataMap.remove(key)
        syncUserExtData()
    }
    override fun clearUserExtData() {
        userExtDataMap.clear()
        syncUserExtData()
    }

    private fun syncUserExtData() {
        val ext = TargetingParams.getUserExt() ?: org.prebid.mobile.rendering.models.openrtb.bidRequests.Ext()
        ext.remove("data")
        if (userExtDataMap.isNotEmpty()) {
            val data = org.json.JSONObject()
            userExtDataMap.forEach { (k, v) -> data.put(k, org.json.JSONArray(v.sorted())) }
            ext.put("data", data)
        }
        TargetingParams.setUserExt(if (ext.getJsonObject().length() == 0) null else ext)
    }

    override fun addBidderToAccessControlList(bidderName: String) { TargetingParams.addBidderToAccessControlList(bidderName) }
    override fun removeBidderFromAccessControlList(bidderName: String) { TargetingParams.removeBidderFromAccessControlList(bidderName) }
    override fun clearAccessControlList() { TargetingParams.clearAccessControlList() }

    override fun setGlobalOrtbConfig(ortbConfig: String?) { TargetingParams.setGlobalOrtbConfig(ortbConfig) }
    override fun getGlobalOrtbConfig(): String? = TargetingParams.getGlobalOrtbConfig()

    override fun setContentUrl(url: String?) {
        // Not available on Android (and deprecated / not sent on iOS 3.4).
        // Use the global ORTB config to set app.content.url.
    }
    override fun setPublisherName(name: String?) { TargetingParams.setPublisherName(name) }
    override fun setStoreUrl(url: String?) { TargetingParams.setStoreUrl(url) }
    override fun setDomain(domain: String?) { TargetingParams.setDomain(domain) }

    // SKAdNetwork / iTunes IDs are iOS concepts; Android reads the package name.
    override fun setSourceApp(sourceApp: String?) {}
    override fun setItunesId(itunesId: String?) {}

    override fun setOmidPartnerName(name: String?) { TargetingParams.setOmidPartnerName(name) }
    override fun setOmidPartnerVersion(version: String?) { TargetingParams.setOmidPartnerVersion(version) }

    override fun setUserLatLng(latitude: Double, longitude: Double) {
        TargetingParams.setUserLatLng(latitude.toFloat(), longitude.toFloat())
    }
    override fun setLocationPrecision(precision: Long?) {
        TargetingParams.setLocationDecimalPrecision(precision?.toInt())
    }

    // =========================================================================
    // InterstitialAdHostApi
    // =========================================================================

    override fun loadAd(adId: Long, configId: String, adFormats: List<String>?, videoConfig: VideoParametersConfig?, impOrtbConfig: String?, controls: FullscreenControlsConfig?) {
        // A reload replaces the previous unit; destroy it so it stops sending
        // events under this ad id.
        interstitialAds.remove(adId)?.destroy()
        val act = activity ?: return sendAdFailed(adId, NO_ACTIVITY)

        // Build EnumSet for ad formats
        val formats = java.util.EnumSet.noneOf(org.prebid.mobile.api.data.AdUnitFormat::class.java)
        adFormats?.forEach { f ->
            when (f) {
                "banner" -> formats.add(org.prebid.mobile.api.data.AdUnitFormat.BANNER)
                "video" -> formats.add(org.prebid.mobile.api.data.AdUnitFormat.VIDEO)
            }
        }
        if (formats.isEmpty()) {
            formats.add(org.prebid.mobile.api.data.AdUnitFormat.BANNER)
        }

        val adUnit = org.prebid.mobile.api.rendering.InterstitialAdUnit(act, configId, formats)

        // The Android rendering InterstitialAdUnit has no public video-parameters
        // setter (mimes/protocols/etc. come from the SDK defaults); only the max
        // duration is configurable.
        videoConfig?.maxDuration?.let { adUnit.setMaxVideoDuration(it.toInt()) }
        impOrtbConfig?.let { adUnit.setImpOrtbConfig(it) }
        controls?.let { c ->
            c.applyTo(adUnit)
            if (c.minWidthPercentage != null && c.minHeightPercentage != null) {
                adUnit.setMinSizePercentage(
                    org.prebid.mobile.AdSize(c.minWidthPercentage.toInt(), c.minHeightPercentage.toInt())
                )
            }
        }

        adUnit.setInterstitialAdUnitListener(object : org.prebid.mobile.api.rendering.listeners.InterstitialAdUnitListener {
            override fun onAdLoaded(unit: org.prebid.mobile.api.rendering.InterstitialAdUnit) {
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdLoaded")) {}
            }
            override fun onAdFailed(unit: org.prebid.mobile.api.rendering.InterstitialAdUnit, e: org.prebid.mobile.api.exceptions.AdException?) {
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdFailed", error = e?.message)) {}
            }
            override fun onAdDisplayed(unit: org.prebid.mobile.api.rendering.InterstitialAdUnit) {
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdDisplayed")) {}
            }
            override fun onAdClosed(unit: org.prebid.mobile.api.rendering.InterstitialAdUnit) {
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdClosed")) {}
            }
            override fun onAdClicked(unit: org.prebid.mobile.api.rendering.InterstitialAdUnit) {
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdClicked")) {}
            }
            override fun onAdExpired(unit: org.prebid.mobile.api.rendering.InterstitialAdUnit) {
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdExpired")) {}
            }
        })

        interstitialAds[adId] = adUnit
        adUnit.loadAd()
    }

    override fun show(adId: Long) {
        val adUnit = interstitialAds[adId]
        if (adUnit == null || !adUnit.isLoaded) return sendAdFailed(adId, NOT_READY)
        adUnit.show()
    }

    override fun destroy(adId: Long) {
        interstitialAds.remove(adId)?.destroy()
    }

    internal companion object {
        const val NO_ACTIVITY = "No Activity is attached to the Flutter engine"
        const val NOT_READY = "The ad is not loaded"
    }
}

// =========================================================================
// RewardedAdHostApi — separate class to avoid method signature conflicts
// =========================================================================

class RewardedAdHostApiImpl(
    private val flutterApi: AdFlutterApi,
    private val plugin: PrebidMobileFlutterPlugin
) : RewardedAdHostApi {

    private val rewardedAds = mutableMapOf<Long, org.prebid.mobile.api.rendering.RewardedAdUnit>()

    override fun loadAd(adId: Long, configId: String, impOrtbConfig: String?, controls: FullscreenControlsConfig?) {
        rewardedAds.remove(adId)?.destroy()
        val act = plugin.getActivity()
            ?: return plugin.sendAdFailed(adId, PrebidMobileFlutterPlugin.NO_ACTIVITY)
        val adUnit = org.prebid.mobile.api.rendering.RewardedAdUnit(act, configId)
        impOrtbConfig?.let { adUnit.setImpOrtbConfig(it) }
        controls?.applyTo(adUnit)

        adUnit.setRewardedAdUnitListener(object : org.prebid.mobile.api.rendering.listeners.RewardedAdUnitListener {
            override fun onAdLoaded(unit: org.prebid.mobile.api.rendering.RewardedAdUnit) {
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdLoaded")) {}
            }
            override fun onAdFailed(unit: org.prebid.mobile.api.rendering.RewardedAdUnit, e: org.prebid.mobile.api.exceptions.AdException?) {
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdFailed", error = e?.message)) {}
            }
            override fun onAdDisplayed(unit: org.prebid.mobile.api.rendering.RewardedAdUnit) {
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdDisplayed")) {}
            }
            override fun onAdClosed(unit: org.prebid.mobile.api.rendering.RewardedAdUnit) {
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdClosed")) {}
            }
            override fun onAdClicked(unit: org.prebid.mobile.api.rendering.RewardedAdUnit) {
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdClicked")) {}
            }
            override fun onAdExpired(unit: org.prebid.mobile.api.rendering.RewardedAdUnit) {
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdExpired")) {}
            }
            override fun onUserEarnedReward(unit: org.prebid.mobile.api.rendering.RewardedAdUnit, reward: org.prebid.mobile.rendering.interstitial.rewarded.Reward?) {
                flutterApi.onAdEvent(AdEvent(
                    adId = adId,
                    eventName = "onUserEarnedReward",
                    reward = RewardData(
                        type = reward?.type ?: "reward",
                        count = reward?.count?.toLong() ?: 1,
                        ext = reward?.ext?.toMap(),
                    )
                )) {}
            }
        })

        rewardedAds[adId] = adUnit
        adUnit.loadAd()
    }

    override fun show(adId: Long) {
        val adUnit = rewardedAds[adId]
        if (adUnit == null || !adUnit.isLoaded) {
            return plugin.sendAdFailed(adId, PrebidMobileFlutterPlugin.NOT_READY)
        }
        adUnit.show()
    }

    override fun destroy(adId: Long) {
        rewardedAds.remove(adId)?.destroy()
    }

    /// Destroys every rewarded unit and returns their ad ids.
    fun destroyAll(): List<Long> {
        val ids = rewardedAds.keys.toList()
        ids.forEach { rewardedAds.remove(it)?.destroy() }
        return ids
    }
}

// =========================================================================
// NativeAdHostApi — separate class to avoid destroy() signature conflict
// =========================================================================

class NativeAdHostApiImpl(
    private val flutterApi: AdFlutterApi
) : NativeAdHostApi {

    private val nativeAds = mutableMapOf<Long, org.prebid.mobile.NativeAdUnit>()

    override fun loadAd(adId: Long, config: NativeAdRequestConfig) {
        destroy(adId)
        val nativeAdUnit = org.prebid.mobile.NativeAdUnit(config.configId)

        // Set context
        config.context?.let {
            nativeAdUnit.setContextType(org.prebid.mobile.NativeAdUnit.CONTEXT_TYPE.values().firstOrNull { ct -> ct.id == it.toInt() })
        }
        config.contextSubType?.let {
            nativeAdUnit.setContextSubType(org.prebid.mobile.NativeAdUnit.CONTEXTSUBTYPE.values().firstOrNull { st -> st.id == it.toInt() })
        }
        config.placementType?.let {
            nativeAdUnit.setPlacementType(org.prebid.mobile.NativeAdUnit.PLACEMENTTYPE.values().firstOrNull { pt -> pt.id == it.toInt() })
        }
        config.placementCount?.let { nativeAdUnit.setPlacementCount(it.toInt()) }
        config.pbAdSlot?.let { nativeAdUnit.setPbAdSlot(it) }
        config.gpid?.let { nativeAdUnit.setGpid(it) }
        config.impOrtbConfig?.let { nativeAdUnit.setImpOrtbConfig(it) }

        // Configure assets
        config.assets?.filterNotNull()?.forEach { assetConfig ->
            when (assetConfig.assetType) {
                "title" -> {
                    val titleAsset = org.prebid.mobile.NativeTitleAsset()
                    titleAsset.setLength(assetConfig.titleLength?.toInt() ?: 90)
                    titleAsset.isRequired = assetConfig.required_
                    nativeAdUnit.addAsset(titleAsset)
                }
                "image" -> {
                    val imageAsset = org.prebid.mobile.NativeImageAsset(
                        assetConfig.imageWidthMin?.toInt() ?: 0,
                        assetConfig.imageHeightMin?.toInt() ?: 0,
                        assetConfig.imageWidth?.toInt() ?: 0,
                        assetConfig.imageHeight?.toInt() ?: 0
                    )
                    assetConfig.imageType?.let { imageAsset.imageType = org.prebid.mobile.NativeImageAsset.IMAGE_TYPE.values().firstOrNull { t -> t.id == it.toInt() } }
                    imageAsset.isRequired = assetConfig.required_
                    nativeAdUnit.addAsset(imageAsset)
                }
                "data" -> {
                    val dataAsset = org.prebid.mobile.NativeDataAsset()
                    assetConfig.dataType?.let { dataAsset.dataType = org.prebid.mobile.NativeDataAsset.DATA_TYPE.values().firstOrNull { d -> d.id == it.toInt() } }
                    assetConfig.dataLength?.let { dataAsset.setLen(it.toInt()) }
                    dataAsset.isRequired = assetConfig.required_
                    nativeAdUnit.addAsset(dataAsset)
                }
            }
        }

        // Configure event trackers
        config.eventTrackers?.filterNotNull()?.forEach { trackerConfig ->
            val methods = ArrayList<org.prebid.mobile.NativeEventTracker.EVENT_TRACKING_METHOD>()
            trackerConfig.methods.forEach { methodValue ->
                org.prebid.mobile.NativeEventTracker.EVENT_TRACKING_METHOD.values()
                    .firstOrNull { it.id == methodValue.toInt() }
                    ?.let { methods.add(it) }
            }
            val eventType = org.prebid.mobile.NativeEventTracker.EVENT_TYPE.values()
                .firstOrNull { it.id == trackerConfig.eventType.toInt() }
            if (eventType != null) {
                nativeAdUnit.addEventTracker(org.prebid.mobile.NativeEventTracker(eventType, methods))
            }
        }

        nativeAds[adId] = nativeAdUnit

        nativeAdUnit.fetchDemand { bidInfo ->
            if (bidInfo.dartResultCode() == "prebidDemandFetchSuccess") {
                val cacheId = bidInfo.nativeCacheId
                if (cacheId != null) {
                    val nativeAd = org.prebid.mobile.PrebidNativeAd.create(cacheId)
                    if (nativeAd != null) {
                        NativeAdStore.ads[adId] = nativeAd
                        val nativeData = NativeAdData(
                            title = nativeAd.title,
                            text = nativeAd.description,
                            iconUrl = nativeAd.iconUrl,
                            imageUrl = nativeAd.imageUrl,
                            sponsoredBy = nativeAd.sponsoredBy,
                            callToAction = nativeAd.callToAction,
                            clickUrl = nativeAd.clickUrl,
                            privacyUrl = nativeAd.privacyUrl,
                            titles = nativeAd.titles.map { it.text },
                            images = nativeAd.images.map {
                                NativeAdImageData(type = it.typeNumber.toLong(), url = it.url)
                            },
                            dataAssets = nativeAd.dataList.map {
                                NativeAdDataAssetData(type = it.typeNumber.toLong(), value = it.value)
                            },
                        )
                        flutterApi.onAdEvent(AdEvent(
                            adId = adId, eventName = "onAdLoaded", nativeAd = nativeData
                        )) {}
                        return@fetchDemand
                    }
                }
                flutterApi.onAdEvent(AdEvent(
                    adId = adId, eventName = "onAdFailed",
                    error = "Failed to parse native ad"
                )) {}
            } else {
                flutterApi.onAdEvent(AdEvent(
                    adId = adId, eventName = "onAdFailed",
                    error = bidInfo.dartResultCode()
                )) {}
            }
        }
    }

    override fun destroy(adId: Long) {
        nativeAds.remove(adId)?.destroy()
        NativeAdStore.remove(adId)
    }
}


// Multiformat ad handler
class MultiformatAdHostApiImpl(
    private val flutterApi: MultiformatFlutterApi,
    private val plugin: PrebidMobileFlutterPlugin,
) : MultiformatAdHostApi {

    private val adUnits = mutableMapOf<Long, org.prebid.mobile.api.original.PrebidAdUnit>()
    private val refreshSeconds = mutableMapOf<Long, Int>()
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

    override fun fetchDemand(
        adId: Long,
        config: MultiformatAdRequestConfig,
        callback: (Result<MultiformatBidResult>) -> Unit
    ) {
        cancelRefresh(adId)
        adUnits.remove(adId)?.destroy()
        val adUnit = org.prebid.mobile.api.original.PrebidAdUnit(config.configId)
        adUnits[adId] = adUnit
        // Must be set before the auction: Prebid starts the tracker when the
        // ad server's interstitial shows the Prebid creative.
        if (config.trackInterstitialImpression) adUnit.activateInterstitialPrebidImpressionTracker(true)

        // Build PrebidRequest using setters
        val request = org.prebid.mobile.api.original.PrebidRequest()
        config.gpid?.let { request.setGpid(it) }

        if (config.bannerSizes != null && config.bannerSizes.isNotEmpty()) {
            val params = org.prebid.mobile.BannerParameters()
            val sizes = mutableSetOf<org.prebid.mobile.AdSize>()
            val sizeList = config.bannerSizes.filterNotNull()
            var i = 0
            while (i + 1 < sizeList.size) {
                sizes.add(org.prebid.mobile.AdSize(sizeList[i].toInt(), sizeList[i + 1].toInt()))
                i += 2
            }
            params.adSizes = sizes
            request.setBannerParameters(params)
        }

        config.videoConfig?.let { request.setVideoParameters(it.toVideoParameters()) }

        // Build native params if provided
        config.nativeConfig?.let { nc ->
            val assets = mutableListOf<org.prebid.mobile.NativeAsset>()
            nc.assets?.filterNotNull()?.forEach { ac ->
                when (ac.assetType) {
                    "title" -> {
                        val a = org.prebid.mobile.NativeTitleAsset()
                        a.setLength(ac.titleLength?.toInt() ?: 90)
                        a.isRequired = ac.required_
                        assets.add(a)
                    }
                    "image" -> {
                        val a = org.prebid.mobile.NativeImageAsset(
                            ac.imageWidthMin?.toInt() ?: 0,
                            ac.imageHeightMin?.toInt() ?: 0,
                            ac.imageWidth?.toInt() ?: 0,
                            ac.imageHeight?.toInt() ?: 0
                        )
                        ac.imageType?.let { a.imageType = org.prebid.mobile.NativeImageAsset.IMAGE_TYPE.values().firstOrNull { t -> t.id == it.toInt() } }
                        a.isRequired = ac.required_
                        assets.add(a)
                    }
                    "data" -> {
                        val a = org.prebid.mobile.NativeDataAsset()
                        ac.dataType?.let { a.dataType = org.prebid.mobile.NativeDataAsset.DATA_TYPE.values().firstOrNull { d -> d.id == it.toInt() } }
                        ac.dataLength?.let { a.setLen(it.toInt()) }
                        a.isRequired = ac.required_
                        assets.add(a)
                    }
                }
            }
            val params = org.prebid.mobile.NativeParameters(assets)
            nc.context?.let { v ->
                org.prebid.mobile.NativeAdUnit.CONTEXT_TYPE.values().firstOrNull { it.id == v.toInt() }
                    ?.let { params.setContextType(it) }
            }
            nc.contextSubType?.let { v ->
                org.prebid.mobile.NativeAdUnit.CONTEXTSUBTYPE.values().firstOrNull { it.id == v.toInt() }
                    ?.let { params.setContextSubType(it) }
            }
            nc.placementType?.let { v ->
                org.prebid.mobile.NativeAdUnit.PLACEMENTTYPE.values().firstOrNull { it.id == v.toInt() }
                    ?.let { params.setPlacementType(it) }
            }

            // Event trackers
            nc.eventTrackers?.filterNotNull()?.forEach { tc ->
                val methods = ArrayList<org.prebid.mobile.NativeEventTracker.EVENT_TRACKING_METHOD>()
                tc.methods.forEach { m ->
                    org.prebid.mobile.NativeEventTracker.EVENT_TRACKING_METHOD.values()
                        .firstOrNull { it.id == m.toInt() }?.let { methods.add(it) }
                }
                val eventType = org.prebid.mobile.NativeEventTracker.EVENT_TYPE.values()
                    .firstOrNull { it.id == tc.eventType.toInt() }
                if (eventType != null) {
                    params.addEventTracker(org.prebid.mobile.NativeEventTracker(eventType, methods))
                }
            }
            request.setNativeParameters(params)
        }

        request.setInterstitial(config.isInterstitial)
        request.setRewarded(config.isRewarded)

        config.adPosition?.let { pos ->
            org.prebid.mobile.rendering.models.AdPosition.values().firstOrNull { it.value == pos.toInt() }
                ?.let { request.setAdPosition(it) }
        }

        requests[adId] = request
        adUnit.fetchDemand(request) { bidInfo ->
            val result = bidInfo.toMultiformatResult()
            mainHandler.post {
                callback(Result.success(result))
                scheduleRefresh(adId)
            }
        }
    }

    // Auto-refresh. Prebid Android 3.4's PrebidAdUnit can't refresh: it
    // rebuilds its inner ad unit (interval 0, no refresh listener) on every
    // fetchDemand. So the plugin re-runs the same request on a timer and
    // sends each result to Dart as an event.
    private val requests = mutableMapOf<Long, org.prebid.mobile.api.original.PrebidRequest>()
    private val refreshTasks = mutableMapOf<Long, Runnable>()

    private fun scheduleRefresh(adId: Long) {
        cancelRefresh(adId)
        val seconds = refreshSeconds[adId] ?: return
        if (requests[adId] == null) return
        val task = object : Runnable {
            override fun run() {
                val adUnit = adUnits[adId] ?: return
                val request = requests[adId] ?: return
                adUnit.fetchDemand(request) { bidInfo ->
                    val result = bidInfo.toMultiformatResult()
                    mainHandler.post {
                        if (adUnits[adId] === adUnit) flutterApi.onDemandRefreshed(adId, result) {}
                    }
                }
                mainHandler.postDelayed(this, seconds * 1000L)
            }
        }
        refreshTasks[adId] = task
        mainHandler.postDelayed(task, seconds * 1000L)
    }

    private fun cancelRefresh(adId: Long) {
        refreshTasks.remove(adId)?.let { mainHandler.removeCallbacks(it) }
    }

    override fun setAutoRefreshInterval(adId: Long, seconds: Long) {
        // Same bounds as Prebid's auto-refresh.
        refreshSeconds[adId] = seconds.toInt().coerceIn(30, 120)
        if (refreshTasks.containsKey(adId)) scheduleRefresh(adId)
    }

    override fun stopAutoRefresh(adId: Long) {
        cancelRefresh(adId)
    }

    override fun resumeAutoRefresh(adId: Long) {
        if (!refreshTasks.containsKey(adId)) scheduleRefresh(adId)
    }

    override fun activateBannerImpressionTracker(adId: Long): Boolean {
        val adUnit = adUnits[adId] ?: return false
        val root = plugin.getActivity()?.window?.decorView ?: return false
        val banner = findGmaBannerViews(root).singleOrNull() ?: return false
        adUnit.activatePrebidImpressionTracker(banner)
        return true
    }

    override fun destroy(adId: Long) {
        cancelRefresh(adId)
        refreshSeconds.remove(adId)
        requests.remove(adId)
        adUnits.remove(adId)?.destroy()
    }

    private fun org.prebid.mobile.api.data.BidInfo.toMultiformatResult() = MultiformatBidResult(
        resultCode = dartResultCode(),
        winningFormat = targetingKeywords?.get("hb_format"),
        targetingKeywords = targetingKeywords?.mapKeys { it.key } ?: emptyMap(),
        nativeAdCacheId = nativeCacheId,
        exp = exp?.toDouble(),
        topBidFiltered = isTopBidFiltered,
    )

    /// Google Mobile Ads banner views (AdView / AdManagerAdView) in [view]'s
    /// tree, found by class name so the core plugin needn't depend on GMA.
    private fun findGmaBannerViews(view: android.view.View): List<android.view.View> {
        var type: Class<*>? = view.javaClass
        while (type != null) {
            if (type.name == "com.google.android.gms.ads.BaseAdView") return listOf(view)
            type = type.superclass
        }
        if (view !is android.view.ViewGroup) return emptyList()
        return (0 until view.childCount).flatMap { findGmaBannerViews(view.getChildAt(it)) }
    }
}

// In-stream video ad handler
class InstreamVideoAdHostApiImpl : InstreamVideoAdHostApi {

    private val adUnits = mutableMapOf<Long, org.prebid.mobile.InStreamVideoAdUnit>()

    override fun fetchDemand(
        adId: Long,
        config: InstreamVideoAdRequestConfig,
        callback: (Result<MultiformatBidResult>) -> Unit
    ) {
        val adUnit = org.prebid.mobile.InStreamVideoAdUnit(
            config.configId,
            config.width.toInt(),
            config.height.toInt()
        )
        config.videoConfig?.let { adUnit.videoParameters = it.toVideoParameters() }
        adUnits[adId] = adUnit

        adUnit.fetchDemand { bidInfo ->
            val resultStr = bidInfo.dartResultCode()
            callback(Result.success(MultiformatBidResult(
                resultCode = resultStr,
                winningFormat = "video",
                targetingKeywords = bidInfo.targetingKeywords?.mapKeys { it.key } ?: emptyMap(),
                exp = bidInfo.exp?.toDouble(),
            )))
        }
    }

    override fun destroy(adId: Long) {
        adUnits.remove(adId)
    }
}

/// Maps an Android [org.prebid.mobile.ResultCode] to the result-code names the
/// Dart API uses (the iOS `ResultCode` case names), so both platforms report
/// the same strings and `isSuccess` works everywhere.
internal fun org.prebid.mobile.ResultCode.toDartCode(): String = when (this) {
    org.prebid.mobile.ResultCode.SUCCESS -> "prebidDemandFetchSuccess"
    org.prebid.mobile.ResultCode.INVALID_ACCOUNT_ID -> "prebidInvalidAccountId"
    org.prebid.mobile.ResultCode.INVALID_CONFIG_ID -> "prebidInvalidConfigId"
    org.prebid.mobile.ResultCode.INVALID_SIZE -> "prebidInvalidSize"
    org.prebid.mobile.ResultCode.INVALID_HOST_URL -> "prebidServerURLInvalid"
    org.prebid.mobile.ResultCode.NETWORK_ERROR -> "prebidNetworkError"
    org.prebid.mobile.ResultCode.PREBID_SERVER_ERROR -> "prebidServerError"
    org.prebid.mobile.ResultCode.NO_BIDS -> "prebidDemandNoBids"
    org.prebid.mobile.ResultCode.NO_CACHED_BIDS -> "prebidDemandNoCachedBids"
    org.prebid.mobile.ResultCode.TIMEOUT -> "prebidDemandTimedOut"
    else -> "prebidInvalidRequest"
}

/// Result code for a fetchDemand [org.prebid.mobile.api.data.BidInfo].
/// Prebid Android's Original API reports SUCCESS even for an empty seatbid
/// (no winning bid); iOS reports no-bids. Treat SUCCESS without targeting
/// keywords as no-bids so both platforms agree.
internal fun org.prebid.mobile.api.data.BidInfo.dartResultCode(): String =
    if (resultCode == org.prebid.mobile.ResultCode.SUCCESS && targetingKeywords.isNullOrEmpty()) {
        "prebidDemandNoBids"
    } else {
        resultCode.toDartCode()
    }

/// Builds Prebid video parameters from the Pigeon config.
internal fun VideoParametersConfig.toVideoParameters(): org.prebid.mobile.VideoParameters {
    val vp = org.prebid.mobile.VideoParameters(mimes)
    protocols?.filterNotNull()?.let { list ->
        vp.protocols = list.map { org.prebid.mobile.Signals.Protocols(it.toInt()) }
    }
    playbackMethods?.filterNotNull()?.let { list ->
        vp.playbackMethod = list.map { org.prebid.mobile.Signals.PlaybackMethod(it.toInt()) }
    }
    placement?.let { vp.placement = org.prebid.mobile.Signals.Placement(it.toInt()) }
    plcmt?.let { vp.plcmt = org.prebid.mobile.Signals.Plcmt(it.toInt()) }
    api?.filterNotNull()?.let { list ->
        vp.api = list.map { org.prebid.mobile.Signals.Api(it.toInt()) }
    }
    maxDuration?.let { vp.maxDuration = it.toInt() }
    minDuration?.let { vp.minDuration = it.toInt() }
    startDelay?.let { vp.startDelay = org.prebid.mobile.Signals.StartDelay(it.toInt()) }
    linearity?.let { vp.linearity = it.toInt() }
    skippable?.let { vp.skippable = it }
    battr?.filterNotNull()?.let { list ->
        vp.battr = list.map { org.prebid.mobile.Signals.CreativeAttribute(it.toInt()) }
    }
    minBitrate?.let { vp.minBitrate = it.toInt() }
    maxBitrate?.let { vp.maxBitrate = it.toInt() }
    return vp
}

/// Applies fullscreen controls to a rendering interstitial / rewarded ad unit.
internal fun FullscreenControlsConfig.applyTo(adUnit: org.prebid.mobile.api.rendering.BaseInterstitialAdUnit) {
    closeButtonArea?.let { adUnit.setCloseButtonArea(it) }
    closeButtonPosition?.toPrebidPosition()?.let { adUnit.setCloseButtonPosition(it) }
    skipButtonArea?.let { adUnit.setSkipButtonArea(it) }
    skipButtonPosition?.toPrebidPosition()?.let { adUnit.setSkipButtonPosition(it) }
    skipDelay?.let { adUnit.setSkipDelay(it.toInt()) }
    isMuted?.let { adUnit.setIsMuted(it) }
    isSoundButtonVisible?.let { adUnit.setIsSoundButtonVisible(it) }
    // isAutoCloseOnCompletionEnabled, supportSKOverlay: iOS only.
}

internal fun String.toPrebidPosition(): org.prebid.mobile.api.data.Position? = when (this) {
    "topLeft" -> org.prebid.mobile.api.data.Position.TOP_LEFT
    "topRight" -> org.prebid.mobile.api.data.Position.TOP_RIGHT
    else -> null
}

/// JSONObject -> Map for the Pigeon codec (nested objects / arrays included).
internal fun org.json.JSONObject.toMap(): Map<String?, Any?> =
    keys().asSequence().associateWith { key -> opt(key).toPigeonValue() }

private fun Any?.toPigeonValue(): Any? = when (this) {
    org.json.JSONObject.NULL, null -> null
    is org.json.JSONObject -> toMap()
    is org.json.JSONArray -> (0 until length()).map { opt(it).toPigeonValue() }
    else -> this
}
