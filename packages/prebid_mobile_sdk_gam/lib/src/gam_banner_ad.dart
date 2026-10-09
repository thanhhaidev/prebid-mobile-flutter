import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show
        AdFormat,
        PrebidAdPosition,
        PrebidBannerAdController,
        PrebidBannerAdListener,
        PrebidBannerVideoListener,
        VideoParameters,
        VideoPlacementType;

/// A banner ad rendered by **Google Ad Manager** with Prebid demand.
///
/// Prebid runs the auction and, via its GAM event handler, GAM renders either
/// the winning Prebid creative (through a Prebid line item + the Prebid
/// Universal Creative) or a direct-sold GAM ad. Contrast with the core
/// `PrebidBannerAd`, where the Prebid SDK renders directly.
class PrebidGamBannerAd extends StatefulWidget {
  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The Google Ad Manager ad unit ID (e.g. `/1234567/your-ad-unit`).
  final String gamAdUnitId;

  /// The desired width of the banner ad in dp.
  final int width;

  /// The desired height of the banner ad in dp.
  final int height;

  /// Further sizes the slot accepts besides [width] x [height] (a multisize
  /// banner, e.g. `[Size(300, 250)]` next to 320x50). Passed to the GAM event
  /// handler as valid ad sizes, from which Prebid derives the request sizes.
  final List<Size>? additionalSizes;

  /// Whether this banner should display video ads.
  ///
  /// Ignored when [adFormats] is set.
  final bool isVideo;

  /// Formats to request — e.g. `{AdFormat.banner, AdFormat.video}` for a
  /// multiformat banner (Prebid 3.4). Overrides [isVideo] when set.
  final Set<AdFormat>? adFormats;

  /// Prebid ad slot (`imp.ext.data.pbadslot`).
  final String? pbAdSlot;

  /// Impression-level OpenRTB JSON merged into this ad unit's `imp` (e.g.
  /// `{"ext":{"gpid":"/1111/home"}}`).
  final String? impOrtbConfig;

  /// OpenRTB video parameters for an outstream video banner. **iOS only**:
  /// Prebid Android's `BannerView` has no video-parameters setter (use
  /// [videoPlacementType] there). An explicit `placement` here overrides
  /// [videoPlacementType].
  final VideoParameters? videoParameters;

  /// Whether the ad should load automatically when the widget is created.
  final bool autoLoad;

  /// Auto-refresh interval in seconds. `null` (default) or `0` disables
  /// auto-refresh on both platforms; positive values are clamped by Prebid to
  /// its supported range (Android 30–120 s, iOS 15–120 s).
  final int? refreshIntervalSeconds;

  /// Custom key-values added to the Google Ad Manager request (Prebid 3.4).
  /// Prebid's own `hb_*` keys take precedence on conflict.
  final Map<String, String>? customTargeting;

  /// Outstream video placement when the banner requests video. Defaults to
  /// [VideoPlacementType.inBanner].
  final VideoPlacementType? videoPlacementType;

  /// Optional controller to load on demand (`autoLoad: false`) or stop
  /// auto-refresh.
  final PrebidBannerAdController? controller;

  /// Ad position on screen (`imp.banner.pos`).
  final PrebidAdPosition? adPosition;

  /// Listener for banner ad events.
  final PrebidBannerAdListener? listener;

  /// Listener for video playback events (outstream video creatives).
  final PrebidBannerVideoListener? videoListener;

  /// Creates a [PrebidGamBannerAd] widget.
  const PrebidGamBannerAd({
    super.key,
    required this.configId,
    required this.gamAdUnitId,
    required this.width,
    required this.height,
    this.additionalSizes,
    this.isVideo = false,
    this.adFormats,
    this.pbAdSlot,
    this.impOrtbConfig,
    this.videoParameters,
    this.autoLoad = true,
    this.refreshIntervalSeconds,
    this.customTargeting,
    this.videoPlacementType,
    this.controller,
    this.adPosition,
    this.listener,
    this.videoListener,
  });

  @override
  State<PrebidGamBannerAd> createState() => _PrebidGamBannerAdState();
}

class _PrebidGamBannerAdState extends State<PrebidGamBannerAd> {
  /// Current slot size. Starts at the requested size and adopts the actual
  /// rendered creative size once the native SDK reports it via `onAdSize`.
  late double _width = widget.width.toDouble();
  late double _height = widget.height.toDouble();

  @override
  Widget build(BuildContext context) {
    final creationParams = <String, dynamic>{
      'configId': widget.configId,
      'gamAdUnitId': widget.gamAdUnitId,
      'width': widget.width,
      'height': widget.height,
      'isVideo': widget.isVideo,
      'autoLoad': widget.autoLoad,
      if (widget.adPosition != null) 'adPosition': widget.adPosition!.value,
      if (widget.additionalSizes != null)
        'additionalSizes': [
          for (final size in widget.additionalSizes!) ...[
            size.width.round(),
            size.height.round(),
          ],
        ],
      if (widget.adFormats != null)
        'adFormats': widget.adFormats!.map((f) => f.name).toList(),
      if (widget.pbAdSlot != null) 'pbAdSlot': widget.pbAdSlot,
      if (widget.impOrtbConfig != null) 'impOrtbConfig': widget.impOrtbConfig,
      if (widget.videoParameters != null)
        'videoParameters': widget.videoParameters!.toMap(),
      if (widget.refreshIntervalSeconds != null)
        'refreshIntervalSeconds': widget.refreshIntervalSeconds,
      if (widget.customTargeting != null)
        'customTargeting': widget.customTargeting,
      if (widget.videoPlacementType != null)
        'videoPlacementType': widget.videoPlacementType!.name,
    };

    return SizedBox(
      width: _width,
      height: _height,
      child: _buildPlatformView(creationParams),
    );
  }

  Widget _buildPlatformView(Map<String, dynamic> creationParams) {
    // defaultTargetPlatform (not dart:io) so widget tests can pick a platform.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: 'prebid_mobile_sdk_gam/banner',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: 'prebid_mobile_sdk_gam/banner',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    }
    return const SizedBox.shrink();
  }

  void _onPlatformViewCreated(int viewId) {
    final channel = MethodChannel('prebid_mobile_sdk_gam/banner_$viewId');
    _channel = channel;
    widget.controller?.attachChannel(channel);
    channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onAdSize':
          final args = call.arguments as Map?;
          final w = (args?['width'] as num?)?.toDouble();
          final h = (args?['height'] as num?)?.toDouble();
          if (w != null && h != null && w > 0 && h > 0 && mounted) {
            setState(() {
              _width = w;
              _height = h;
            });
          }
        case 'onAdLoaded':
          widget.listener?.onAdLoaded?.call();
        case 'onAdDisplayed':
          widget.listener?.onAdDisplayed?.call();
        case 'onAdFailed':
          widget.listener?.onAdFailed?.call(call.arguments as String? ?? '');
        case 'onAdClicked':
          widget.listener?.onAdClicked?.call();
        case 'onAdClosed':
          widget.listener?.onAdClosed?.call();
        case 'onAdExpired':
          widget.listener?.onAdExpired?.call();
        default:
          widget.videoListener?.dispatch(call.method);
      }
    });
  }

  MethodChannel? _channel;

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) {
      channel.setMethodCallHandler(null);
      widget.controller?.detachChannel(channel);
    }
    super.dispose();
  }
}
