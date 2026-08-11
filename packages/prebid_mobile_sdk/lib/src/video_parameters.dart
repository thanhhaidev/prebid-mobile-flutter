/// Video parameters for OpenRTB video ad configuration.
///
/// Used with [PrebidInterstitialAd], [PrebidMultiformatAd], and
/// [PrebidInstreamVideoAd] to specify detailed video ad requirements.
///
/// ## Example
///
/// ```dart
/// final videoParams = VideoParameters(
///   mimes: ['video/mp4', 'video/x-ms-wmv'],
///   protocols: [VideoProtocol.vast2_0, VideoProtocol.vast3_0],
///   playbackMethods: [VideoPlaybackMethod.autoPlaySoundOff],
///   placement: VideoPlacement.inBanner,
///   maxDuration: 30,
/// );
/// ```
class VideoParameters {
  /// Supported content MIME types (e.g., `["video/mp4"]`).
  final List<String> mimes;

  /// Supported VAST protocol versions.
  final List<VideoProtocol>? protocols;

  /// How the video ad should play.
  final List<VideoPlaybackMethod>? playbackMethods;

  /// Placement type for the video impression.
  final VideoPlacement? placement;

  /// Maximum video duration in seconds.
  final int? maxDuration;

  /// Minimum video duration in seconds.
  final int? minDuration;

  /// Supported API frameworks (e.g., VPAID, MRAID).
  final List<VideoApi>? api;

  /// Creates a [VideoParameters] configuration.
  const VideoParameters({
    required this.mimes,
    this.protocols,
    this.playbackMethods,
    this.placement,
    this.maxDuration,
    this.minDuration,
    this.api,
  });
}

/// VAST protocol versions for video ads.
enum VideoProtocol {
  /// VAST 1.0.
  vast1_0(1),

  /// VAST 2.0.
  vast2_0(2),

  /// VAST 3.0.
  vast3_0(3),

  /// VAST 1.0 Wrapper.
  vast1_0Wrapper(4),

  /// VAST 2.0 Wrapper.
  vast2_0Wrapper(5),

  /// VAST 3.0 Wrapper.
  vast3_0Wrapper(6),

  /// VAST 4.0.
  vast4_0(7),

  /// VAST 4.0 Wrapper.
  vast4_0Wrapper(8);

  const VideoProtocol(this.value);

  /// The OpenRTB protocol ID.
  final int value;
}

/// Video playback methods per OpenRTB spec.
enum VideoPlaybackMethod {
  /// Initiates on page load with sound on.
  autoPlaySoundOn(1),

  /// Initiates on page load with sound off by default.
  autoPlaySoundOff(2),

  /// Initiates on click with sound on.
  clickToPlay(3),

  /// Initiates on mouse-over with sound on.
  mouseOver(4),

  /// Initiates on entering viewport with sound on.
  enterSoundOn(5),

  /// Initiates on entering viewport with sound off by default.
  enterSoundOff(6);

  const VideoPlaybackMethod(this.value);

  /// The OpenRTB playback method ID.
  final int value;
}

/// Video placement type per OpenRTB spec.
enum VideoPlacement {
  /// In-stream (pre-roll, mid-roll, post-roll).
  inStream(1),

  /// In-banner (plays within a standard banner slot).
  inBanner(2),

  /// In-article (plays between paragraphs of editorial content).
  inArticle(3),

  /// In-feed (plays within a content feed).
  inFeed(4),

  /// Interstitial/Slider/Floating.
  interstitial(5);

  const VideoPlacement(this.value);

  /// The OpenRTB placement type ID.
  final int value;
}

/// API frameworks supported by the video player.
enum VideoApi {
  /// VPAID 1.0.
  vpaid1_0(1),

  /// VPAID 2.0.
  vpaid2_0(2),

  /// MRAID 1.
  mraid1(3),

  /// ORMMA.
  ormma(4),

  /// MRAID 2.
  mraid2(5),

  /// MRAID 3.
  mraid3(6),

  /// OMID 1.
  omid1(7);

  const VideoApi(this.value);

  /// The OpenRTB API framework ID.
  final int value;
}
