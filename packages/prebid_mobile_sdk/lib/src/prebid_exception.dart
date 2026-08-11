/// Exception thrown by Prebid Mobile SDK operations.
///
/// Encapsulates errors from native Android/iOS SDK calls with a typed
/// [PrebidErrorCode], a human-readable [message], and optional [details].
///
/// ```dart
/// try {
///   await interstitial.loadAd();
/// } on PrebidException catch (e) {
///   debugPrint('Error ${e.code}: ${e.message}');
///   if (e.details != null) debugPrint('Details: ${e.details}');
/// }
/// ```
class PrebidException implements Exception {
  /// The error code identifying the type of error.
  ///
  /// Use this to programmatically handle different error conditions.
  final PrebidErrorCode code;

  /// A human-readable description of the error.
  final String message;

  /// Optional underlying error details from the native SDK.
  ///
  /// May contain stack traces, error codes, or diagnostic information
  /// from the Android or iOS Prebid SDK.
  final String? details;

  /// Creates a [PrebidException].
  const PrebidException({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() =>
      'PrebidException($code): $message'
      '${details != null ? ' ($details)' : ''}';
}

/// Error codes for Prebid Mobile SDK operations.
///
/// Each value maps to a specific category of failure that can occur during
/// SDK initialization, ad loading, or ad display.
enum PrebidErrorCode {
  /// The SDK failed to initialize.
  ///
  /// Common causes: invalid server URL, network unavailable, or
  /// invalid account ID.
  initializationFailed,

  /// Invalid or missing arguments were provided to an SDK method.
  invalidArguments,

  /// The ad request failed to return a valid ad.
  ///
  /// This can happen due to no fill, invalid config ID, or server-side issues.
  adLoadFailed,

  /// Attempted to show or destroy an ad that does not exist.
  ///
  /// This typically occurs when calling [PrebidInterstitialAd.show] before
  /// [PrebidInterstitialAd.loadAd], or after [PrebidInterstitialAd.destroy].
  adNotFound,

  /// The ad was loaded but could not be displayed.
  ///
  /// May occur if the ad creative is invalid or the rendering engine encounters
  /// an error.
  adDisplayFailed,

  /// A network request failed (DNS resolution, connection refused, etc.).
  networkError,

  /// Prebid Server returned an HTTP error (4xx or 5xx).
  serverError,

  /// The operation exceeded the configured timeout duration.
  ///
  /// Increase the timeout via [PrebidMobile.setTimeoutMillis] if this
  /// occurs frequently.
  timeout,

  /// An unclassified error occurred.
  ///
  /// Check [PrebidException.details] for more information.
  unknown,
}
