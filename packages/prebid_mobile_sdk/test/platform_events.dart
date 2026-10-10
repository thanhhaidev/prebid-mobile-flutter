import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/src/generated/prebid_api.g.dart';

/// Sends [event] the way the native side does: over the Pigeon
/// `AdFlutterApi.onAdEvent` channel. An ad must exist (it binds the
/// channel).
Future<void> sendAdEvent(AdEvent event) => _send(
  'dev.flutter.pigeon.prebid_mobile_sdk.AdFlutterApi.onAdEvent',
  [event],
);

/// Sends Prebid's `onDemandRefreshed` for [adId] over the Pigeon
/// `MultiformatFlutterApi` channel. An Original API unit must exist.
Future<void> sendDemandRefreshed(
  int adId,
  MultiformatBidResult result,
) => _send(
  'dev.flutter.pigeon.prebid_mobile_sdk.MultiformatFlutterApi.onDemandRefreshed',
  [adId, result],
);

/// Sends a bid request / response pair over `PrebidEventFlutterApi`.
Future<void> sendBidResponse(String? request, String? response) => _send(
  'dev.flutter.pigeon.prebid_mobile_sdk.PrebidEventFlutterApi.onBidResponse',
  [request, response],
);

/// Sends a Prebid log message over `PrebidEventFlutterApi`.
Future<void> sendLog(int level, String message) => _send(
  'dev.flutter.pigeon.prebid_mobile_sdk.PrebidEventFlutterApi.onLog',
  [level, message],
);

Future<void> _send(String channel, List<Object?> arguments) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel,
          PrebidMobileHostApi.pigeonChannelCodec.encodeMessage(arguments),
          (_) {},
        );
