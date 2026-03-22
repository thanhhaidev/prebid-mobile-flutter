/// Exception thrown by Prebid Mobile SDK operations.
class PrebidException implements Exception {
  /// The error code identifying the type of error.
  final PrebidErrorCode code;

  /// A human-readable description of the error.
  final String message;

  /// Optional underlying error details from the native SDK.
  final String? details;

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
enum PrebidErrorCode {
  /// SDK initialization failed.
  initializationFailed,

  /// Invalid or missing arguments provided.
  invalidArguments,

  /// Ad failed to load.
  adLoadFailed,

  /// Ad not found (e.g., trying to show a destroyed ad).
  adNotFound,

  /// Ad failed to display.
  adDisplayFailed,

  /// Network request failed.
  networkError,

  /// Server returned an error.
  serverError,

  /// The operation timed out.
  timeout,

  /// An unknown error occurred.
  unknown,
}
