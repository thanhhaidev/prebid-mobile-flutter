import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'ad_event_router.dart';
import 'generated/prebid_api.g.dart';
import 'native_ad_enums.dart';

/// Listener for native ad events.
class PrebidNativeAdListener {
  /// Called when the native ad data is loaded.
  final void Function(PrebidNativeAdResponse response)? onAdLoaded;

  /// Called when the ad fails to load.
  final void Function(String error)? onAdFailed;

  /// Called when an impression is tracked. Fires only while the ad is shown
  /// in a [PrebidNativeAdView] (Prebid measures viewability on that view).
  final void Function()? onAdImpression;

  /// Called when the ad is clicked inside a [PrebidNativeAdView].
  final void Function()? onAdClicked;

  /// Called when the ad's bid expired (per `bid.exp`) before it was shown.
  final void Function()? onAdExpired;

  /// Creates a [PrebidNativeAdListener].
  const PrebidNativeAdListener({
    this.onAdLoaded,
    this.onAdFailed,
    this.onAdImpression,
    this.onAdClicked,
    this.onAdExpired,
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
  @visibleForTesting
  static NativeAdHostApi api = NativeAdHostApi();
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
    AdEventRouter.instance.register(_adId, _handleEvent);
  }

  void _handleEvent(AdEvent event) {
    final l = listener;
    if (l == null) return;
    switch (event.eventName) {
      case 'onAdLoaded':
        if (event.nativeAd != null) {
          l.onAdLoaded?.call(
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
        l.onAdFailed?.call(event.error ?? 'Unknown error');
      case 'onAdImpression':
        l.onAdImpression?.call();
      case 'onAdClicked':
        l.onAdClicked?.call();
      case 'onAdExpired':
        l.onAdExpired?.call();
    }
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
    api.loadAd(_adId, config);
  }

  /// Destroy the native ad and free resources.
  Future<void> destroy() async {
    AdEventRouter.instance.unregister(_adId);
    api.destroy(_adId);
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

/// Renders a loaded [PrebidNativeAd] with a native view and registers it with
/// Prebid, so impressions (viewability-based) and clicks are tracked and
/// reported through the ad's [PrebidNativeAdListener].
///
/// Show it after `onAdLoaded` fires:
///
/// ```dart
/// late final PrebidNativeAd ad;
/// bool loaded = false;
///
/// ad = PrebidNativeAd(
///   configId: 'prebid-demo-banner-native-styles',
///   listener: PrebidNativeAdListener(
///     onAdLoaded: (_) => setState(() => loaded = true),
///     onAdImpression: () => debugPrint('impression'),
///     onAdClicked: () => debugPrint('click'),
///   ),
/// )..loadAd();
///
/// // in build():
/// if (loaded) PrebidNativeAdView(ad: ad);
/// ```
///
/// The layout (main image, icon, sponsored, title, body, call to action) is
/// rendered natively; the widget grows to the rendered content's height.
class PrebidNativeAdView extends StatefulWidget {
  /// The loaded native ad to render.
  final PrebidNativeAd ad;

  /// Width of the view.
  final double width;

  /// Initial height, replaced by the rendered content height.
  final double height;

  /// Creates a [PrebidNativeAdView].
  const PrebidNativeAdView({
    super.key,
    required this.ad,
    this.width = double.infinity,
    this.height = 320,
  });

  @override
  State<PrebidNativeAdView> createState() => _PrebidNativeAdViewState();
}

class _PrebidNativeAdViewState extends State<PrebidNativeAdView> {
  static const _viewType = 'prebid_mobile_flutter/native_ad';

  late double _height = widget.height;
  MethodChannel? _channel;

  void _onPlatformViewCreated(int viewId) {
    _channel = MethodChannel('prebid_mobile_flutter/native_ad_$viewId')
      ..setMethodCallHandler((call) async {
        if (call.method == 'onAdSize') {
          final h = ((call.arguments as Map?)?['height'] as num?)?.toDouble();
          if (h != null && h > 0 && mounted) setState(() => _height = h);
        }
      });
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final creationParams = <String, Object?>{'adId': widget.ad._adId};
    final Widget view;
    if (!kIsWeb && Platform.isAndroid) {
      view = AndroidView(
        viewType: _viewType,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    } else if (!kIsWeb && Platform.isIOS) {
      view = UiKitView(
        viewType: _viewType,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    } else {
      view = const SizedBox.shrink();
    }
    return SizedBox(width: widget.width, height: _height, child: view);
  }
}
