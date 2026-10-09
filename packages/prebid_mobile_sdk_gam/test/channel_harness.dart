import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records method calls sent to [channel] and lets a test push native events
/// back over it, as the plugin's Kotlin / Swift side does.
class ChannelHarness {
  ChannelHarness(this.channel) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channel), (call) async {
          calls.add(call);
          return null;
        });
  }

  final String channel;
  final List<MethodCall> calls = [];

  Map<Object?, Object?> argsOf(String method) =>
      calls.lastWhere((c) => c.method == method).arguments as Map;

  /// Delivers a native → Dart event for [adId].
  Future<void> emit(String event, int adId, [Map<String, Object?>? extra]) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel,
            const StandardMethodCodec().encodeMethodCall(
              MethodCall(event, {'adId': adId, ...?extra}),
            ),
            (_) {},
          );
}

/// Fakes the engine side of platform views so `AndroidView` / `UiKitView`
/// actually get created in widget tests, and mocks the created view's method
/// channel (`<channelPrefix>_<viewId>`) to record what the widget sends.
class PlatformViewHarness {
  PlatformViewHarness(this.channelPrefix) {
    for (final channel in _engineChannels) {
      _messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'create':
            final id = (call.arguments as Map)['id'] as int;
            final name = '${channelPrefix}_$id';
            viewChannel = name;
            _messenger.setMockMethodCallHandler(MethodChannel(name), (c) async {
              calls.add(c);
              return null;
            });
            return 0;
          case 'resize':
            final args = call.arguments as Map;
            return {'width': args['width'], 'height': args['height']};
        }
        return null;
      });
    }
  }

  static const _engineChannels = [
    SystemChannels.platform_views,
    SystemChannels.platform_views_2,
  ];

  static TestDefaultBinaryMessenger get _messenger =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final String channelPrefix;

  /// The created view's channel name, once the platform view exists.
  String? viewChannel;

  /// Calls the widget sent to the created view's channel.
  final List<MethodCall> calls = [];

  /// Delivers a native → Dart event on the created view's channel.
  Future<void> emit(String method, [Object? arguments]) =>
      _messenger.handlePlatformMessage(
        viewChannel!,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall(method, arguments),
        ),
        (_) {},
      );

  void dispose() {
    for (final channel in _engineChannels) {
      _messenger.setMockMethodCallHandler(channel, null);
    }
    if (viewChannel != null) {
      _messenger.setMockMethodCallHandler(MethodChannel(viewChannel!), null);
    }
  }
}
