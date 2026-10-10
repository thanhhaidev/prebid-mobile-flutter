package io.github.thanhhaidev.prebid_mobile_sdk

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import org.json.JSONObject
import org.prebid.mobile.NativeEventTracker
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
}
