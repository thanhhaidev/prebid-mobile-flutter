import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prebid_mobile_sdk/companion.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show
        NativeAsset,
        NativeContextSubType,
        NativeContextType,
        NativeEventTracker,
        NativePlacementType;

/// Listener for the GAM native ad flow, surfacing the full set of callbacks
/// from Prebid's Original-API GAM native integration (mirrors the reference
/// `PrebidInternalTestApp` native event list).
///
/// The flow: Prebid runs the auction (`fetchDemand`) → Google Ad Manager
/// resolves the line item into either a **custom-format** ad (Prebid demand is
/// carried here) or a **unified** native ad → `AdViewUtils.findNative` tries to
/// extract the Prebid winning bid. If found, the Prebid native creative is
/// rendered ([onNativeAdLoaded]); otherwise the GAM ad wins directly
/// ([onPrimaryAdWinCustom] / [onPrimaryAdWinUnified]).
class PrebidGamNativeAdListener {
  /// Creates a [PrebidGamNativeAdListener].
  const PrebidGamNativeAdListener({
    this.onFetchDemandSuccess,
    this.onFetchDemandFailed,
    this.onCustomAdLoaded,
    this.onUnifiedAdLoaded,
    this.onPrimaryAdFailed,
    this.onNativeAdLoaded,
    this.onPrimaryAdWinCustom,
    this.onPrimaryAdWinUnified,
    this.onAdImpression,
    this.onAdClicked,
    this.onAdExpired,
  });

  /// The Prebid auction returned a winning bid (`fetchDemand` succeeded).
  final VoidCallback? onFetchDemandSuccess;

  /// The Prebid auction returned no bid or failed. The GAM request still
  /// runs, so a direct-sold GAM ad may fill the slot.
  ///
  /// `reason` is the Prebid result code name, the same strings the core
  /// package reports on both platforms: `prebidDemandNoBids`,
  /// `prebidDemandTimedOut`, `prebidNetworkError`, `prebidServerError`,
  /// `prebidInvalidAccountId`, `prebidInvalidConfigId`, `prebidInvalidSize`,
  /// `prebidServerURLInvalid`, `prebidServerNotSpecified`,
  /// `prebidDemandNoCachedBids` or `prebidInvalidRequest` (any other code).
  ///
  /// On Android it is also `prebidSdkNotInitialized` when the view is created
  /// before the Prebid SDK finished initializing: Prebid Android drops such
  /// requests, so no auction runs (the GAM request still does).
  final void Function(String reason)? onFetchDemandFailed;

  /// Google Ad Manager returned a **custom-format** ad.
  final VoidCallback? onCustomAdLoaded;

  /// Google Ad Manager returned a **unified** native ad.
  final VoidCallback? onUnifiedAdLoaded;

  /// The primary (GAM) ad request failed to load.
  final void Function(String error)? onPrimaryAdFailed;

  /// A Prebid native creative was extracted from the GAM ad and rendered.
  final VoidCallback? onNativeAdLoaded;

  /// No Prebid creative in the custom-format ad — the GAM custom template wins.
  final VoidCallback? onPrimaryAdWinCustom;

  /// No Prebid creative in the unified ad — the GAM unified native ad wins.
  final VoidCallback? onPrimaryAdWinUnified;

  /// An impression was recorded on the rendered native ad.
  ///
  /// For a Prebid creative ([onNativeAdLoaded]) this is Prebid's own
  /// impression-tracker callback: it fires once Prebid's impression tracker
  /// request succeeds (reported once, though Prebid calls back per tracker
  /// URL). That differs from the core `PrebidNativeAdView`, whose
  /// `onAdImpression` is viewability-based (the ad on screen for about a
  /// second). For a GAM ad that wins ([onPrimaryAdWinUnified]) it is the
  /// Google Mobile Ads SDK's impression callback.
  final VoidCallback? onAdImpression;

  /// The rendered native ad was clicked.
  final VoidCallback? onAdClicked;

  /// The Prebid native bid expired (per `bid.exp`) before an impression.
  final VoidCallback? onAdExpired;
}

