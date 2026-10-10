import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'companion/ad_view_channel.dart';
import 'generated/prebid_api.g.dart';
import 'internal/ad_event_router.dart';
import 'internal/ad_ids.dart';
import 'internal/pigeon_conversions.dart';
import 'internal/visibility.dart';
import 'native_ad_enums.dart';
import 'native_parameters.dart';

/// Listener for native ad events.
class PrebidNativeAdListener {
  /// Creates a [PrebidNativeAdListener].
  const PrebidNativeAdListener({
    this.onAdLoaded,
    this.onAdFailed,
    this.onAdImpression,
    this.onAdClicked,
    this.onAdExpired,
  });

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
}

/// Structured native ad response data.
class PrebidNativeAdResponse {
  /// Creates a [PrebidNativeAdResponse].
  const PrebidNativeAdResponse({
    this.title,
    this.text,
    this.iconUrl,
    this.imageUrl,
    this.sponsoredBy,
    this.callToAction,
    this.clickUrl,
    this.privacyUrl,
    this.titles = const [],
    this.images = const [],
    this.dataAssets = const [],
  });

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

  /// The AdChoices / privacy notice URL (native `privacy`). Show it as an
  /// AdChoices link when your layout renders the ad itself.
  final String? privacyUrl;

  /// Every title asset of the response.
  final List<String> titles;

  /// Every image asset of the response.
  final List<PrebidNativeImage> images;

  /// Every data asset of the response (rating, price, likes, address, ...).
  final List<PrebidNativeData> dataAssets;

  /// The values of the data assets of [type].
  List<String> dataOf(NativeDataType type) => [
    for (final d in dataAssets)
      if (d.type == type.value && d.value != null) d.value!,
  ];
}

/// An image asset of a native response.
class PrebidNativeImage {
  /// Creates a [PrebidNativeImage].
  const PrebidNativeImage({
    required this.type,
    this.url,
    this.width,
    this.height,
  });

  /// The OpenRTB image type (see [NativeImageType]).
  final int type;

  /// The image URL.
  final String? url;

  /// The image width the bid declares, in pixels. iOS only: Prebid Android
  /// doesn't keep it.
  final int? width;

  /// The image height the bid declares, in pixels. iOS only, as [width].
  final int? height;
}

/// A data asset of a native response.
class PrebidNativeData {
  /// Creates a [PrebidNativeData].
  const PrebidNativeData({required this.type, this.value});

  /// The OpenRTB data asset type (see [NativeDataType]).
  final int type;

  /// The asset value.
  final String? value;
}

/// Defines a native asset for the ad request.
class NativeAsset {
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
    this.imageMimes,
    this.ext,
    this.assetExt,
  });

  /// Creates a title asset.
  const NativeAsset.title({
    int length = 90,
    bool required = false,
    Map<String, Object?>? ext,
    Map<String, Object?>? assetExt,
  }) : this._(
         type: NativeAssetType.title,
         titleLength: length,
         required: required,
         ext: ext,
         assetExt: assetExt,
       );

  /// Creates an image asset.
  const NativeAsset.image({
    NativeImageType imageType = NativeImageType.main,
    int? width,
    int? height,
    int? widthMin,
    int? heightMin,
    List<String>? mimes,
    bool required = false,
    Map<String, Object?>? ext,
    Map<String, Object?>? assetExt,
  }) : this._(
         type: NativeAssetType.image,
         imageMimes: mimes,
         imageType: imageType,
         imageWidth: width,
         imageHeight: height,
         imageWidthMin: widthMin,
         imageHeightMin: heightMin,
         required: required,
         ext: ext,
         assetExt: assetExt,
       );

  /// Creates a data asset.
  const NativeAsset.data({
    required NativeDataType dataType,
    int? length,
    bool required = false,
    Map<String, Object?>? ext,
    Map<String, Object?>? assetExt,
  }) : this._(
         type: NativeAssetType.data,
         dataType: dataType,
         dataLength: length,
         required: required,
         ext: ext,
         assetExt: assetExt,
       );

  /// The kind of asset: title, image or data.
  final NativeAssetType type;

  /// Whether the bid must include this asset.
  final bool required;

  /// Maximum title length in characters (title assets).
  final int? titleLength;

  /// Image subtype: icon, main or custom (image assets).
  final NativeImageType? imageType;

  /// Exact image width in pixels (image assets).
  final int? imageWidth;

  /// Exact image height in pixels (image assets).
  final int? imageHeight;

  /// Minimum image width in pixels (image assets).
  final int? imageWidthMin;

  /// Minimum image height in pixels (image assets).
  final int? imageHeightMin;

  /// Data subtype, e.g. sponsored, description or rating (data assets).
  final NativeDataType? dataType;

  /// Maximum data length in characters (data assets).
  final int? dataLength;

  /// Image MIME types the app accepts, e.g. `['image/png']` (image assets).
  final List<String>? imageMimes;

  /// The `ext` of the asset's `title`, `img` or `data` object.
  final Map<String, Object?>? ext;

  /// The asset's own `ext` (`assets[].ext`). Android only: Prebid iOS has
  /// no field for it.
  final Map<String, Object?>? assetExt;

  /// The method-channel form used by the GAM / AdMob / MAX native widgets.
  /// Keys match the Pigeon `NativeAssetConfig` fields.
  Map<String, Object?> toMap() => {
    'assetType': type.name,
    'required': required,
    'titleLength': ?titleLength,
    'imageType': ?imageType?.value,
    'imageWidth': ?imageWidth,
    'imageHeight': ?imageHeight,
    'imageWidthMin': ?imageWidthMin,
    'imageHeightMin': ?imageHeightMin,
    'dataType': ?dataType?.value,
    'dataLength': ?dataLength,
    'imageMimes': ?imageMimes,
    if (ext != null) 'ext': jsonEncode(ext),
    if (assetExt != null) 'assetExt': jsonEncode(assetExt),
  };
}

