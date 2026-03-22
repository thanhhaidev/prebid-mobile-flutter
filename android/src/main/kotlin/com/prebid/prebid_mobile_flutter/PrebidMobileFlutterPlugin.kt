package com.prebid.prebid_mobile_flutter

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

    fun getActivity(): Activity? = activity

    private val interstitialAds = mutableMapOf<Long, org.prebid.mobile.api.rendering.InterstitialAdUnit>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        flutterApi = AdFlutterApi(binding.binaryMessenger)

        // Register Pigeon APIs
        PrebidMobileHostApi.setUp(binding.binaryMessenger, this)
        TargetingHostApi.setUp(binding.binaryMessenger, this)
        InterstitialAdHostApi.setUp(binding.binaryMessenger, this)
        RewardedAdHostApi.setUp(binding.binaryMessenger, RewardedAdHostApiImpl(flutterApi, this))
        NativeAdHostApi.setUp(binding.binaryMessenger, NativeAdHostApiImpl(flutterApi))

        // Register multiformat handler as separate class
        MultiformatAdHostApi.setUp(binding.binaryMessenger, MultiformatAdHostApiImpl(flutterApi))
        InstreamVideoAdHostApi.setUp(binding.binaryMessenger, InstreamVideoAdHostApiImpl())

        // Register the BannerAd PlatformView factory
        binding.platformViewRegistry.registerViewFactory(
            "prebid_mobile_flutter/banner_ad",
            BannerAdViewFactory(binding.binaryMessenger)
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
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }
    override fun onDetachedFromActivity() { activity = null }

    // =========================================================================
    // PrebidMobileHostApi
    // =========================================================================

    override fun initializeSdk(
        prebidServerUrl: String,
        accountId: String,
        callback: (Result<com.prebid.prebid_mobile_flutter.InitializationResult>) -> Unit
    ) {
        PrebidMobile.setPrebidServerAccountId(accountId)
        PrebidMobile.initializeSdk(context, prebidServerUrl) { status ->
            val statusStr = when (status) {
                InitializationStatus.SUCCEEDED -> "succeeded"
                InitializationStatus.SERVER_STATUS_WARNING -> "serverStatusWarning"
                else -> "failed"
            }
            val result = com.prebid.prebid_mobile_flutter.InitializationResult(
                status = statusStr,
                error = status.description
            )
            activity?.runOnUiThread {
                callback(Result.success(result))
            } ?: callback(Result.success(result))
        }
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
        PrebidMobile.setStoredAuctionResponse("")
    }

    override fun addStoredBidResponse(bidder: String, responseId: String) {
        PrebidMobile.addStoredBidResponse(bidder, responseId)
    }

    override fun clearStoredBidResponses() {
        PrebidMobile.clearStoredBidResponses()
    }

    override fun setLogLevel(level: Long) {
        val logLevel = when (level.toInt()) {
            0 -> PrebidMobile.LogLevel.DEBUG
            2 -> PrebidMobile.LogLevel.INFO
            3 -> PrebidMobile.LogLevel.WARN
            4 -> PrebidMobile.LogLevel.ERROR
            5 -> PrebidMobile.LogLevel.NONE
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

    // External User IDs
    override fun setExternalUserIds(userIds: List<ExternalUserIdData>) {
        val ids = userIds.map { data ->
            val uniqueId = ExternalUserId.UniqueId(data.identifier, data.atype?.toInt() ?: 0)
            data.ext?.let { ext ->
                val extMap = HashMap<String, Any>()
                ext.forEach { (k, v) -> if (k != null && v != null) extMap[k] = v }
                uniqueId.setExt(extMap)
            }
            ExternalUserId(data.source, listOf(uniqueId))
        }
        TargetingParams.setExternalUserIds(ArrayList(ids))
    }

    override fun getExternalUserIds(): List<ExternalUserIdData> {
        val ids = TargetingParams.getExternalUserIds() ?: return emptyList()
        return ids.flatMap { uid ->
            val source = uid.source ?: ""
            uid.uids?.map { uniqueId ->
                ExternalUserIdData(
                    source = source,
                    identifier = uniqueId.id ?: "",
                    atype = uniqueId.atype?.toLong()
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
    override fun getDeviceAccessConsent(): Boolean? = TargetingParams.getDeviceAccessConsent()

    // US Privacy / CCPA
    override fun setUSPrivacyString(value: String?) {
        // Android SDK reads IABUSPrivacy_String from SharedPreferences, but we can store it
        val prefs = context.getSharedPreferences("SharedPreferences", Context.MODE_PRIVATE)
        if (value != null) {
            prefs.edit().putString("IABUSPrivacy_String", value).apply()
        } else {
            prefs.edit().remove("IABUSPrivacy_String").apply()
        }
    }
    override fun getUSPrivacyString(): String? {
        val prefs = context.getSharedPreferences("SharedPreferences", Context.MODE_PRIVATE)
        return prefs.getString("IABUSPrivacy_String", null)
    }

    override fun addUserKeyword(keyword: String) { TargetingParams.addUserKeyword(keyword) }
    override fun addUserKeywords(keywords: List<String>) { keywords.forEach { TargetingParams.addUserKeyword(it) } }
    override fun removeUserKeyword(keyword: String) { TargetingParams.removeUserKeyword(keyword) }
    override fun clearUserKeywords() { TargetingParams.clearUserKeywords() }
    override fun getUserKeywords(): List<String> {
        val kw = TargetingParams.getUserKeywords()
        return if (kw.isNullOrEmpty()) emptyList() else kw.split(",").map { it.trim() }
    }

    // Android SDK doesn't have separate App keyword APIs; use user keywords as fallback
    override fun addAppKeyword(keyword: String) { TargetingParams.addUserKeyword(keyword) }
    override fun addAppKeywords(keywords: List<String>) { keywords.forEach { TargetingParams.addUserKeyword(it) } }
    override fun removeAppKeyword(keyword: String) { TargetingParams.removeUserKeyword(keyword) }
    override fun clearAppKeywords() { /* no separate app keywords on Android */ }

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

    // User Ext Data (user.ext.data) — Android SDK does not have direct user data methods,
    // so we use a stored map and merge into global ORTB config.
    private val userExtDataMap = mutableMapOf<String, MutableSet<String>>()

    override fun addUserExtData(key: String, value: String) {
        userExtDataMap.getOrPut(key) { mutableSetOf() }.add(value)
        syncUserExtDataToOrtb()
    }
    override fun updateUserExtData(key: String, value: List<String>) {
        userExtDataMap[key] = value.toMutableSet()
        syncUserExtDataToOrtb()
    }
    override fun removeUserExtData(key: String) {
        userExtDataMap.remove(key)
        syncUserExtDataToOrtb()
    }
    override fun clearUserExtData() {
        userExtDataMap.clear()
        syncUserExtDataToOrtb()
    }

    private fun syncUserExtDataToOrtb() {
        try {
            if (userExtDataMap.isEmpty()) return
            val dataObj = org.json.JSONObject()
            userExtDataMap.forEach { (k, v) -> dataObj.put(k, org.json.JSONArray(v.toList())) }
            val userObj = org.json.JSONObject().put("ext", org.json.JSONObject().put("data", dataObj))
            val ortb = org.json.JSONObject().put("user", userObj)
            TargetingParams.setGlobalOrtbConfig(ortb.toString())
        } catch (_: Exception) {}
    }

    override fun addBidderToAccessControlList(bidderName: String) { TargetingParams.addBidderToAccessControlList(bidderName) }
    override fun removeBidderFromAccessControlList(bidderName: String) { TargetingParams.removeBidderFromAccessControlList(bidderName) }
    override fun clearAccessControlList() { TargetingParams.clearAccessControlList() }

    override fun setGlobalOrtbConfig(ortbConfig: String?) { TargetingParams.setGlobalOrtbConfig(ortbConfig) }
    override fun getGlobalOrtbConfig(): String? = TargetingParams.getGlobalOrtbConfig()

    override fun setContentUrl(url: String?) {
        // contentUrl not directly available on Android; use global ORTB config
    }
    override fun setPublisherName(name: String?) { TargetingParams.setPublisherName(name) }
    override fun setStoreUrl(url: String?) { TargetingParams.setStoreUrl(url) }
    override fun setDomain(domain: String?) { TargetingParams.setDomain(domain) }

    // =========================================================================
    // InterstitialAdHostApi
    // =========================================================================

    override fun loadAd(adId: Long, configId: String, adFormats: List<String>?, videoConfig: VideoParametersConfig?) {
        val act = activity ?: return

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

        // Apply video parameters if provided
        if (videoConfig != null && formats.contains(org.prebid.mobile.api.data.AdUnitFormat.VIDEO)) {
            try {
                val vp = org.prebid.mobile.VideoParameters(videoConfig.mimes)
                videoConfig.protocols?.filterNotNull()?.map { it.toInt() }?.let { protocols ->
                    vp.protocols = protocols.mapNotNull { org.prebid.mobile.Signals.Protocols(it) }
                }
                videoConfig.playbackMethods?.filterNotNull()?.map { it.toInt() }?.let { methods ->
                    vp.playbackMethod = methods.mapNotNull { org.prebid.mobile.Signals.PlaybackMethod(it) }
                }
                videoConfig.placement?.let { vp.placement = org.prebid.mobile.Signals.Placement(it.toInt()) }
                videoConfig.maxDuration?.let { vp.maxDuration = it.toInt() }
                videoConfig.minDuration?.let { vp.minDuration = it.toInt() }
                adUnit.setVideoParameters(vp)
            } catch (_: Exception) {}
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
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdDismissed")) {}
            }
            override fun onAdClicked(unit: org.prebid.mobile.api.rendering.InterstitialAdUnit) {
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdClicked")) {}
            }
        })

        interstitialAds[adId] = adUnit
        adUnit.loadAd()
    }

    override fun show(adId: Long) {
        interstitialAds[adId]?.show()
    }

    override fun destroy(adId: Long) {
        interstitialAds.remove(adId)?.destroy()
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

    override fun loadAd(adId: Long, configId: String) {
        val act = plugin.getActivity() ?: return
        val adUnit = org.prebid.mobile.api.rendering.RewardedAdUnit(act, configId)

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
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdDismissed")) {}
            }
            override fun onAdClicked(unit: org.prebid.mobile.api.rendering.RewardedAdUnit) {
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdClicked")) {}
            }
            override fun onUserEarnedReward(unit: org.prebid.mobile.api.rendering.RewardedAdUnit, reward: org.prebid.mobile.rendering.interstitial.rewarded.Reward?) {
                flutterApi.onAdEvent(AdEvent(
                    adId = adId,
                    eventName = "onUserEarnedReward",
                    reward = RewardData(type = reward?.type ?: "reward", count = reward?.count?.toLong() ?: 1)
                )) {}
            }
        })

        rewardedAds[adId] = adUnit
        adUnit.loadAd()
    }

    override fun show(adId: Long) {
        rewardedAds[adId]?.show()
    }

    override fun destroy(adId: Long) {
        rewardedAds.remove(adId)?.destroy()
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
        val nativeAdUnit = org.prebid.mobile.NativeAdUnit(config.configId)

        // Set context
        config.context?.let {
            nativeAdUnit.setContextType(org.prebid.mobile.NativeAdUnit.CONTEXT_TYPE.values().firstOrNull { ct -> ct.id == it.toInt() })
        }
        config.placementType?.let {
            nativeAdUnit.setPlacementType(org.prebid.mobile.NativeAdUnit.PLACEMENTTYPE.values().firstOrNull { pt -> pt.id == it.toInt() })
        }
        config.placementCount?.let { nativeAdUnit.setPlacementCount(it.toInt()) }

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
            if (bidInfo.resultCode == org.prebid.mobile.ResultCode.SUCCESS) {
                val cacheId = bidInfo.nativeCacheId
                if (cacheId != null) {
                    val nativeAd = org.prebid.mobile.PrebidNativeAd.create(cacheId)
                    if (nativeAd != null) {
                        val nativeData = NativeAdData(
                            title = nativeAd.title,
                            text = nativeAd.description,
                            iconUrl = nativeAd.iconUrl,
                            imageUrl = nativeAd.imageUrl,
                            sponsoredBy = nativeAd.sponsoredBy,
                            callToAction = nativeAd.callToAction,
                            clickUrl = nativeAd.clickUrl
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
                    error = bidInfo.resultCode.name
                )) {}
            }
        }
    }

    override fun trackImpression(adId: Long) {
        // Impression tracking handled automatically by native SDK
    }

    override fun trackClick(adId: Long) {
        // Click tracking handled automatically by native SDK
    }

    override fun destroy(adId: Long) {
        nativeAds.remove(adId)
    }
}


// Multiformat ad handler
class MultiformatAdHostApiImpl(
    private val flutterApi: AdFlutterApi
) : MultiformatAdHostApi {

    private val adUnits = mutableMapOf<Long, org.prebid.mobile.api.original.PrebidAdUnit>()

    override fun fetchDemand(
        adId: Long,
        config: MultiformatAdRequestConfig,
        callback: (Result<MultiformatBidResult>) -> Unit
    ) {
        val adUnit = org.prebid.mobile.api.original.PrebidAdUnit(config.configId)
        adUnits[adId] = adUnit

        // Build PrebidRequest using setters
        val request = org.prebid.mobile.api.original.PrebidRequest()

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

        if (config.videoConfig != null) {
            val vc = config.videoConfig
            val vp = org.prebid.mobile.VideoParameters(vc.mimes)
            vc.protocols?.filterNotNull()?.map { it.toInt() }?.let { protocols ->
                vp.protocols = protocols.mapNotNull { org.prebid.mobile.Signals.Protocols(it) }
            }
            vc.playbackMethods?.filterNotNull()?.map { it.toInt() }?.let { methods ->
                vp.playbackMethod = methods.mapNotNull { org.prebid.mobile.Signals.PlaybackMethod(it) }
            }
            vc.placement?.let { vp.placement = org.prebid.mobile.Signals.Placement(it.toInt()) }
            vc.maxDuration?.let { vp.maxDuration = it.toInt() }
            vc.minDuration?.let { vp.minDuration = it.toInt() }
            request.setVideoParameters(vp)
        }

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

        adUnit.fetchDemand(request) { bidInfo ->
            val resultStr = bidInfo.resultCode.name
            val format = bidInfo.targetingKeywords?.get("hb_format")
            callback(Result.success(MultiformatBidResult(
                resultCode = resultStr,
                winningFormat = format,
                targetingKeywords = bidInfo.targetingKeywords?.mapKeys { it.key } ?: emptyMap(),
                nativeAdCacheId = bidInfo.nativeCacheId
            )))
        }
    }

    override fun destroy(adId: Long) {
        adUnits.remove(adId)
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
        adUnits[adId] = adUnit

        adUnit.fetchDemand { bidInfo ->
            val resultStr = bidInfo.resultCode.name
            callback(Result.success(MultiformatBidResult(
                resultCode = resultStr,
                winningFormat = "video",
                targetingKeywords = bidInfo.targetingKeywords?.mapKeys { it.key } ?: emptyMap()
            )))
        }
    }

    override fun destroy(adId: Long) {
        adUnits.remove(adId)
    }
}
