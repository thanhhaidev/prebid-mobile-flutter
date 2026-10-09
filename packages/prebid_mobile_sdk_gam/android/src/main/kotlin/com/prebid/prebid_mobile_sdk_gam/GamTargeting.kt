package com.prebid.prebid_mobile_sdk_gam

/// Reads the `customTargeting` creation/method argument (a String→String map
/// from Dart) into a Kotlin map, or null when absent or empty.
internal fun gamCustomTargeting(raw: Any?): Map<String, String>? {
    val map = (raw as? Map<*, *>)
        ?.mapNotNull { (k, v) -> if (k is String && v is String) k to v else null }
        ?.toMap()
    return if (map.isNullOrEmpty()) null else map
}
