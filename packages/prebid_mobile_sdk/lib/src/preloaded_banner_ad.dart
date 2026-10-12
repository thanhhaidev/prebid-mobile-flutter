import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'ad_enums.dart';
import 'ad_listener.dart';
import 'banner_ad.dart';
import 'companion/ad_view_state.dart';
import 'companion/preloaded_banner.dart';
import 'generated/prebid_api.g.dart';
import 'internal/ortb.dart';
import 'internal/session.dart';
import 'video_parameters.dart';

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
  });

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

  late final PreloadedBanner _banner = PreloadedBanner(
    viewType: 'prebid_mobile_sdk/banner_ad',
    size: Size(width.toDouble(), height.toDouble()),
    create: (channelId) {
      // A restarted isolate's channel ids collide with the old banners'.
      releasePreviousIsolateAds();
      return api.create(
        channelId,
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
    },
    destroy: api.destroy,
    onEvent: _onEvent,
  );

  /// The winning bid of the last load, for analytics; null before the first
  /// load and when the last one had no bid.
  PrebidWinningBid? get winningBid => _winningBid;
  PrebidWinningBid? _winningBid;

  /// The slot size: [width] x [height] until the native SDK reports the
  /// rendered creative's size (a multisize banner can win a larger one).
  Size get size => _banner.size;

  /// Runs the auction and renders the winning creative off screen; calling
  /// it again reloads the banner, and after [destroy] it starts afresh.
  Future<void> load() => _banner.load();

  /// Stops auto-refresh. Does nothing without a loaded banner.
  Future<void> stopRefresh() => _banner.stopRefresh();

  /// Destroys the native banner; a view showing it goes empty until the
  /// next [load].
  Future<void> destroy() {
    _winningBid = null;
    return _banner.destroy();
  }

  void _onEvent(MethodCall call) {
    _winningBid = switch (call.method) {
      'onAdLoaded' => PrebidWinningBid.fromPayload(call.arguments),
      'onAdFailed' => null,
      _ => _winningBid,
    };
    dispatchBannerEvent(listener, videoListener, call);
  }
}

/// Shows a [PrebidPreloadedBannerAd], at the size the banner reports.
///
/// The slot stays empty until the banner is loaded. Removing the view keeps
/// the banner loaded, for this view or another one to show again.
class PrebidPreloadedBannerAdView extends StatelessWidget {
  /// Creates a view of [ad].
  const PrebidPreloadedBannerAdView({super.key, required this.ad});

  /// The banner to show.
  final PrebidPreloadedBannerAd ad;

  @override
  Widget build(BuildContext context) => PreloadedBannerView(banner: ad._banner);
}
