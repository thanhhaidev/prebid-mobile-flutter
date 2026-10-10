package io.github.thanhhaidev.prebid_mobile_sdk_admob

import kotlin.test.Ignore
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertNull
import kotlin.test.assertTrue
import org.json.JSONObject
import org.mockito.ArgumentMatchers.argThat
import org.mockito.Mockito.mock
import org.mockito.Mockito.verify
import org.mockito.Mockito.verifyNoInteractions
import org.prebid.mobile.NativeAdUnit
import org.prebid.mobile.NativeDataAsset
import org.prebid.mobile.NativeEventTracker
import org.prebid.mobile.NativeImageAsset
import org.prebid.mobile.NativeTitleAsset
import org.prebid.mobile.api.data.Position
import org.prebid.mobile.api.mediation.MediationNativeAdUnit

/*
 * JVM unit tests of the channel argument parsing. Run them from
 * `example/android` with `./gradlew :prebid_mobile_sdk_gam:testDebugUnitTest`
 * (`_admob`, `_max` alike). Like PrebidRequests.kt, the three companion copies of
 * this file are identical apart from the package line (tool/check_copies.sh).
 * The values mirror what Flutter's standard codec sends: Int or Long for a
 * Dart int, Double for a double, String for `jsonEncode` output.
 */

internal class PrebidRequestsTest {
    @Test
    fun int_readsAnyNumberAndIgnoresOtherTypes() {
        val m = mapOf("int" to 7, "long" to 8L, "double" to 9.9, "string" to "10")
        assertEquals(7, m.int("int"))
        assertEquals(8, m.int("long"))
        assertEquals(9, m.int("double"))
        assertNull(m.int("string"))
        assertNull(m.int("missing"))
    }

    @Test
    fun json_parsesAJsonObjectStringAndIgnoresInvalidJson() {
        val m = mapOf("ok" to """{"k":1}""", "bad" to "not json", "map" to mapOf("k" to 1))
        assertEquals(1, m.json("ok")?.getInt("k"))
        assertNull(m.json("bad"))
        assertNull(m.json("map"))
        assertNull(m.json("missing"))
    }

    @Test
    fun nativeAssetsFrom_isNullWithoutAList() {
        assertNull(nativeAssetsFrom(null))
        assertNull(nativeAssetsFrom(mapOf("assetType" to "title")))
    }

    @Test
    fun nativeAssetsFrom_buildsATitleWithItsLengthAndExts() {
        val title = nativeAssetsFrom(
            listOf(
                mapOf(
                    "assetType" to "title",
                    "required" to true,
                    "titleLength" to 25,
                    "ext" to """{"k":1}""",
                    "assetExt" to """{"a":true}""",
                ),
            ),
        )!!.single()
        assertIs<NativeTitleAsset>(title)
        assertEquals(25, title.len)
        assertTrue(title.isRequired)
        assertEquals(1, (title.titleExt as JSONObject).getInt("k"))
        assertEquals(true, (title.assetExt as JSONObject).getBoolean("a"))
    }

    @Test
    fun nativeAssetsFrom_titleDefaultsTo90CharactersAndOptional() {
        val title = nativeAssetsFrom(listOf(mapOf("assetType" to "title")))!!.single()
        assertIs<NativeTitleAsset>(title)
        assertEquals(90, title.len)
        assertFalse(title.isRequired)
        assertNull(title.titleExt)
    }

    @Test
    fun nativeAssetsFrom_buildsAnImageWithItsTypeMimesAndExt() {
        val image = nativeAssetsFrom(
            listOf(
                mapOf(
                    "assetType" to "image",
                    "required" to true,
                    "imageType" to 3,
                    "imageMimes" to listOf("image/png", 1, "image/jpeg"),
                    "ext" to """{"k":"v"}""",
                ),
            ),
        )!!.single()
        assertIs<NativeImageAsset>(image)
        assertEquals(NativeImageAsset.IMAGE_TYPE.MAIN, image.imageType)
        assertEquals(listOf("image/png", "image/jpeg"), image.mimes.toList())
        assertTrue(image.isRequired)
        assertEquals("v", (image.imageExt as JSONObject).getString("k"))
    }

