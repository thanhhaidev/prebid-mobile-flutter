package io.github.thanhhaidev.prebid_mobile_sdk

import kotlin.test.Test
import kotlin.test.assertEquals

/*
 * JVM unit tests. Run them from `example/android` with
 * `./gradlew :prebid_mobile_sdk:testDebugUnitTest`.
 */

internal class NativeImageLoaderTest {
    @Test
    fun calculateInSampleSize_keepsImageAtLeastRequestedSize() {
        assertEquals(1, calculateInSampleSize(100, 100, 100, 100))
        assertEquals(1, calculateInSampleSize(199, 199, 100, 100))
        assertEquals(2, calculateInSampleSize(200, 200, 100, 100))
        assertEquals(8, calculateInSampleSize(1200, 1200, 120, 120))
        // Bounded by the dimension closest to its target (cropping view).
        assertEquals(2, calculateInSampleSize(4000, 400, 1080, 180))
    }

    @Test
    fun calculateInSampleSize_unknownSizesDecodeFullSize() {
        assertEquals(1, calculateInSampleSize(-1, -1, 100, 100))
        assertEquals(1, calculateInSampleSize(1000, 1000, 0, 0))
    }
}