/// Defines a native event tracker for the ad request.
class NativeEventTracker {
  /// Creates a [NativeEventTracker].
  const NativeEventTracker({
    required this.eventType,
    required this.methods,
    this.ext,
  });

  /// The event to track, e.g. an impression.
  final NativeEventType eventType;

  /// How the event is tracked: image pixel, JavaScript or custom.
  final List<NativeEventTrackingMethod> methods;

  /// The tracker's `ext`. Android only: Prebid iOS doesn't send it.
  final Map<String, Object?>? ext;

  /// The method-channel form used by the GAM / AdMob / MAX native widgets.
  Map<String, Object?> toMap() => {
    'eventType': eventType.value,
    'methods': methods.map((m) => m.value).toList(),
    if (ext != null) 'ext': jsonEncode(ext),
  };
}

/// A native ad: loads the assets of a native bid for your app to show.
///
/// Show it with [PrebidNativeAdView], which renders a native layout, or with
/// [PrebidNativeAdView.custom] around your own Flutter layout. Prebid only
/// tracks impressions and clicks of an ad shown through one of them.
///
/// ```dart
/// final nativeAd = PrebidNativeAd(
///   configId: 'your-config-id',
///   nativeParameters: const NativeParameters(
///     assets: [
///       NativeAsset.title(length: 90, required: true),
///       NativeAsset.image(imageType: NativeImageType.main, required: true),
///       NativeAsset.data(dataType: NativeDataType.ctaText, required: true),
///     ],
///     eventTrackers: [
///       NativeEventTracker(
///         eventType: NativeEventType.impression,
///         methods: [NativeEventTrackingMethod.image],
///       ),
///     ],
///   ),
///   listener: PrebidNativeAdListener(
///     // Show PrebidNativeAdView(ad: nativeAd), or your layout of
///     // `response` inside PrebidNativeAdView.custom.
///     onAdLoaded: (response) { /* ... */ },
///     onAdFailed: (error) { /* handle error */ },
///   ),
/// );
/// nativeAd.loadAd();
/// ```
///
/// [destroy] releases the native ad; call it when the ad is no longer needed
/// (e.g. from `State.dispose`) or the native ad leaks. The object stays
/// usable: calling [loadAd] after [destroy] loads a fresh ad and its events
/// reach [listener] again.
class PrebidNativeAd {
  /// Creates a [PrebidNativeAd].
  PrebidNativeAd({
    required this.configId,
    this.nativeParameters = const NativeParameters(),
    this.gpid,
    this.pbAdSlot,
    this.impOrtbConfig,
    this.globalOrtbConfig,
    this.listener,
  }) : _adId = nextAdId() {
    AdEventRouter.instance.register(_adId, _handleEvent);
  }