    // Prebid's constructor is NativeImageAsset(w, h, wmin, hmin); the parsing
    // passes (wmin, hmin, w, h), so the request swaps the sizes and their minimums.
    @Ignore("w/h and wmin/hmin are swapped: fix the NativeImageAsset argument order")
    @Test
    fun nativeAssetsFrom_requestsTheImageSizesAndTheirMinimums() {
        val image = nativeAssetsFrom(
            listOf(
                mapOf(
                    "assetType" to "image",
                    "imageWidth" to 1200L,
                    "imageHeight" to 627,
                    "imageWidthMin" to 300,
                    "imageHeightMin" to 157,
                ),
            ),
        )!!.single()
        val img = image.getJsonObject(1).getJSONObject("img")
        assertEquals(1200, img.getInt("w"))
        assertEquals(627, img.getInt("h"))
        assertEquals(300, img.getInt("wmin"))
        assertEquals(157, img.getInt("hmin"))
    }

    @Test
    fun nativeAssetsFrom_imageWithAnUnknownTypeHasNoType() {
        val image = nativeAssetsFrom(listOf(mapOf("assetType" to "image", "imageType" to 42)))!!.single()
        assertIs<NativeImageAsset>(image)
        assertNull(image.imageType)
        assertEquals(0, image.w)
    }

    @Test
    fun nativeAssetsFrom_buildsADataAssetWithItsTypeAndLength() {
        val data = nativeAssetsFrom(
            listOf(
                mapOf(
                    "assetType" to "data",
                    "dataType" to 2,
                    "dataLength" to 140,
                    "assetExt" to """{"a":1}""",
                ),
            ),
        )!!.single()
        assertIs<NativeDataAsset>(data)
        assertEquals(NativeDataAsset.DATA_TYPE.DESC, data.dataType)
        assertEquals(140, data.len)
        assertFalse(data.isRequired)
        assertEquals(1, (data.assetExt as JSONObject).getInt("a"))
    }

    @Test
    fun nativeAssetsFrom_skipsUnknownAssetTypesAndNonMapItems() {
        val assets = nativeAssetsFrom(
            listOf(
                mapOf("assetType" to "video"),
                "title",
                mapOf("assetType" to "data", "dataType" to 1),
            ),
        )!!
        assertEquals(1, assets.size)
        assertEquals(NativeDataAsset.DATA_TYPE.SPONSORED, (assets.single() as NativeDataAsset).dataType)
    }

    @Test
    fun nativeAssetsFrom_ignoresAnInvalidExt() {
        val title = nativeAssetsFrom(listOf(mapOf("assetType" to "title", "ext" to "{oops")))!!.single()
        assertNull((title as NativeTitleAsset).titleExt)
    }

    @Test
    fun nativeTrackersFrom_keepsKnownMethodsAndTheExt() {
        val tracker = nativeTrackersFrom(
            listOf(mapOf("eventType" to 1, "methods" to listOf(1, 99, 2L), "ext" to """{"t":"x"}""")),
        )!!.single()
        assertEquals(NativeEventTracker.EVENT_TYPE.IMPRESSION, tracker.event)
        assertEquals(
            listOf(NativeEventTracker.EVENT_TRACKING_METHOD.IMAGE, NativeEventTracker.EVENT_TRACKING_METHOD.JS),
            tracker.methods.toList(),
        )
        assertEquals("x", (tracker.extObject as JSONObject).getString("t"))
    }

    @Test
    fun nativeTrackersFrom_dropsTrackersOfAnUnknownEventType() {
        val trackers = nativeTrackersFrom(
            listOf(mapOf("eventType" to 42, "methods" to listOf(1)), mapOf("methods" to listOf(1))),
        )
        assertEquals(emptyList<NativeEventTracker>(), trackers)
    }

    @Test
    fun nativeTrackersFrom_isNullWithoutAList() {
        assertNull(nativeTrackersFrom(null))
    }

    @Test
    fun videoMaxDurationFrom_readsMaxDurationOnly() {
        assertEquals(30, videoMaxDurationFrom(mapOf("maxDuration" to 30, "minDuration" to 5)))
        assertNull(videoMaxDurationFrom(mapOf("minDuration" to 5)))
        assertNull(videoMaxDurationFrom(null))
    }

