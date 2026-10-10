package io.github.thanhhaidev.prebid_mobile_sdk

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue
import org.json.JSONObject
import org.prebid.mobile.AdSize
import org.prebid.mobile.NativeAdUnit
import org.prebid.mobile.NativeDataAsset
import org.prebid.mobile.NativeEventTracker
import org.prebid.mobile.NativeTitleAsset
import org.prebid.mobile.ResultCode

internal class PigeonConversionsTest {
    @Test
    fun toDartCode_mapsResultCodesToDartNames() {
        assertEquals("prebidDemandFetchSuccess", ResultCode.SUCCESS.toDartCode())
        assertEquals("prebidDemandNoBids", ResultCode.NO_BIDS.toDartCode())
        assertEquals("prebidDemandTimedOut", ResultCode.TIMEOUT.toDartCode())
        assertEquals("prebidInvalidNativeRequest", ResultCode.INVALID_NATIVE_REQUEST.toDartCode())
        assertEquals("prebidInvalidRequest", ResultCode.INVALID_PREBID_REQUEST_OBJECT.toDartCode())
    }

    @Test
    fun toPrebidTracker_keepsKnownMethodsAndDropsUnknownTypes() {
        val tracker = NativeEventTrackerConfig(eventType = 1, methods = listOf(1, 99)).toPrebidTracker()
        assertEquals(NativeEventTracker.EVENT_TYPE.IMPRESSION, tracker?.event)
        assertEquals<List<NativeEventTracker.EVENT_TRACKING_METHOD>?>(listOf(NativeEventTracker.EVENT_TRACKING_METHOD.IMAGE), tracker?.methods?.toList())
        assertNull(NativeEventTrackerConfig(eventType = 42, methods = listOf(1)).toPrebidTracker())
    }

    @Test
    fun toPrebidAsset_sendsTheObjectAndAssetExt() {
        val json = NativeAssetConfig(
            assetType = "image",
            required_ = false,
            imageType = 3,
            imageMimes = listOf("image/png"),
            ext = """{"k":1}""",
            assetExt = """{"a":true}""",
        ).toPrebidAsset()!!.getJsonObject(1)
        assertEquals(1, json.getJSONObject("img").getJSONObject("ext").getInt("k"))
        assertEquals("image/png", json.getJSONObject("img").getJSONArray("mimes").getString(0))
        assertEquals(true, json.getJSONObject("ext").getBoolean("a"))
    }

    @Test
    fun toPrebidAsset_ignoresInvalidExt() {
        val json = NativeAssetConfig(assetType = "title", required_ = false, ext = "not json").toPrebidAsset()!!.getJsonObject(1)
        assertNull(json.getJSONObject("title").opt("ext"))
    }

    @Test
    fun toPrebidTracker_keepsTheExt() {
        val tracker = NativeEventTrackerConfig(eventType = 1, methods = listOf(1), ext = """{"t":"x"}""").toPrebidTracker()
        assertEquals("x", (tracker?.extObject as JSONObject).getString("t"))
    }

    @Test
    fun toDartCode_namesEveryOtherResultCodeLikeIos() {
        assertEquals("prebidInvalidAccountId", ResultCode.INVALID_ACCOUNT_ID.toDartCode())
        assertEquals("prebidInvalidConfigId", ResultCode.INVALID_CONFIG_ID.toDartCode())
        assertEquals("prebidInvalidSize", ResultCode.INVALID_SIZE.toDartCode())
        assertEquals("prebidServerURLInvalid", ResultCode.INVALID_HOST_URL.toDartCode())
        assertEquals("prebidNetworkError", ResultCode.NETWORK_ERROR.toDartCode())
        assertEquals("prebidServerError", ResultCode.PREBID_SERVER_ERROR.toDartCode())
        assertEquals("prebidDemandNoCachedBids", ResultCode.NO_CACHED_BIDS.toDartCode())
        assertEquals("prebidInvalidContext", ResultCode.INVALID_CONTEXT.toDartCode())
        assertEquals("prebidInvalidAdObject", ResultCode.INVALID_AD_OBJECT.toDartCode())
    }

