import 'dart:ui' show Size;

/// Corner for the fullscreen close / skip buttons.
enum PrebidButtonPosition {
  /// Top-left corner.
  topLeft,

  /// Top-right corner (Prebid's default).
  topRight,
}

/// Rendering controls for Prebid-rendered fullscreen ads (interstitial and
/// rewarded), mirroring the Prebid SDK's ad-unit setters.
///
/// Every field is optional; `null` keeps the SDK default.
///
/// ```dart
/// PrebidInterstitialAd(
///   configId: 'prebid-demo-video-interstitial-320-480',
///   adFormats: {PrebidAdFormat.video},
///   controls: const PrebidFullscreenControls(
///     closeButtonPosition: PrebidButtonPosition.topLeft,
///     skipDelay: 5,
///     isMuted: true,
///     isSoundButtonVisible: true,
///   ),
/// );
/// ```
///
/// Platform notes: the skip options apply to interstitials on both platforms
/// and to rewarded ads on Android only; [isAutoCloseOnCompletionEnabled] is
/// iOS only; [minSizePercentage] applies to interstitials only.
class PrebidFullscreenControls {
  /// Creates [PrebidFullscreenControls].
  const PrebidFullscreenControls({
    this.closeButtonArea,
    this.closeButtonPosition,
    this.skipButtonArea,
    this.skipButtonPosition,
    this.skipDelay,
    this.isMuted,
    this.isSoundButtonVisible,
    this.isAutoCloseOnCompletionEnabled,
    this.minSizePercentage,
    this.supportSKOverlay,
  });

  /// Close button size as a fraction of the screen, `0..1`.
  final double? closeButtonArea;

  /// Corner of the close button.
  final PrebidButtonPosition? closeButtonPosition;

  /// Skip button size as a fraction of the screen, `0..1`.
  final double? skipButtonArea;

  /// Corner of the skip button.
  final PrebidButtonPosition? skipButtonPosition;

  /// Seconds before the skip button appears on a video ad.
  final int? skipDelay;

  /// Whether video starts muted.
  final bool? isMuted;

  /// Whether the mute / unmute button is shown on video.
  final bool? isSoundButtonVisible;

  /// Whether the ad closes itself when the video completes (iOS only).
  final bool? isAutoCloseOnCompletionEnabled;

  /// Minimum creative size as a percentage of the screen (width, height in
  /// `0..100`). Interstitials only.
  final Size? minSizePercentage;

  /// iOS only: present an SKOverlay (App Store sheet) for SKAdNetwork ads.
  final bool? supportSKOverlay;

  /// The method-channel form sent by the GAM / AdMob / MAX companion
  /// packages. Unset fields are omitted; the min size is sent as
  /// `minWidthPercentage` / `minHeightPercentage`.
  Map<String, Object?> toMap() => {
    'closeButtonArea': ?closeButtonArea,
    'closeButtonPosition': ?closeButtonPosition?.name,
    'skipButtonArea': ?skipButtonArea,
    'skipButtonPosition': ?skipButtonPosition?.name,
    'skipDelay': ?skipDelay,
    'isMuted': ?isMuted,
    'isSoundButtonVisible': ?isSoundButtonVisible,
    'isAutoCloseOnCompletionEnabled': ?isAutoCloseOnCompletionEnabled,
    'minWidthPercentage': ?minSizePercentage?.width.round(),
    'minHeightPercentage': ?minSizePercentage?.height.round(),
    'supportSKOverlay': ?supportSKOverlay,
  };
}
