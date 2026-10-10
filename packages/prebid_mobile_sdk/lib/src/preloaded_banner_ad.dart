import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'ad_enums.dart';
import 'ad_listener.dart';
import 'banner_ad.dart';
import 'companion/ad_view_channel.dart';
import 'companion/ad_view_state.dart';
import 'generated/prebid_api.g.dart';
import 'internal/ortb.dart';
import 'internal/platform_view.dart';
import 'video_parameters.dart';

const _viewType = 'prebid_mobile_sdk/banner_ad';

/// A Prebid-rendered banner that lives apart from the widgets showing it:
/// [load] it before its slot is on screen, show it with a
/// [PrebidPreloadedBannerAdView], and [destroy] it when you no longer need
/// it.
///
/// Unlike a [PrebidBannerAd], which loads when its widget is built and is
/// destroyed with it, the banner survives its view: in a scrolling list, a
/// slot scrolled away and back shows the same ad instead of running a new
/// auction. The banner's impression is counted once it is on screen.
///
/// ```dart
/// final ad = PrebidPreloadedBannerAd(
///   configId: 'prebid-demo-banner-320-50',
///   width: 320,
///   height: 50,
///   listener: PrebidBannerAdListener(onAdLoaded: () {}),
/// );
/// await ad.load();
/// // In the list item:
/// PrebidPreloadedBannerAdView(ad: ad);
/// // When the screen goes away:
/// await ad.destroy();
/// ```
///
/// The banner shows in one view at a time: a view built later takes it over
/// from the one showing it, which goes empty.
class PrebidPreloadedBannerAd {
  /// Creates a banner; nothing is requested until [load]. The parameters are
  /// those of [PrebidBannerAd].
  PrebidPreloadedBannerAd({
    required this.configId,
    required this.width,
    required this.height,
    this.additionalSizes,
    this.isVideo = false,
    this.adFormats,
    this.pbAdSlot,
    this.gpid,
    this.adPosition,
    this.videoParameters,
    this.impOrtbConfig,
    this.globalOrtbConfig,
    this.refreshIntervalSeconds,
    this.videoPlacementType,
    this.listener,
    this.videoListener,
  }) : _size = ValueNotifier(Size(width.toDouble(), height.toDouble()));

  /// The platform API; replaced in tests.
  @visibleForTesting
  static BannerAdHostApi api = BannerAdHostApi();

  /// See [PrebidBannerAd.configId].
  final String configId;

  /// See [PrebidBannerAd.width].
  final int width;

  /// See [PrebidBannerAd.height].
  final int height;

  /// See [PrebidBannerAd.additionalSizes].
  final List<Size>? additionalSizes;

  /// See [PrebidBannerAd.isVideo].
  final bool isVideo;

  /// See [PrebidBannerAd.adFormats].
  final Set<PrebidAdFormat>? adFormats;

  /// See [PrebidBannerAd.pbAdSlot].
  final String? pbAdSlot;

  /// See [PrebidBannerAd.gpid].
  final String? gpid;

  /// See [PrebidBannerAd.adPosition].
  final PrebidAdPosition? adPosition;

  /// See [PrebidBannerAd.videoParameters].
  final VideoParameters? videoParameters;

  /// See [PrebidBannerAd.impOrtbConfig].
  final String? impOrtbConfig;

  /// See [PrebidBannerAd.globalOrtbConfig].
  final String? globalOrtbConfig;

  /// See [PrebidBannerAd.refreshIntervalSeconds]. Prebid refreshes the
  /// banner only while it is on screen.
  final int? refreshIntervalSeconds;

  /// See [PrebidBannerAd.videoPlacementType].
  final VideoPlacementType? videoPlacementType;

  /// Listener for banner ad events.
  final PrebidBannerAdListener? listener;

  /// Listener for video playback events (outstream video creatives).
  final PrebidBannerVideoListener? videoListener;

  final ValueNotifier<Size> _size;

  /// Bumped when the native banner is created or destroyed, so views pick
  /// up the current one.
  final ValueNotifier<int> _revision = ValueNotifier(0);

  /// The channel and creation of the current native banner; null before
  /// [load] and after [destroy].
  AdViewChannel? _channel;
  Future<void>? _created;

  /// The winning bid of the last load, for analytics; null before the first
  /// load and when the last one had no bid.
  PrebidWinningBid? get winningBid => _winningBid;
  PrebidWinningBid? _winningBid;

