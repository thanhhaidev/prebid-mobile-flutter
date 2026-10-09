// Conversions from the public API types to the Pigeon-generated messages.
//
// Not exported from `package:prebid_mobile_sdk/prebid_mobile_sdk.dart`: the
// generated types are an implementation detail of the platform channel and
// may change between releases without a breaking change to the public API.

import '../fullscreen_controls.dart';
import '../generated/prebid_api.g.dart';
import '../native_ad.dart';
import '../video_parameters.dart';

/// Pigeon form of [VideoParameters].
extension VideoParametersPigeon on VideoParameters {
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
}

/// Pigeon form of [PrebidFullscreenControls].
extension FullscreenControlsPigeon on PrebidFullscreenControls {
  /// The Pigeon config sent to the core plugin.
  FullscreenControlsConfig toConfig() => FullscreenControlsConfig(
    closeButtonArea: closeButtonArea,
    closeButtonPosition: closeButtonPosition?.name,
    skipButtonArea: skipButtonArea,
    skipButtonPosition: skipButtonPosition?.name,
    skipDelay: skipDelay,
    isMuted: isMuted,
    isSoundButtonVisible: isSoundButtonVisible,
    isAutoCloseOnCompletionEnabled: isAutoCloseOnCompletionEnabled,
    minWidthPercentage: minSizePercentage?.width.round(),
    minHeightPercentage: minSizePercentage?.height.round(),
    supportSKOverlay: supportSKOverlay,
  );
}

/// Pigeon form of [NativeAsset].
extension NativeAssetPigeon on NativeAsset {
  /// The Pigeon config sent to the core plugin.
  NativeAssetConfig toConfig() => NativeAssetConfig(
    assetType: type.name,
    required_: required,
    titleLength: titleLength,
    imageType: imageType?.value,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    imageWidthMin: imageWidthMin,
    imageHeightMin: imageHeightMin,
    dataType: dataType?.value,
    dataLength: dataLength,
  );
}

/// Pigeon form of [NativeEventTracker].
extension NativeEventTrackerPigeon on NativeEventTracker {
  /// The Pigeon config sent to the core plugin.
  NativeEventTrackerConfig toConfig() => NativeEventTrackerConfig(
    eventType: eventType.value,
    methods: methods.map((m) => m.value).toList(),
  );
}

/// Converts a Pigeon string map with nullable keys / values into a plain
/// `Map<String, String>`, dropping null entries.
Map<String, String>? stringMap(Map<String?, String?>? map) => map == null
    ? null
    : {
        for (final e in map.entries)
          if (e.key != null && e.value != null) e.key!: e.value!,
      };