  /// The platform channel to the native SDK; tests replace it with a mock.
  @visibleForTesting
  static NativeAdHostApi api = NativeAdHostApi();

  final int _adId;

  /// The Prebid Server config ID.
  final String configId;

  /// The native request: assets, event trackers, context and options.
  /// Unset assets request [NativeParameters.defaultAssets].
  final NativeParameters nativeParameters;

  /// Global Placement ID (`imp.ext.gpid`).
  final String? gpid;

  /// Prebid ad slot (`imp.ext.data.pbadslot`).
  final String? pbAdSlot;

  /// Impression-level OpenRTB JSON merged into this ad unit's `imp`.
  final String? impOrtbConfig;

  /// Request-level OpenRTB JSON for this ad unit only (merged over
  /// [PrebidTargeting.setGlobalOrtbConfig]).
  final String? globalOrtbConfig;

  /// Listener for native ad events.
  final PrebidNativeAdListener? listener;

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
              privacyUrl: event.nativeAd!.privacyUrl,
              titles: [...?event.nativeAd!.titles?.nonNulls],
              images: [
                for (final i
                    in event.nativeAd!.images?.nonNulls ??
                        <NativeAdImageData>[])
                  PrebidNativeImage(
                    type: i.type,
                    url: i.url,
                    width: i.width,
                    height: i.height,
                  ),
              ],
              dataAssets: [
                for (final d
                    in event.nativeAd!.dataAssets?.nonNulls ??
                        <NativeAdDataAssetData>[])
                  PrebidNativeData(type: d.type, value: d.value),
              ],
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

  /// Load the native ad. Also valid after [destroy].
  Future<void> loadAd() async {
    // Re-register: [destroy] unregisters, and the object may be reused.
    AdEventRouter.instance.register(_adId, _handleEvent);
    final config = nativeParameters.toConfig(
      configId: configId,
      gpid: gpid,
      pbAdSlot: pbAdSlot,
      impOrtbConfig: impOrtbConfig,
      globalOrtbConfig: globalOrtbConfig,
    );
    await api.loadAd(_adId, config);
  }

  /// Loads the native ad a Prebid cache id points to instead of running an
  /// auction: the [PrebidMultiformatBidResponse.nativeAdCacheId] of an
  /// Original API native win. The result reaches [listener] as for
  /// [loadAd], and the ad shows in a [PrebidNativeAdView].
  Future<void> loadFromCacheId(String cacheId) async {
    AdEventRouter.instance.register(_adId, _handleEvent);
    await api.loadFromCacheId(_adId, cacheId);
  }

  /// Reports a click on the ad shown in [PrebidNativeAdView.custom], as a tap
  /// on its layout does: Prebid fires the click trackers and opens the
  /// click URL. Call it from your own buttons (e.g. the call to action);
  /// returns false when the ad isn't on screen in a custom view.
  Future<bool> performClick() => api.performClick(_adId);