  /// The slot size: [width] x [height] until the native SDK reports the
  /// rendered creative's size (a multisize banner can win a larger one).
  Size get size => _size.value;

  /// Runs the auction and renders the winning creative off screen; calling
  /// it again reloads the banner, and after [destroy] it starts afresh.
  Future<void> load() {
    final created = _created;
    final channel = _channel;
    if (created != null && channel != null) {
      return created.then(
        (_) => channel.methodChannel.invokeMethod<void>('loadAd'),
      );
    }
    final fresh = AdViewChannel(_viewType, _onCall);
    _channel = fresh;
    // The native banner loads once created.
    final creating = _created = api.create(
      fresh.id,
      bannerConfig(
        configId: configId,
        width: width,
        height: height,
        isVideo: isVideo,
        autoLoad: true,
        additionalSizes: additionalSizes,
        refreshIntervalSeconds: refreshIntervalSeconds,
        adFormats: adFormats,
        pbAdSlot: pbAdSlot,
        adPosition: adPosition,
        videoParameters: videoParameters,
        impOrtbConfig: impOrtbWithGpid(impOrtbConfig, gpid),
        globalOrtbConfig: globalOrtbConfig,
        videoPlacementType: videoPlacementType,
      ),
    );
    _revision.value++;
    return creating;
  }

  /// Stops auto-refresh. Does nothing without a loaded banner.
  Future<void> stopRefresh() async {
    final created = _created;
    final channel = _channel;
    if (created == null || channel == null) return;
    await created;
    await channel.methodChannel.invokeMethod<void>('stopRefresh');
  }

  /// Destroys the native banner; a view showing it goes empty until the
  /// next [load].
  Future<void> destroy() async {
    final created = _created;
    final channel = _channel;
    if (created == null || channel == null) return;
    _created = null;
    _channel = null;
    channel.dispose();
    _winningBid = null;
    _size.value = Size(width.toDouble(), height.toDouble());
    _revision.value++;
    try {
      await created;
    } on Object {
      return; // Never created natively: nothing to destroy.
    }
    await api.destroy(channel.id);
  }

  Future<void> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'onAdSize':
        final args = call.arguments as Map?;
        final w = (args?['width'] as num?)?.toDouble();
        final h = (args?['height'] as num?)?.toDouble();
        // As AdViewState: a report without a positive height is dropped.
        if (h == null || h <= 0 || (w != null && w <= 0)) return;
        _size.value = Size(w ?? _size.value.width, h);
      case 'onAdLoaded':
        _winningBid = PrebidWinningBid.fromPayload(call.arguments);
        dispatchBannerEvent(listener, videoListener, call);
      default:
        dispatchBannerEvent(listener, videoListener, call);
    }
  }
}

/// Shows a [PrebidPreloadedBannerAd], at the size the banner reports.
///
/// The slot stays empty until the banner is loaded. Removing the view keeps
/// the banner loaded, for this view or another one to show again.
class PrebidPreloadedBannerAdView extends StatefulWidget {
  /// Creates a view of [ad].
  const PrebidPreloadedBannerAdView({super.key, required this.ad});

  /// The banner to show.
  final PrebidPreloadedBannerAd ad;

  @override
  State<PrebidPreloadedBannerAdView> createState() =>
      _PrebidPreloadedBannerAdViewState();
}

class _PrebidPreloadedBannerAdViewState
    extends State<PrebidPreloadedBannerAdView> {
  /// The native banner creation this view shows once it completes: the
  /// platform view looks the banner up, so it must exist first.
  Future<void>? _creation;
  bool _created = false;

  void _follow(Future<void>? creation) {
    if (identical(creation, _creation)) return;
    _creation = creation;
    _created = false;
    creation?.then((_) {
      if (mounted && identical(_creation, creation)) {
        setState(() => _created = true);
      }
    }, onError: (Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    return ListenableBuilder(
      listenable: Listenable.merge([ad._size, ad._revision]),
      builder: (context, _) {
        _follow(ad._created);
        final channel = ad._channel;
        return SizedBox.fromSize(
          size: ad.size,
          child: _created && channel != null
              ? adPlatformView(
                  key: ValueKey(channel.id),
                  viewType: _viewType,
                  creationParams: {'channelId': channel.id, 'preloaded': true},
                )
              : null,
        );
      },
    );
  }
}
