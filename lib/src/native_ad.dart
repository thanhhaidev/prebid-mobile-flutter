import 'generated/prebid_api.g.dart';
import 'native_ad_enums.dart';

/// Listener for native ad events.
class PrebidNativeAdListener {
  /// Called when the native ad data is loaded.
  final void Function(PrebidNativeAdResponse response)? onAdLoaded;

  /// Called when the ad fails to load.
  final void Function(String error)? onAdFailed;

  /// Called when an impression is tracked.
  final void Function()? onAdImpression;

  /// Called when the ad is clicked.
  final void Function()? onAdClicked;

  /// Creates a [PrebidNativeAdListener].
  const PrebidNativeAdListener({
    this.onAdLoaded,
    this.onAdFailed,
    this.onAdImpression,
    this.onAdClicked,
  });
}

/// Structured native ad response data.
class PrebidNativeAdResponse {
  /// The ad title text.
  final String? title;

  /// The ad description/body text.
  final String? text;

  /// URL of the icon image.
  final String? iconUrl;

  /// URL of the main image.
  final String? imageUrl;

  /// The sponsor/advertiser name.
  final String? sponsoredBy;

  /// The call-to-action text (e.g. "Install", "Learn More").
  final String? callToAction;

  /// The click-through URL.
  final String? clickUrl;

  const PrebidNativeAdResponse({
    this.title,
    this.text,
    this.iconUrl,
    this.imageUrl,
    this.sponsoredBy,
    this.callToAction,
    this.clickUrl,
  });
}

/// Defines a native asset for the ad request.
class NativeAsset {
  final NativeAssetType type;
  final bool required;
  final int? titleLength;
  final NativeImageType? imageType;
  final int? imageWidth;
  final int? imageHeight;
  final int? imageWidthMin;
  final int? imageHeightMin;
  final NativeDataType? dataType;
  final int? dataLength;

  const NativeAsset._({
    required this.type,
    this.required = false,
    this.titleLength,
    this.imageType,
    this.imageWidth,
    this.imageHeight,
    this.imageWidthMin,
    this.imageHeightMin,
    this.dataType,
    this.dataLength,
  });

  /// Creates a title asset.
  const NativeAsset.title({int length = 90, bool required = false})
    : this._(
        type: NativeAssetType.title,
        titleLength: length,
        required: required,
      );

  /// Creates an image asset.
  const NativeAsset.image({
    NativeImageType imageType = NativeImageType.main,
    int? width,
    int? height,
    int? widthMin,
    int? heightMin,
    bool required = false,
  }) : this._(
         type: NativeAssetType.image,
         imageType: imageType,
         imageWidth: width,
         imageHeight: height,
         imageWidthMin: widthMin,
         imageHeightMin: heightMin,
         required: required,
       );

  /// Creates a data asset.
  const NativeAsset.data({
    required NativeDataType dataType,
    int? length,
    bool required = false,
  }) : this._(
         type: NativeAssetType.data,
         dataType: dataType,
         dataLength: length,
         required: required,
       );
}

/// Defines a native event tracker for the ad request.
class NativeEventTracker {
  final NativeEventType eventType;
  final List<NativeEventTrackingMethod> methods;

  const NativeEventTracker({required this.eventType, required this.methods});
}

/// A native ad that loads structured ad data and renders via Flutter widgets.
///
/// ```dart
/// final nativeAd = PrebidNativeAd(
///   configId: 'your-config-id',
///   assets: [
///     NativeAsset.title(length: 90, required: true),
///     NativeAsset.image(imageType: NativeImageType.main, required: true),
///     NativeAsset.image(imageType: NativeImageType.icon, required: true),
///     NativeAsset.data(dataType: NativeDataType.sponsored, required: true),
///     NativeAsset.data(dataType: NativeDataType.ctaText, required: true),
///     NativeAsset.data(dataType: NativeDataType.desc, required: true),
///   ],
///   eventTrackers: [
///     NativeEventTracker(
///       eventType: NativeEventType.impression,
///       methods: [NativeEventTrackingMethod.image],
///     ),
///   ],
///   listener: PrebidNativeAdListener(
///     onAdLoaded: (response) { /* render using Flutter widgets */ },
///     onAdFailed: (error) { /* handle error */ },
///   ),
/// );
/// nativeAd.loadAd();
/// ```
class PrebidNativeAd {
  static final NativeAdHostApi _api = NativeAdHostApi();
  static int _nextId = 2000000;

