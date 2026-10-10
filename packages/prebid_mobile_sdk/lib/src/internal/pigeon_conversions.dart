// Conversions from the public API types to the Pigeon-generated messages.
//
// Not exported from `package:prebid_mobile_sdk/prebid_mobile_sdk.dart`: the
// generated types are an implementation detail of the platform channel and
// may change between releases without a breaking change to the public API.

import 'dart:convert';

import '../external_user_id.dart';
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
    width: size?.width.round(),
    height: size?.height.round(),
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
    imageMimes: imageMimes,
    ext: _json(ext),
    assetExt: _json(assetExt),
  );
}

/// Pigeon form of [NativeEventTracker].
extension NativeEventTrackerPigeon on NativeEventTracker {
  /// The Pigeon config sent to the core plugin.
  NativeEventTrackerConfig toConfig() => NativeEventTrackerConfig(
    eventType: eventType.value,
    methods: methods.map((m) => m.value).toList(),
    ext: _json(ext),
  );
}

String? _json(Map<String, Object?>? map) =>
    map == null ? null : jsonEncode(map);

/// Converts a Pigeon string map with nullable keys / values into a plain
/// `Map<String, String>`, dropping null entries.
Map<String, String>? stringMap(Map<String?, String?>? map) => map == null
    ? null
    : {
        for (final e in map.entries)
          if (e.key != null && e.value != null) e.key!: e.value!,
      };

/// Pigeon form of [ExternalUserId].
ExternalUserIdData externalUserIdToData(ExternalUserId id) =>
    ExternalUserIdData(
      source: id.source,
      uids: [
        for (final uid in id.uids)
          UserUniqueIdData(id: uid.id, atype: uid.atype, ext: uid.ext),
      ],
      ext: id.ext,
      inserter: id.inserter,
      matcher: id.matcher,
      mm: id.mm,
    );

/// [ExternalUserId] from its Pigeon form; null when it carries no uid.
ExternalUserId? externalUserIdFromData(ExternalUserIdData data) {
  final uids = [
    for (final uid in data.uids.nonNulls)
      UserUniqueId(id: uid.id, atype: uid.atype, ext: _stringKeys(uid.ext)),
  ];
  if (uids.isEmpty) return null;
  return ExternalUserId.withUids(
    source: data.source,
    uids: uids,
    ext: _stringKeys(data.ext),
    inserter: data.inserter,
    matcher: data.matcher,
    mm: data.mm,
  );
}

Map<String, Object?>? _stringKeys(Map<String?, Object?>? map) =>
    map?.map((k, v) => MapEntry(k ?? '', v));
