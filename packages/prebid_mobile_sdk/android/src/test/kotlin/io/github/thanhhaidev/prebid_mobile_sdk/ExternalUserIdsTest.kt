package io.github.thanhhaidev.prebid_mobile_sdk

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import org.mockito.Mockito.mock
import org.prebid.mobile.TargetingParams

/**
 * The external user IDs through the host API: Pigeon data to Prebid's
 * `ExternalUserId` and back. Prebid keeps them in a static map, cleared after
 * each test.
 */
internal class ExternalUserIdsTest {
    private val api = PrebidMobileHostApiImpl(
        mock(Context::class.java),
        PrebidEventFlutterApi(mock(BinaryMessenger::class.java)),
        releaseAds = {},
    )

    @AfterTest
    fun clearIds() {
        TargetingParams.setExternalUserIds(null)
    }

    @Test
    fun externalUserIds_roundTripEveryField() {
        val uid2 = ExternalUserIdData(
            source = "uidapi.com",
            uids = listOf(
                UserUniqueIdData(id = "uid2-abc", atype = 3, ext = mapOf("rtiPartner" to "UID2")),
                UserUniqueIdData(id = "uid2-def", atype = 1),
            ),
            ext = mapOf("segment" to "a"),
            inserter = "inserter.com",
            matcher = "matcher.com",
            mm = 2,
        )
        val shared = ExternalUserIdData(
            source = "sharedid.org",
            uids = listOf(UserUniqueIdData(id = "shared-xyz", atype = 1)),
            ext = mapOf("third" to true),
        )

        api.setExternalUserIds(listOf(uid2, shared))

        assertEquals(listOf(shared, uid2), api.getExternalUserIds().sortedBy { it.source })
    }

    @Test
    fun setExternalUserIds_dropsNullKeysAndValuesFromTheExts() {
        api.setExternalUserIds(
            listOf(
                ExternalUserIdData(
                    source = "id5-sync.com",
                    uids = listOf(UserUniqueIdData(id = "id5", atype = 1, ext = mapOf("k" to "v", "gone" to null))),
                    ext = mapOf("k" to 1L, null to "gone"),
                ),
            ),
        )

        val id = api.getExternalUserIds().single()
        assertEquals(mapOf<String?, Any?>("k" to 1L), id.ext)
        assertEquals(mapOf<String?, Any?>("k" to "v"), id.uids.single()?.ext)
    }

    @Test
    fun setExternalUserIds_replacesThePreviousIds() {
        api.setExternalUserIds(
            listOf(ExternalUserIdData(source = "a.com", uids = listOf(UserUniqueIdData(id = "1", atype = 1)))),
        )
        api.setExternalUserIds(
            listOf(ExternalUserIdData(source = "b.com", uids = listOf(UserUniqueIdData(id = "2", atype = 1)))),
        )

        assertEquals(listOf("b.com"), api.getExternalUserIds().map { it.source })
    }

    @Test
    fun clearExternalUserIds_removesEveryId() {
        api.setExternalUserIds(
            listOf(ExternalUserIdData(source = "a.com", uids = listOf(UserUniqueIdData(id = "1", atype = 1)))),
        )

        api.clearExternalUserIds()

        assertEquals(emptyList(), api.getExternalUserIds())
    }
}
