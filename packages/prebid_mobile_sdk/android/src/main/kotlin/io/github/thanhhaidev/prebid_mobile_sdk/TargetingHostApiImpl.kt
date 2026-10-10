package io.github.thanhhaidev.prebid_mobile_sdk

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import org.prebid.mobile.TargetingParams
import org.prebid.mobile.rendering.utils.helpers.AppInfoManager

/** TargetingHostApi: privacy signals, keywords, ext data and app info. */
internal class TargetingHostApiImpl(private val context: Context) : TargetingHostApi {

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

    // Prebid's rule (UserConsentManager.canAccessDeviceData, not public API):
    // without a device-access answer, allowed unless GDPR applies.
    override fun isAllowedAccessDeviceData(): Boolean =
        TargetingParams.getDeviceAccessConsent() ?: (TargetingParams.isSubjectToGDPR() != true)

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
    override fun getUSPrivacyString(): String? = defaultPreferences().getString("IABUSPrivacy_String", null)

    // Same file as the deprecated PreferenceManager.getDefaultSharedPreferences.
    private fun defaultPreferences() =
        context.getSharedPreferences("${context.packageName}_preferences", Context.MODE_PRIVATE)

    override fun addUserKeyword(keyword: String) {
        TargetingParams.addUserKeyword(keyword)
    }
    override fun addUserKeywords(keywords: List<String>) {
        keywords.forEach { TargetingParams.addUserKeyword(it) }
    }
    override fun removeUserKeyword(keyword: String) {
        TargetingParams.removeUserKeyword(keyword)
    }
    override fun clearUserKeywords() {
        TargetingParams.clearUserKeywords()
    }
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
    override fun getAppKeywords(): List<String> = emptyList()

    private fun warnAppKeywordsUnsupported() {
        Log.w(
            "PrebidFlutter",
            "App keywords are not supported by Prebid Android; " +
                "use setGlobalOrtbConfig with app.keywords instead.",
        )
    }

    override fun addAppExtData(key: String, value: String) {
        try {
            TargetingParams.addExtData(key, value)
        } catch (_: Exception) {}
    }
    override fun updateAppExtData(key: String, value: List<String>) {
        try {
            TargetingParams.updateExtData(key, HashSet(value))
        } catch (_: Exception) {}
    }
    override fun removeAppExtData(key: String) {
        try {
            TargetingParams.removeExtData(key)
        } catch (_: Exception) {}
    }
    override fun clearAppExtData() {
        try {
            TargetingParams.clearExtData()
        } catch (_: Exception) {}
    }

    // User Ext Data (user.ext.data). Tracked locally (process-wide, like the
    // TargetingParams it's written to, so engines don't wipe each other's
    // keys) and written to TargetingParams.userExt["data"], which Prebid
    // merges into user.ext — leaving the global ORTB config and any other
    // user.ext keys untouched.

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

    // The whole user.ext (setUserExt); its `data` gives way to the user ext
    // data keys when any is set. Until the first setUserExt, the keys already
    // in TargetingParams.userExt are kept.
    override fun setUserExt(json: String?) {
        userExtBase = json?.let { runCatching { JSONObject(it) }.getOrNull() } ?: JSONObject()
        syncUserExtData()
    }
    override fun getUserExt(): String? = TargetingParams.getUserExt()?.getJsonObject()?.toString()

    private fun syncUserExtData() {
        val base = userExtBase
        val ext = if (base != null) {
            org.prebid.mobile.rendering.models.openrtb.bidRequests.Ext().apply { put(base) }
        } else {
            TargetingParams.getUserExt() ?: org.prebid.mobile.rendering.models.openrtb.bidRequests.Ext()
        }
        if (base == null || userExtDataMap.isNotEmpty()) ext.remove("data")
        if (userExtDataMap.isNotEmpty()) {
            val data = JSONObject()
            userExtDataMap.forEach { (k, v) -> data.put(k, JSONArray(v.sorted())) }
            ext.put("data", data)
        }
        TargetingParams.setUserExt(if (ext.getJsonObject().length() == 0) null else ext)
    }

    override fun addBidderToAccessControlList(bidderName: String) {
        TargetingParams.addBidderToAccessControlList(bidderName)
    }
    override fun removeBidderFromAccessControlList(bidderName: String) {
        TargetingParams.removeBidderFromAccessControlList(bidderName)
    }
    override fun clearAccessControlList() {
        TargetingParams.clearAccessControlList()
    }

    override fun setGlobalOrtbConfig(ortbConfig: String?) {
        TargetingParams.setGlobalOrtbConfig(ortbConfig)
    }
    override fun getGlobalOrtbConfig(): String? = TargetingParams.getGlobalOrtbConfig()

    override fun setPublisherName(name: String?) {
        TargetingParams.setPublisherName(name)
    }
    override fun setStoreUrl(url: String?) {
        TargetingParams.setStoreUrl(url)
    }
    override fun setDomain(domain: String?) {
        TargetingParams.setDomain(domain)
    }

    override fun setAppName(name: String?) {
        appNameOverride = name
        // null: back to the application label, as Prebid's AppInfoManager.init reads it.
        AppInfoManager.setAppName(
            name ?: context.applicationInfo.loadLabel(context.packageManager).toString(),
        )
    }

    // SKAdNetwork / iTunes IDs are iOS concepts; Android reads the package name.
    override fun setSourceApp(sourceApp: String?) {}
    override fun setItunesId(itunesId: String?) {}
    override fun getSourceApp(): String? = null
    override fun getItunesId(): String? = null

    override fun setBundleName(bundleName: String?) {
        TargetingParams.setBundleName(bundleName)
    }
    override fun getBundleName(): String? = TargetingParams.getBundleName()

    override fun setOmidPartnerName(name: String?) {
        TargetingParams.setOmidPartnerName(name)
    }
    override fun setOmidPartnerVersion(version: String?) {
        TargetingParams.setOmidPartnerVersion(version)
    }

    override fun setUserLatLng(latitude: Double, longitude: Double) {
        TargetingParams.setUserLatLng(latitude.toFloat(), longitude.toFloat())
    }
    override fun clearUserLatLng() {
        TargetingParams.setUserLatLng(null, null)
    }
    override fun setLocationPrecision(precision: Long?) {
        TargetingParams.setLocationDecimalPrecision(precision?.toInt())
    }

    override fun getAppExtData(): Map<String, List<String>> =
        TargetingParams.getExtDataDictionary().orEmpty().mapValues { it.value.toList() }
    override fun getAccessControlList(): List<String> = TargetingParams.getAccessControlList().orEmpty().toList()
    override fun getPublisherName(): String? = TargetingParams.getPublisherName()
    override fun getStoreUrl(): String? = TargetingParams.getStoreUrl()
    override fun getDomain(): String? = TargetingParams.getDomain()
    override fun getOmidPartnerName(): String? = TargetingParams.getOmidPartnerName()
    override fun getOmidPartnerVersion(): String? = TargetingParams.getOmidPartnerVersion()
    override fun getSendSharedId(): Boolean = TargetingParams.getSendSharedId() == true
    override fun getUserLatLng(): List<Double>? =
        TargetingParams.getUserLatLng()?.let { listOf(it.first.toDouble(), it.second.toDouble()) }
    override fun getLocationPrecision(): Long? = TargetingParams.getLocationDecimalPrecision()?.toLong()

    internal companion object {
        private val userExtDataMap = mutableMapOf<String, MutableSet<String>>()
        private var userExtBase: JSONObject? = null

        /** Process-wide like AppInfoManager; reapplied after the first init. */
        var appNameOverride: String? = null
            private set
    }
}
