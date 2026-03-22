/// Ad format types supported by Prebid Mobile.
///
/// Used with [PrebidInterstitialAd.adFormats] and [PrebidBannerAd.isVideo]
/// to specify the desired creative type for an ad request.
enum AdFormat {
  /// HTML display ad format (standard banner or interstitial).
  banner,

  /// VAST / outstream video ad format.
  video,
}

/// Log level for Prebid Mobile SDK output.
///
/// Controls the verbosity of diagnostic messages from the SDK.
/// Use [PrebidMobile.setLogLevel] to configure.
///
/// Levels are ordered from most verbose ([debug]) to least verbose ([severe]).
enum PrebidLogLevel {
  /// Most verbose. Logs all SDK internal messages including request/response details.
  debug,

  /// Detailed information useful for debugging bidding flows.
  verbose,

  /// General informational messages about SDK lifecycle events.
  info,

  /// Potential issues that may affect ad delivery.
  warn,

  /// Errors that may impact functionality (failed requests, parse errors).
  error,

  /// Critical errors only (SDK crashes, unrecoverable states).
  severe,
}

/// SDK initialization status returned by [PrebidMobile.initializeSdk].
///
/// The [completion] callback receives one of these values along with an
/// optional error message.
enum InitializationStatus {
  /// SDK initialized successfully and is ready to serve ads.
  succeeded,

  /// Initialization failed. Check the error message for details.
  failed,

  /// Connected to Prebid Server but the server returned a warning status.
  /// Ad serving may still work, but some features might be limited.
  serverStatusWarning,
}

/// Video placement type for banner video ads.
///
/// Specifies where the outstream video will appear relative to the
/// surrounding content.
enum VideoPlacementType {
  /// Video rendered within a standard banner placement.
  inBanner,

  /// Video rendered within article content (read-along).
  inArticle,

  /// Video rendered within a content feed.
  inFeed,
}