    @Test
    fun toVideoParameters_setsEveryParameter() {
        val vp = VideoParametersConfig(
            mimes = listOf("video/mp4"),
            protocols = listOf(2, 3),
            playbackMethods = listOf(1),
            placement = 3,
            maxDuration = 30,
            minDuration = 5,
            api = listOf(1, 2),
            plcmt = 4,
            startDelay = -1,
            linearity = 1,
            skippable = true,
            battr = listOf(13),
            minBitrate = 300,
            maxBitrate = 1500,
            width = 640,
            height = 480,
        ).toVideoParameters()
        assertEquals(listOf("video/mp4"), vp.mimes)
        assertEquals(listOf(2, 3), vp.protocols?.map { it.value })
        assertEquals(listOf(1), vp.playbackMethod?.map { it.value })
        assertEquals(3, vp.placement?.value)
        assertEquals(30, vp.maxDuration)
        assertEquals(5, vp.minDuration)
        assertEquals(listOf(1, 2), vp.api?.map { it.value })
        assertEquals(4, vp.plcmt?.value)
        assertEquals(-1, vp.startDelay?.value)
        assertEquals(1, vp.linearity)
        assertEquals(true, vp.skippable)
        assertEquals(listOf(13), vp.battr?.map { it.value })
        assertEquals(300, vp.minBitrate)
        assertEquals(1500, vp.maxBitrate)
        assertEquals(AdSize(640, 480), vp.adSize)
    }

    @Test
    fun toVideoParameters_leavesAbsentParametersUnsetAndNeedsBothSizes() {
        val vp = VideoParametersConfig(mimes = listOf("video/mp4"), width = 640).toVideoParameters()
        assertNull(vp.protocols)
        assertNull(vp.placement)
        assertNull(vp.maxDuration)
        assertNull(vp.skippable)
        assertNull(vp.adSize)
    }

    @Test
    fun toPrebidAsset_titleDefaultsTo90CharactersAndKeepsRequired() {
        val title = NativeAssetConfig(assetType = "title", required_ = true).toPrebidAsset() as NativeTitleAsset
        assertEquals(90, title.len)
        assertTrue(title.isRequired)
        val short = NativeAssetConfig(assetType = "title", required_ = false, titleLength = 25).toPrebidAsset() as NativeTitleAsset
        assertEquals(25, short.len)
    }

    @Test
    fun toPrebidAsset_buildsADataAssetWithItsTypeAndLength() {
        val data = NativeAssetConfig(
            assetType = "data",
            required_ = false,
            dataType = 12,
            dataLength = 15,
            ext = """{"d":2}""",
        ).toPrebidAsset() as NativeDataAsset
        assertEquals(NativeDataAsset.DATA_TYPE.CTATEXT, data.dataType)
        assertEquals(15, data.len)
        assertEquals(2, (data.dataExt as JSONObject).getInt("d"))
    }

    @Test
    fun toPrebidAsset_isNullForAnUnknownAssetType() {
        assertNull(NativeAssetConfig(assetType = "video", required_ = true).toPrebidAsset())
    }

    // Prebid's constructor is NativeImageAsset(w, h, wmin, hmin); the
    // conversion passes (wmin, hmin, w, h), so the request swaps the sizes and
    // their minimums.
    @Test
    fun toPrebidAsset_requestsTheImageSizesAndTheirMinimums() {
        val img = NativeAssetConfig(
            assetType = "image",
            required_ = true,
            imageWidth = 1200,
            imageHeight = 627,
            imageWidthMin = 300,
            imageHeightMin = 157,
        ).toPrebidAsset()!!.getJsonObject(1).getJSONObject("img")
        assertEquals(1200, img.getInt("w"))
        assertEquals(627, img.getInt("h"))
        assertEquals(300, img.getInt("wmin"))
        assertEquals(157, img.getInt("hmin"))
    }

    @Test
    fun nativeRequestSettings_appliesTheRequestToANativeAdUnit() {
        val unit = NativeAdUnit("config-id")
        NativeRequestSettings(
            NativeAdRequestConfig(
                configId = "config-id",
                assets = listOf(
                    NativeAssetConfig(assetType = "title", required_ = true),
                    NativeAssetConfig(assetType = "video", required_ = true),
                ),
                eventTrackers = listOf(NativeEventTrackerConfig(eventType = 1, methods = listOf(1))),
                context = 1,
                contextSubType = 10,
                placementType = 2,
                placementCount = 4,
                sequence = 1,
                privacy = true,
                ext = """{"e":1}""",
                pbAdSlot = "/slot",
                gpid = "/gpid",
            ),
        ).applyTo(unit)
        val config = unit.nativeConfiguration
        assertEquals(1, config.assets.size)
        assertEquals(1, config.eventTrackers.size)
        assertEquals(NativeAdUnit.CONTEXT_TYPE.CONTENT_CENTRIC, config.contextType)
        assertEquals(NativeAdUnit.CONTEXTSUBTYPE.GENERAL, config.contextSubtype)
        assertEquals(NativeAdUnit.PLACEMENTTYPE.CONTENT_ATOMIC_UNIT, config.placementType)
        assertEquals(4, config.placementCount)
        assertEquals(1, config.seq)
        assertTrue(config.privacy)
        assertEquals(1, config.ext.getInt("e"))
        assertEquals("/slot", unit.pbAdSlot)
        assertEquals("/gpid", unit.gpid)
    }
}
