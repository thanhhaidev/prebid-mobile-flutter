import 'dart:convert';

import 'native_ad.dart';
import 'native_ad_enums.dart';

/// The native request of an ad (OpenRTB Native 1.2): the assets to ask for,
/// the event trackers, where the ad appears and the request options.
///
/// Every native ad takes one, through `nativeParameters`: [PrebidNativeAd],
/// the Original API's `PrebidNativeAdUnit` and `PrebidMultiformatAd`, and the
/// GAM, AdMob and MAX native ads.
///
/// ```dart
/// const parameters = NativeParameters(
///   assets: [
///     NativeAsset.title(length: 90, required: true),
///     NativeAsset.image(imageType: NativeImageType.main, required: true),
///     NativeAsset.data(dataType: NativeDataType.ctaText),
///   ],
///   context: NativeContextType.socialCentric,
///   placementType: NativePlacementType.inFeed,
/// );
/// ```
class NativeParameters {
  /// Creates [NativeParameters]. Unset fields keep the defaults of the ad
  /// that sends them.
  const NativeParameters({
    this.assets,
    this.eventTrackers,
    this.context,
    this.contextSubType,
    this.placementType,
    this.placementCount,
    this.sequence,
    this.assetUrlSupport,
    this.dUrlSupport,
    this.privacy,
    this.ext,
  });

  /// The assets to request. `null` requests the ad's default set:
  /// [defaultAssets] for the core ads, Prebid's reference set in the GAM,
  /// AdMob and MAX packages. Prebid Server rejects a native request without
  /// any asset.
  final List<NativeAsset>? assets;

  /// Title, main image, icon, sponsored, description and call to action:
  /// what the core ads request when [assets] is `null`.
  static const defaultAssets = [
    NativeAsset.title(required: true),
    NativeAsset.image(required: true),
    NativeAsset.image(imageType: NativeImageType.icon, required: true),
    NativeAsset.data(dataType: NativeDataType.sponsored, required: true),
    NativeAsset.data(dataType: NativeDataType.desc),
    NativeAsset.data(dataType: NativeDataType.ctaText),
  ];

  /// The event trackers to request. `null` sends none from the core ads;
  /// the GAM, AdMob and MAX packages request impression trackers.
  final List<NativeEventTracker>? eventTrackers;

  /// The context the ad appears in (`context`). The GAM, AdMob and MAX
  /// packages default to social.
  final NativeContextType? context;

  /// The context subtype (`contextsubtype`). The GAM, AdMob and MAX packages
  /// default to general social.
  final NativeContextSubType? contextSubType;

  /// The placement type (`plcmttype`). The GAM, AdMob and MAX packages
  /// default to in-feed.
  final NativePlacementType? placementType;

  /// The number of identical placements (`plcmtcnt`).
  final int? placementCount;

  /// The ad's position in a sequence (`seq`, 0 for the first).
  final int? sequence;

  /// Whether the app accepts an asset URL instead of the assets
  /// (`aurlsupport`).
  final bool? assetUrlSupport;

  /// Whether the app accepts a DCO URL instead of the assets
  /// (`durlsupport`).
  final bool? dUrlSupport;

  /// Whether the layout shows the buyer's own privacy (AdChoices) link
  /// (`privacy`).
  final bool? privacy;

  /// The native request's `ext`.
  final Map<String, Object?>? ext;

  /// The method-channel form used by the GAM / AdMob / MAX native ads.
  /// Unset fields are omitted, so the native side keeps its defaults.
  Map<String, Object?> toMap() => {
    'assets': ?assets?.map((a) => a.toMap()).toList(),
    'eventTrackers': ?eventTrackers?.map((t) => t.toMap()).toList(),
    'context': ?context?.value,
    'contextSubType': ?contextSubType?.value,
    'placementType': ?placementType?.value,
    'placementCount': ?placementCount,
    'sequence': ?sequence,
    'assetUrlSupport': ?assetUrlSupport,
    'dUrlSupport': ?dUrlSupport,
    'privacy': ?privacy,
    if (ext != null) 'ext': jsonEncode(ext),
  };
}
