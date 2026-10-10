package io.github.thanhhaidev.prebid_mobile_sdk

import org.prebid.mobile.NativeAdUnit
import org.prebid.mobile.NativeDataAsset
import org.prebid.mobile.NativeEventTracker
import org.prebid.mobile.NativeImageAsset
import org.prebid.mobile.NativeTitleAsset
import org.prebid.mobile.PrebidMobile
import org.prebid.mobile.PrebidNativeAd

/** NativeAdHostApi: In-App native ads; the assets go to Dart, which renders them. */
class NativeAdHostApiImpl(
    private val flutterApi: AdFlutterApi,
    private val store: NativeAdStore,
) : NativeAdHostApi {

    private val nativeAds = mutableMapOf<Long, NativeAdUnit>()

    override fun loadAd(adId: Long, config: NativeAdRequestConfig) {
        destroy(adId)
        if (!PrebidMobile.isSdkInitialized()) {
            flutterApi.onAdEvent(AdEvent(
                adId = adId, eventName = "onAdFailed",
                error = PluginErrors.NOT_INITIALIZED,
            )) {}
            return
        }
        val nativeAdUnit = NativeAdUnit(config.configId)

        // Set context
        config.context?.let {
            nativeAdUnit.setContextType(NativeAdUnit.CONTEXT_TYPE.values().firstOrNull { ct -> ct.id == it.toInt() })
        }
        config.contextSubType?.let {
            nativeAdUnit.setContextSubType(NativeAdUnit.CONTEXTSUBTYPE.values().firstOrNull { st -> st.id == it.toInt() })
        }
        config.placementType?.let {
            nativeAdUnit.setPlacementType(NativeAdUnit.PLACEMENTTYPE.values().firstOrNull { pt -> pt.id == it.toInt() })
        }
        config.placementCount?.let { nativeAdUnit.setPlacementCount(it.toInt()) }
        config.pbAdSlot?.let { nativeAdUnit.setPbAdSlot(it) }
        config.gpid?.let { nativeAdUnit.setGpid(it) }
        config.impOrtbConfig?.let { nativeAdUnit.setImpOrtbConfig(it) }

        // Configure assets
        config.assets?.filterNotNull()?.forEach { assetConfig ->
            when (assetConfig.assetType) {
                "title" -> {
                    val titleAsset = NativeTitleAsset()
                    titleAsset.setLength(assetConfig.titleLength?.toInt() ?: 90)
                    titleAsset.isRequired = assetConfig.required_
                    nativeAdUnit.addAsset(titleAsset)
                }
                "image" -> {
                    val imageAsset = NativeImageAsset(
                        assetConfig.imageWidthMin?.toInt() ?: 0,
                        assetConfig.imageHeightMin?.toInt() ?: 0,
                        assetConfig.imageWidth?.toInt() ?: 0,
                        assetConfig.imageHeight?.toInt() ?: 0
                    )
                    assetConfig.imageType?.let { imageAsset.imageType = NativeImageAsset.IMAGE_TYPE.values().firstOrNull { t -> t.id == it.toInt() } }
                    imageAsset.isRequired = assetConfig.required_
                    nativeAdUnit.addAsset(imageAsset)
                }
                "data" -> {
                    val dataAsset = NativeDataAsset()
                    assetConfig.dataType?.let { dataAsset.dataType = NativeDataAsset.DATA_TYPE.values().firstOrNull { d -> d.id == it.toInt() } }
                    assetConfig.dataLength?.let { dataAsset.setLen(it.toInt()) }
                    dataAsset.isRequired = assetConfig.required_
                    nativeAdUnit.addAsset(dataAsset)
                }
            }
        }

        // Configure event trackers
        config.eventTrackers?.filterNotNull()?.forEach { trackerConfig ->
            val methods = ArrayList<NativeEventTracker.EVENT_TRACKING_METHOD>()
            trackerConfig.methods.forEach { methodValue ->
                NativeEventTracker.EVENT_TRACKING_METHOD.values()
                    .firstOrNull { it.id == methodValue.toInt() }
                    ?.let { methods.add(it) }
            }
            val eventType = NativeEventTracker.EVENT_TYPE.values()
                .firstOrNull { it.id == trackerConfig.eventType.toInt() }
            if (eventType != null) {
                nativeAdUnit.addEventTracker(NativeEventTracker(eventType, methods))
            }
        }

        nativeAds[adId] = nativeAdUnit

        nativeAdUnit.fetchDemand { bidInfo ->
            if (bidInfo.dartResultCode() == "prebidDemandFetchSuccess") {
                val cacheId = bidInfo.nativeCacheId
                if (cacheId != null) {
                    val nativeAd = PrebidNativeAd.create(cacheId)
                    if (nativeAd != null) {
                        store.put(adId, nativeAd)
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
        store.remove(adId)
    }

    fun destroyAll() {
        nativeAds.keys.toList().forEach(::destroy)
    }
}