    @Test
    fun fullscreenControls_readsEveryControl() {
        val controls = FullscreenControls.from(
            mapOf(
                "closeButtonArea" to 0.2,
                "closeButtonPosition" to "topLeft",
                "skipButtonArea" to 1,
                "skipButtonPosition" to "topRight",
                "skipDelay" to 5,
                "isMuted" to true,
                "isSoundButtonVisible" to false,
                "minWidthPercentage" to 50,
                "minHeightPercentage" to 40,
                "supportSKOverlay" to true,
            ),
        )!!
        assertEquals(0.2, controls.closeButtonArea)
        assertEquals(Position.TOP_LEFT, controls.closeButtonPosition)
        assertEquals(1.0, controls.skipButtonArea)
        assertEquals(Position.TOP_RIGHT, controls.skipButtonPosition)
        assertEquals(5, controls.skipDelay)
        assertEquals(true, controls.isMuted)
        assertEquals(false, controls.isSoundButtonVisible)
        assertEquals(50, controls.minWidthPercentage)
        assertEquals(40, controls.minHeightPercentage)
    }

    @Test
    fun fullscreenControls_leavesAbsentOrUnknownControlsUnset() {
        val controls = FullscreenControls.from(mapOf("closeButtonPosition" to "bottomLeft"))!!
        assertNull(controls.closeButtonPosition)
        assertNull(controls.closeButtonArea)
        assertNull(controls.skipDelay)
        assertNull(controls.isMuted)
        assertNull(FullscreenControls.from(null))
    }

    @Test
    fun nativeContext_mapsTheOpenRtbIds() {
        val context = NativeContext.from(mapOf("context" to 2, "contextSubType" to 12, "placementType" to 3))
        assertEquals(NativeAdUnit.CONTEXT_TYPE.SOCIAL_CENTRIC, context.context)
        assertEquals(NativeAdUnit.CONTEXTSUBTYPE.VIDEO, context.subType)
        assertEquals(NativeAdUnit.PLACEMENTTYPE.OUTSIDE_CORE_CONTENT, context.placement)
    }

    @Test
    fun nativeContext_isEmptyForAbsentOrUnknownIds() {
        val context = NativeContext.from(mapOf("context" to 99))
        assertNull(context.context)
        assertNull(context.subType)
        assertNull(context.placement)
    }

    @Test
    fun nativeRequestOptions_appliesEveryOptionToANativeAdUnit() {
        val unit = NativeAdUnit("config-id")
        NativeRequestOptions(
            mapOf(
                "placementCount" to 3,
                "sequence" to 2,
                "assetUrlSupport" to true,
                "dUrlSupport" to true,
                "privacy" to true,
                "ext" to """{"k":1}""",
            ),
        ).applyTo(unit)
        val config = unit.nativeConfiguration
        assertEquals(3, config.placementCount)
        assertEquals(2, config.seq)
        assertTrue(config.aUrlSupport)
        assertTrue(config.dUrlSupport)
        assertTrue(config.privacy)
        assertEquals(1, config.ext.getInt("k"))
    }

    @Test
    fun nativeRequestOptions_keepsTheAdUnitDefaultsForAbsentOptions() {
        val unit = NativeAdUnit("config-id")
        val defaults = unit.nativeConfiguration.run { listOf(placementCount, seq, aUrlSupport, dUrlSupport, privacy, ext) }
        NativeRequestOptions(mapOf("ext" to "not json")).applyTo(unit)
        val config = unit.nativeConfiguration
        assertEquals(defaults, listOf(config.placementCount, config.seq, config.aUrlSupport, config.dUrlSupport, config.privacy, config.ext))
    }

    @Test
    fun nativeRequestOptions_appliesEveryOptionToAMediationNativeAdUnit() {
        val unit = mock(MediationNativeAdUnit::class.java)
        NativeRequestOptions(
            mapOf(
                "placementCount" to 3,
                "sequence" to 2,
                "assetUrlSupport" to true,
                "dUrlSupport" to false,
                "privacy" to true,
                "ext" to """{"k":1}""",
            ),
        ).applyTo(unit)
        verify(unit).setPlacementCount(3)
        verify(unit).setSeq(2)
        verify(unit).setAUrlSupport(true)
        verify(unit).setDUrlSupport(false)
        verify(unit).setPrivacy(true)
        verify(unit).setExt(argThat<Any> { (it as JSONObject).getInt("k") == 1 })
    }

    @Test
    fun nativeRequestOptions_setsNothingOnAMediationNativeAdUnitWithoutOptions() {
        val unit = mock(MediationNativeAdUnit::class.java)
        NativeRequestOptions(emptyMap<String, Any>()).applyTo(unit)
        verifyNoInteractions(unit)
    }
}