  /// Releases the native ad and stops event delivery to [listener] until
  /// the next [loadAd].
  Future<void> destroy() async {
    AdEventRouter.instance.unregister(_adId);
    await api.destroy(_adId);
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
///
/// The impression ([PrebidNativeAdListener.onAdImpression]) is reported once
/// at least half of the view has been on screen for one second. "On screen"
/// accounts for Flutter's own clipping too, such as a list scrolled under an
/// app bar.
class PrebidNativeAdView extends StatefulWidget {
  /// Creates a [PrebidNativeAdView].
  const PrebidNativeAdView({
    super.key,
    required this.ad,
    this.width,
    this.height = 320,
  }) : child = null,
       assert(width == null || width > 0, 'width must be positive'),
       assert(height > 0, 'height must be positive');

  /// Shows [child], your own layout of the ad's assets, and tracks it: a
  /// transparent native view under [child] is registered with Prebid for the
  /// impression, and a tap on [child] (one its own buttons don't handle)
  /// reports a click through [PrebidNativeAd.performClick].
  ///
  /// ```dart
  /// PrebidNativeAdView.custom(
  ///   ad: ad,
  ///   child: Column(children: [Text(response.title ?? ''), ...]),
  /// );
  /// ```
  const PrebidNativeAdView.custom({
    super.key,
    required this.ad,
    required Widget this.child,
  }) : width = null,
       height = 0;

  /// The loaded native ad to render.
  final PrebidNativeAd ad;

  /// The app's layout, for [PrebidNativeAdView.custom]; null when the ad is
  /// rendered natively.
  final Widget? child;

  /// Width of the view. `null` (default) fills the parent's width.
  ///
  /// Inside a parent that doesn't bound the width (e.g. a horizontal
  /// `ListView` or a `Row` without `Expanded`) a `null` width falls back to
  /// the screen width; set an explicit width there instead.
  final double? width;

  /// Initial height, replaced by the rendered content height. Unused by
  /// [PrebidNativeAdView.custom], which takes [child]'s size.
  final double height;

  @override
  State<PrebidNativeAdView> createState() => _PrebidNativeAdViewState();
}

class _PrebidNativeAdViewState extends State<PrebidNativeAdView> {
  static const _viewType = 'prebid_mobile_sdk/native_ad';

  /// How often the visible fraction is measured, as the native viewability
  /// check polls.
  static const _visibilityInterval = Duration(milliseconds: 250);

  late double _height = widget.height;
  late AdViewChannel _view = _listen();
  bool _created = false;
  final _boxKey = GlobalKey();
  Timer? _visibilityTimer;
  double? _sentFraction;

  @override
  void didUpdateWidget(PrebidNativeAdView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different ad gets a new native view (keyed by ad id below); stop
    // listening to the old view, whose late size reports would apply to it.
    if (oldWidget.ad._adId != widget.ad._adId ||
        (oldWidget.child == null) != (widget.child == null)) {
      _view.dispose();
      _view = _listen();
      _created = false;
      _stopVisibility();
      _height = widget.height;
    }
  }

  AdViewChannel _listen() => AdViewChannel(_viewType, (call) async {
    if (call.method == 'onAdSize') {
      final h = ((call.arguments as Map?)?['height'] as num?)?.toDouble();
      if (h != null && h > 0 && mounted) setState(() => _height = h);
    }
  });

  /// Reports the fraction of the view Flutter paints on screen to the native
  /// view, which counts the ad viewable only when both its own check and
  /// this fraction reach one half. Sent when it changes.
  void _startVisibility() {
    _stopVisibility();
    _visibilityTimer = Timer.periodic(_visibilityInterval, (_) {
      final box = _boxKey.currentContext?.findRenderObject();
      final channel = _view.methodChannel;
      if (box is! RenderBox || !_created) return;
      final fraction = (visibleFraction(box) * 100).roundToDouble() / 100;
      if (fraction == _sentFraction) return;
      _sentFraction = fraction;
      channel.invokeMethod<void>('setVisibleFraction', fraction).catchError((
        Object _,
      ) {
        // The native view is gone (disposed between ticks).
      });
    });
  }

  void _stopVisibility() {
    _visibilityTimer?.cancel();
    _visibilityTimer = null;
    _sentFraction = null;
  }

  void _onPlatformViewCreated(int viewId) {
    _created = true;
    _startVisibility();
  }

  @override
  void dispose() {
    _stopVisibility();
    _view.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    final creationParams = <String, Object?>{
      'adId': widget.ad._adId,
      'channelId': _view.id,
      if (child != null) 'layout': 'custom',
    };
    final key = ValueKey(_view.id);
    final Widget view;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      view = AndroidView(
        key: key,
        viewType: _viewType,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      view = UiKitView(
        key: key,
        viewType: _viewType,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    } else {
      view = const SizedBox.shrink();
    }
    if (child != null) {
      // The tracking view fills the child's area, under it.
      return Stack(
        key: _boxKey,
        children: [
          Positioned.fill(child: view),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => unawaited(widget.ad.performClick()),
            child: child,
          ),
        ],
      );
    }
    final width = widget.width;
    // `null` fills the parent's width. LimitedBox only applies when the
    // parent leaves the width unbounded, where a native view can't be
    // infinitely wide: it then falls back to the screen width.
    return LimitedBox(
      maxWidth: width ?? MediaQuery.maybeSizeOf(context)?.width ?? 0,
      child: SizedBox(
        key: _boxKey,
        width: width ?? double.infinity,
        height: _height,
        child: view,
      ),
    );
  }
}
