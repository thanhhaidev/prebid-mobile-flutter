import 'dart:async';

import 'package:flutter/material.dart';
import 'package:interactive_media_ads/interactive_media_ads.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:video_player/video_player.dart';

import '../../demo_screen.dart';

/// Prebid's `Util.generateInstreamUriForGam`, ported as is: the Google Ad
/// Manager VAST ad tag for [adUnit] and [sizes] (640x480 or 400x300 only)
/// with the Prebid keywords as `cust_params`.
String generateInstreamUriForGam(
  String adUnit,
  List<Size> sizes,
  Map<String, String>? prebidKeywords,
) {
  if (adUnit.isEmpty) throw ArgumentError('adUnit should not be empty');
  if (sizes.isEmpty) throw ArgumentError('sizes should not be empty');
  final sz = sizes
      .map((s) {
        final w = s.width.round();
        final h = s.height.round();
        if (!(w == 640 && h == 480) && !(w == 400 && h == 300)) {
          throw ArgumentError('size should be either 640x480 or 400x300');
        }
        return '${w}x$h';
      })
      .join('|');
  var uri =
      'https://pubads.g.doubleclick.net/gampad/ads?sz=$sz&iu=$adUnit'
      '&impl=s&gdfp_req=1&env=vp&output=xml_vast4&unviewed_position_start=1';
  if (prebidKeywords != null) {
    uri += '&cust_params=';
    prebidKeywords.forEach((key, value) => uri += '$key%3D$value%26');
  }
  return uri;
}

/// A2v — "Instream Video (GAM Original)" and its "New API" twin
/// (`GamOriginalInstream(NewApi)Fragment`).
///
/// While open the screen uses account `1001` on the Rubicon Prebid Server
/// (the demo framework applies and restores both). On open: the Prebid
/// in-stream auction (`1001-1`, 640x480, mp4, VAST 2.0, auto-play muted,
/// in-stream placement — `plcmt` for the New API), then the content video
/// plays with a GAM pre-roll requested through the IMA SDK with the winning
/// keywords. Load / Stop refresh are present but not wired, as the original;
/// its rows never fire.
class InstreamScreen extends DemoScreen {
  const InstreamScreen({super.key, required super.item});

  @override
  State<InstreamScreen> createState() => _InstreamScreenState();
}

class _InstreamScreenState extends DemoScreenState<InstreamScreen> {
  static const _content =
      'https://storage.googleapis.com/gvabox/media/samples/stock.mp4';

  late final events = EventCounters([
    'onAdLoaded called',
    'onAdDisplayed called',
    'onAdFailed called',
    'onAdClicked called',
    'onAdClosed called',
    'onAdExpired',
  ], tag: 'In-stream');

  late final VideoPlayerController _video = VideoPlayerController.networkUrl(
    Uri.parse(_content),
  );
  final _progress = ContentProgressProvider();
  AdsLoader? _loader;
  AdsManager? _manager;
  Timer? _progressTimer;
  String? _adTagUrl;
  bool _showContent = false;

  VideoParameters get _videoParameters =>
      item.videoParameters ??
      VideoParameters(
        mimes: const ['video/mp4'],
        protocols: const [VideoProtocol.vast2_0],
        playbackMethods: const [VideoPlaybackMethod.autoPlaySoundOff],
        placement: item.has(DemoFlag.newApi) ? null : VideoPlacement.inStream,
        plcmt: item.has(DemoFlag.newApi) ? VideoPlcmt.instream : null,
      );

  @override
  Future<void> startAd() async {
    await _video.initialize();
    _video.addListener(() {
      if (_video.value.isCompleted) _loader?.contentComplete();
    });
    final ad = PrebidInstreamVideoAd(
      configId: config.configId,
      size: const Size(640, 480),
      videoParameters: _videoParameters,
    );
    final response = await ad.fetchDemand();
    if (!mounted) return;
    setState(() {
      _adTagUrl = generateInstreamUriForGam(item.adUnitId ?? '', const [
        Size(640, 480),
      ], response.targetingKeywords);
    });
  }

  late final AdDisplayContainer _container = AdDisplayContainer(
    onContainerAdded: (container) {
      _loader = AdsLoader(
        container: container,
        onAdsLoaded: (data) {
          final manager = _manager = data.manager;
          manager.setAdsManagerDelegate(
            AdsManagerDelegate(
              onAdEvent: (event) {
                switch (event.type) {
                  case AdEventType.loaded:
                    manager.start();
                  case AdEventType.contentPauseRequested:
                    _pauseContent();
                  case AdEventType.contentResumeRequested:
                    _resumeContent();
                  case AdEventType.allAdsCompleted:
                    manager.destroy();
                    _manager = null;
                  case _:
                }
              },
              onAdErrorEvent: (_) => _resumeContent(),
            ),
          );
          manager.init();
        },
        onAdsLoadError: (_) => _resumeContent(),
      );
      final url = _adTagUrl;
      if (url != null) {
        _loader!.requestAds(
          AdsRequest(adTagUrl: url, contentProgressProvider: _progress),
        );
      } else {
        _resumeContent();
      }
    },
  );

  Future<void> _resumeContent() async {
    if (!mounted) return;
    setState(() => _showContent = true);
    _progressTimer ??= Timer.periodic(const Duration(milliseconds: 200), (
      _,
    ) async {
      final position = await _video.position;
      if (position != null) {
        await _progress.setProgress(
          progress: position,
          duration: _video.value.duration,
        );
      }
    });
    await _video.play();
  }

  Future<void> _pauseContent() async {
    if (!mounted) return;
    setState(() => _showContent = false);
    _progressTimer?.cancel();
    _progressTimer = null;
    await _video.pause();
  }

  @override
  void destroyAd() {
    _progressTimer?.cancel();
    _manager?.destroy();
    _video.dispose();
  }

  @override
  Widget buildDemo(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SizedBox(
          height: 300,
          child: _adTagUrl == null || !_video.value.isInitialized
              ? const SizedBox.shrink()
              : Stack(
                  children: [
                    _container,
                    if (_showContent)
                      Center(
                        child: AspectRatio(
                          aspectRatio: _video.value.aspectRatio,
                          child: VideoPlayer(_video),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        AdUnitIdLabel(config.configId),
        const SizedBox(height: 12),
        // Present but not wired, as the original.
        const DemoButtonRow(
          children: [DemoButton('Load'), DemoButton('Stop refresh')],
        ),
        const SizedBox(height: 16),
        EventCounterList(counters: events),
      ],
    );
  }
}