/// A native ad rendered through **Google Ad Manager** with Prebid demand, using
/// the Original-API custom-template + unified flow.
///
/// The entire flow runs natively (build `NativeAdUnit`, `fetchDemand`, build a
/// GAM `AdLoader` registering both `forCustomFormatAd` and `forNativeAd`, then
/// `AdViewUtils.findNative` to extract + render the Prebid creative). This
/// widget hosts the resulting native view as a PlatformView so impressions and
/// clicks track correctly.
///
/// ```dart
/// PrebidGamNativeAd(
///   configId: 'prebid-demo-banner-native-styles',
///   gamAdUnitId: '/21808260008/apollo_custom_template_native_ad_unit',
///   customFormatId: '11934135',
///   listener: PrebidGamNativeAdListener(
///     onNativeAdLoaded: () => debugPrint('Prebid native rendered'),
///   ),
/// );
/// ```
class PrebidGamNativeAd extends StatefulWidget {
  /// Creates a [PrebidGamNativeAd].
  const PrebidGamNativeAd({
    super.key,
    required this.configId,
    required this.gamAdUnitId,
    this.customFormatId,
    this.width = double.infinity,
    this.height = 320,
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
    this.customTargeting,
    this.gpid,
    this.pbAdSlot,
    this.impOrtbConfig,
    this.globalOrtbConfig,
    this.listener,
  });

  /// The Prebid Server stored impression config ID.
  final String configId;

  /// The Google Ad Manager native ad unit ID.
  final String gamAdUnitId;

  /// The GAM custom-format (native template) ID that carries Prebid demand
  /// (e.g. `11934135` in the Prebid demo). `null` requests unified native only.
  final String? customFormatId;

  /// Width of the native view.
  final double width;

  /// Initial height of the native view (grows to the rendered content).
  final double height;

  /// Native assets to request. `null` requests Prebid's reference set
  /// (title, icon, main image, sponsored, description, call to action).
  final List<NativeAsset>? assets;

  /// Native event trackers. `null` requests impression trackers (image + JS).
  final List<NativeEventTracker>? eventTrackers;

  /// Native context, context subtype and placement type. Default: social
  /// context, general-social subtype, in-feed placement.
  final NativeContextType? context;

  /// Native context subtype (`contextsubtype`).
  final NativeContextSubType? contextSubType;

  /// Native placement type (`plcmttype`).
  final NativePlacementType? placementType;

  /// Number of identical placements (`plcmtcnt`).
  final int? placementCount;

  /// Native request `seq` (0 for the first ad of a sequence).
  final int? sequence;

  /// Native request `aurlsupport`: the app can load assets from a URL.
  final bool? assetUrlSupport;

  /// Native request `durlsupport`: the app supports DCO URLs.
  final bool? dUrlSupport;

  /// Native request `privacy`: the layout shows the privacy (AdChoices) link.
  final bool? privacy;

  /// Native request `ext`.
  final Map<String, Object?>? ext;

  /// Custom key-values added to the Google Ad Manager request, next to
  /// Prebid's `hb_*` keys (which take precedence on conflict).
  final Map<String, String>? customTargeting;

  /// The Global Placement ID (`imp.ext.gpid`), e.g. `/1111/home`.
  final String? gpid;

  /// Prebid ad slot (`imp.ext.data.pbadslot`).
  final String? pbAdSlot;

  /// Impression-level OpenRTB JSON merged into this ad unit's `imp` (e.g.
  /// `{"ext":{"data":{"section":"news"}}}`).
  final String? impOrtbConfig;

  /// Request-level OpenRTB JSON for this ad unit only (merged over
  /// `PrebidTargeting.setGlobalOrtbConfig`).
  final String? globalOrtbConfig;

  /// Listener for the native ad flow events.
  final PrebidGamNativeAdListener? listener;

  @override
  State<PrebidGamNativeAd> createState() => _PrebidGamNativeAdState();
}

class _PrebidGamNativeAdState extends State<PrebidGamNativeAd> {
  /// The current native view's channel. The native side starts the auction
  /// as soon as it is created, before `onPlatformViewCreated`, so the channel
  /// is listened to first. A configuration change gets a new channel (and a
  /// new native view), so late events from the old view never reach it.
  late AdViewChannel _view = _newView();
  late double _height = widget.height;

