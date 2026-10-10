import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/src/generated/prebid_api.g.dart';

/// Sends [event] the way the native side does: over the Pigeon
/// `AdFlutterApi.onAdEvent` channel. An ad must exist (it binds the
/// channel).
Future<void> sendAdEvent(AdEvent event) => _send(
  'dev.flutter.pigeon.prebid_mobile_sdk.AdFlutterApi.onAdEvent',
  [event],
);

Future<void> _send(String channel, List<Object?> arguments) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel,
          PrebidMobileHostApi.pigeonChannelCodec.encodeMessage(arguments),
          (_) {},
        );
