/// Ad format types supported by Prebid Mobile.
enum AdFormat {
  banner,
  video,
}

/// Log level for Prebid SDK output.
enum PrebidLogLevel {
  debug,
  verbose,
  info,
  warn,
  error,
  severe,
}

/// SDK initialization status.
enum InitializationStatus {
  succeeded,
  failed,
  serverStatusWarning,
}

/// Video placement type for banner video ads.
enum VideoPlacementType {
  inBanner,
  inArticle,
  inFeed,
}