  AdViewChannel _newView() =>
      AdViewChannel('prebid_mobile_sdk_gam/native', _onNativeEvent);

  @override
  void didUpdateWidget(PrebidGamNativeAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_config(oldWidget).toString() != _config(widget).toString()) {
      // The native view reads its configuration once, so a changed config
      // gets a new view (keyed below) on a new channel, at the initial height.
      _view.dispose();
      _view = _newView();
      _height = widget.height;
    }
  }

  Future<dynamic> _onNativeEvent(MethodCall call) async {
    final l = widget.listener;
    switch (call.method) {
      case 'onAdSize':
        final h = ((call.arguments as Map?)?['height'] as num?)?.toDouble();
        if (h != null && h > 0 && mounted) setState(() => _height = h);
      case 'fetchDemandSuccess':
        l?.onFetchDemandSuccess?.call();
      case 'fetchDemandFailed':
        l?.onFetchDemandFailed?.call(
          call.arguments as String? ?? 'prebidInvalidRequest',
        );
      case 'customAdLoaded':
        l?.onCustomAdLoaded?.call();
      case 'unifiedAdLoaded':
        l?.onUnifiedAdLoaded?.call();
      case 'primaryAdFailed':
        l?.onPrimaryAdFailed?.call(call.arguments as String? ?? '');
      case 'nativeAdLoaded':
        l?.onNativeAdLoaded?.call();
      case 'primaryAdWinCustom':
        l?.onPrimaryAdWinCustom?.call();
      case 'primaryAdWinUnified':
        l?.onPrimaryAdWinUnified?.call();
      case 'onAdImpression':
        l?.onAdImpression?.call();
      case 'onAdClicked':
        l?.onAdClicked?.call();
      case 'onAdExpired':
        l?.onAdExpired?.call();
    }
  }

  /// The configuration the native view is created with (without the
  /// per-view channel id).
  static Map<String, Object?> _config(PrebidGamNativeAd widget) {
    return <String, Object?>{
      'configId': widget.configId,
      'gamAdUnitId': widget.gamAdUnitId,
      'customFormatId': widget.customFormatId ?? '',
      if (widget.assets != null)
        'assets': widget.assets!.map((a) => a.toMap()).toList(),
      if (widget.eventTrackers != null)
        'eventTrackers': widget.eventTrackers!.map((t) => t.toMap()).toList(),
      if (widget.context != null) 'context': widget.context!.value,
      if (widget.contextSubType != null)
        'contextSubType': widget.contextSubType!.value,
      if (widget.placementType != null)
        'placementType': widget.placementType!.value,
      if (widget.placementCount != null)
        'placementCount': widget.placementCount,
      if (widget.sequence != null) 'sequence': widget.sequence,
      if (widget.assetUrlSupport != null)
        'assetUrlSupport': widget.assetUrlSupport,
      if (widget.dUrlSupport != null) 'dUrlSupport': widget.dUrlSupport,
      if (widget.privacy != null) 'privacy': widget.privacy,
      if (widget.ext != null) 'ext': jsonEncode(widget.ext),
      if (widget.customTargeting != null)
        'customTargeting': widget.customTargeting,
      if (widget.gpid != null) 'gpid': widget.gpid,
      if (widget.pbAdSlot != null) 'pbAdSlot': widget.pbAdSlot,
      if (widget.impOrtbConfig != null) 'impOrtbConfig': widget.impOrtbConfig,
      if (widget.globalOrtbConfig != null)
        'globalOrtbConfig': widget.globalOrtbConfig,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: _height,
      child: _buildPlatformView(),
    );
  }

  Widget _buildPlatformView() {
    final view = _view;
    final creationParams = <String, Object?>{
      'channelId': view.id,
      ..._config(widget),
    };
    // A new channel means a new native view (the config changed).
    final key = ValueKey(view.id);
    // defaultTargetPlatform (not dart:io) so widget tests can pick a platform.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        key: key,
        viewType: 'prebid_mobile_sdk_gam/native',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        key: key,
        viewType: 'prebid_mobile_sdk_gam/native',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }
}
