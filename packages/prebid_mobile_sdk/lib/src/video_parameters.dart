import 'generated/prebid_api.g.dart';

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
///   plcmt: VideoPlcmt.accompanyingContent,
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

  /// Placement type for the video impression (`imp.video.placement`).
  ///
  /// Deprecated in OpenRTB 2.6 in favour of [plcmt]; buyers increasingly
  /// read only `plcmt`.
  final VideoPlacement? placement;

  /// OpenRTB 2.6 placement subtype (`imp.video.plcmt`).
  final VideoPlcmt? plcmt;

  /// Start delay in seconds, or one of [VideoStartDelay]'s values for
  /// pre-roll / generic mid-roll / generic post-roll.
  final int? startDelay;

  /// Linear (in-stream) or non-linear (overlay).
  final VideoLinearity? linearity;

  /// Whether the player allows the video to be skipped.
  final bool? skippable;

  /// Blocked creative attributes (`battr`).
  final List<VideoCreativeAttribute>? battr;

  /// Minimum bitrate in Kbps.
  final int? minBitrate;

  /// Maximum bitrate in Kbps.
  final int? maxBitrate;

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
    this.plcmt,
    this.startDelay,
    this.linearity,
    this.skippable,
    this.battr,
    this.minBitrate,
    this.maxBitrate,
  });

  /// The Pigeon config sent to the native SDKs.
  VideoParametersConfig toConfig() => VideoParametersConfig(
    mimes: mimes,
    protocols: protocols?.map((p) => p.value).toList(),
    playbackMethods: playbackMethods?.map((m) => m.value).toList(),
    placement: placement?.value,
    maxDuration: maxDuration,
    minDuration: minDuration,
    api: api?.map((a) => a.value).toList(),
    plcmt: plcmt?.value,
    startDelay: startDelay,
    linearity: linearity?.value,
    skippable: skippable,
    battr: battr?.map((a) => a.value).toList(),
    minBitrate: minBitrate,
    maxBitrate: maxBitrate,
  );

  /// Method-channel payload, for the GAM / AdMob / MAX companion packages.
  Map<String, Object> toMap() => {
    'mimes': mimes,
    'protocols': ?protocols?.map((p) => p.value).toList(),
    'playbackMethods': ?playbackMethods?.map((m) => m.value).toList(),
    'placement': ?placement?.value,
    'maxDuration': ?maxDuration,
    'minDuration': ?minDuration,
    'api': ?api?.map((a) => a.value).toList(),
    'plcmt': ?plcmt?.value,
    'startDelay': ?startDelay,
    'linearity': ?linearity?.value,
    'skippable': ?skippable,
    'battr': ?battr?.map((a) => a.value).toList(),
    'minBitrate': ?minBitrate,
    'maxBitrate': ?maxBitrate,
  };
}

/// OpenRTB 2.6 video placement subtypes (`plcmt`).
enum VideoPlcmt {
  /// Pre-, mid- or post-roll played with streaming content.
  instream(1),

  /// Played alongside content the user is consuming (e.g. outstream in an
  /// article or feed).
  accompanyingContent(2),

  /// Interstitial: covers the content, played without content.
  interstitial(3),

  /// No content / standalone (e.g. a video in a banner slot).
  noContent(4);

  const VideoPlcmt(this.value);

  /// The OpenRTB `plcmt` value.
  final int value;
}

/// Named [VideoParameters.startDelay] values; positive values are seconds.
abstract final class VideoStartDelay {
  /// Pre-roll.
  static const preRoll = 0;

  /// Generic mid-roll.
  static const genericMidRoll = -1;

  /// Generic post-roll.
  static const genericPostRoll = -2;
}

/// Video linearity.
enum VideoLinearity {
  /// Linear / in-stream.
  linear(1),

  /// Non-linear / overlay.
  nonLinear(2);

  const VideoLinearity(this.value);

  /// The OpenRTB `linearity` value.
  final int value;
}

/// OpenRTB creative attributes, used to block creatives via `battr`.
enum VideoCreativeAttribute {
  /// Audio ad (autoplay).
  audioAdAutoplay(1),

  /// Audio ad (user initiated).
  audioAdUserInitiated(2),

  /// Expandable (automatic).
  expandableAutomatic(3),

  /// Expandable (user initiated - click).
  expandableClick(4),

  /// Expandable (user initiated - rollover).
  expandableRollover(5),

  /// In-banner video ad (autoplay).
  inBannerAutoplay(6),

  /// In-banner video ad (user initiated).
  inBannerUserInitiated(7),

  /// Pop (e.g., over, under, or upon exit).
  pop(8),

  /// Provocative or suggestive imagery.
  provocative(9),

  /// Shaky, flashing, flickering, extreme animation, smileys.
  annoying(10),

  /// Surveys.
  surveys(11),

  /// Text only.
  textOnly(12),

  /// User interactive (e.g., embedded games).
  userInteractive(13),

  /// Windows dialog or alert style.
  windowsDialogOrAlert(14),

  /// Has audio on/off button.
  hasAudioOnOffButton(15),

  /// Ad provides skip button (e.g. VPAID-rendered skip button on pre-roll).
  adCanBeSkipped(16),

  /// Adobe Flash.
  flash(17);

  const VideoCreativeAttribute(this.value);

  /// The OpenRTB creative attribute ID.
  final int value;
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