  final int _adId;

  /// The Prebid Server config ID.
  final String configId;

  /// The native assets to request.
  final List<NativeAsset>? assets;

  /// The native event trackers.
  final List<NativeEventTracker>? eventTrackers;

  /// Context type.
  final NativeContextType? context;

  /// Placement type.
  final NativePlacementType? placementType;

  /// Number of placements.
  final int? placementCount;

  /// Listener for native ad events.
  final PrebidNativeAdListener? listener;

  /// Creates a [PrebidNativeAd].
  PrebidNativeAd({
    required this.configId,
    this.assets,
    this.eventTrackers,
    this.context,
    this.placementType,
    this.placementCount,
    this.listener,
  }) : _adId = _nextId++ {
    _NativeAdEventRouter.instance.register(_adId, this);
  }

  /// Load the native ad.
  Future<void> loadAd() async {
    final config = NativeAdRequestConfig(
      configId: configId,
      assets: assets?.map(_convertAsset).toList(),
      eventTrackers: eventTrackers?.map(_convertTracker).toList(),
      context: context?.value,
      placementType: placementType?.value,
      placementCount: placementCount,
    );
    _api.loadAd(_adId, config);
  }

  /// Manually track an impression.
  Future<void> trackImpression() async {
    _api.trackImpression(_adId);
  }

  /// Manually track a click.
  Future<void> trackClick() async {
    _api.trackClick(_adId);
  }

  /// Destroy the native ad and free resources.
  Future<void> destroy() async {
    _NativeAdEventRouter.instance.unregister(_adId);
    _api.destroy(_adId);
  }

  NativeAssetConfig _convertAsset(NativeAsset asset) {
    return NativeAssetConfig(
      assetType: asset.type.name,
      required_: asset.required,
      titleLength: asset.titleLength,
      imageType: asset.imageType?.value,
      imageWidth: asset.imageWidth,
      imageHeight: asset.imageHeight,
      imageWidthMin: asset.imageWidthMin,
      imageHeightMin: asset.imageHeightMin,
      dataType: asset.dataType?.value,
      dataLength: asset.dataLength,
    );
  }

  NativeEventTrackerConfig _convertTracker(NativeEventTracker tracker) {
    return NativeEventTrackerConfig(
      eventType: tracker.eventType.value,
      methods: tracker.methods.map((m) => m.value).toList(),
    );
  }
}

/// Routes native ad events from native to Dart.
class _NativeAdEventRouter implements AdFlutterApi {
  static final _NativeAdEventRouter instance = _NativeAdEventRouter._();
  _NativeAdEventRouter._() {
    AdFlutterApi.setUp(this);
  }

  final Map<int, PrebidNativeAd> _ads = {};

  void register(int adId, PrebidNativeAd ad) {
    _ads[adId] = ad;
  }

  void unregister(int adId) {
    _ads.remove(adId);
  }

  @override
  void onAdEvent(AdEvent event) {
    final ad = _ads[event.adId];
    if (ad == null) return;

    final listener = ad.listener;
    if (listener == null) return;

    switch (event.eventName) {
      case 'onAdLoaded':
        if (event.nativeAd != null) {
          listener.onAdLoaded?.call(
            PrebidNativeAdResponse(
              title: event.nativeAd!.title,
              text: event.nativeAd!.text,
              iconUrl: event.nativeAd!.iconUrl,
              imageUrl: event.nativeAd!.imageUrl,
              sponsoredBy: event.nativeAd!.sponsoredBy,
              callToAction: event.nativeAd!.callToAction,
              clickUrl: event.nativeAd!.clickUrl,
            ),
          );
        }
      case 'onAdFailed':
        listener.onAdFailed?.call(event.error ?? 'Unknown error');
      case 'onAdImpression':
        listener.onAdImpression?.call();
      case 'onAdClicked':
        listener.onAdClicked?.call();
    }
  }
}
