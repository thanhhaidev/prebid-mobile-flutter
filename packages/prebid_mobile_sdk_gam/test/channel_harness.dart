import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records method calls sent to [channel] and lets a test push native events
/// back over it, as the plugin's Kotlin / Swift side does.
///
/// The one-time `releaseAll` (hot-restart cleanup) is counted in
/// [releaseAllCalls], not recorded in [calls].
class ChannelHarness {
  ChannelHarness(this.channel) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channel), (call) async {
          if (call.method == 'releaseAll') {
            releaseAllCalls++;
          } else {
            calls.add(call);
          }
          return null;
        });
  }

  final String channel;
  final List<MethodCall> calls = [];
  int releaseAllCalls = 0;

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
/// channel (`<channelPrefix>_<channelId>`, the `channelId` creation param) to
/// record what the widget sends.
class PlatformViewHarness {
  PlatformViewHarness(this.channelPrefix) {
    for (final channel in _engineChannels) {
      _messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'create':
            final args = call.arguments as Map;
            final id = args['id'] as int;
            final params = args['params'];
            if (params is Uint8List) {
              creationParams =
                  const StandardMessageCodec().decodeMessage(
                        ByteData.sublistView(params),
                      )
                      as Map?;
            }
            // Named as the native view names it; kept out of
            // [creationParams] so tests can compare the configuration.
            final channelId = creationParams?.remove('channelId') as int?;
            channelIds.add(channelId);
            createdParams.add(creationParams);
            createdIds.add(id);
            final name = '${channelPrefix}_${channelId ?? id}';
            viewChannel = name;
            viewChannels.add(name);
            _messenger.setMockMethodCallHandler(MethodChannel(name), (c) async {
              calls.add(c);
              return null;
            });
            // As a native view that fails at once, before the engine reports
            // the view as created.
            for (final (method, arguments) in eventsOnCreate) {
              await emit(method, arguments);
            }
            return 0;
          case 'dispose':
            final args = call.arguments;
            disposedIds.add(args is Map ? args['id'] as int : args as int);
            return null;
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

  /// The decoded `creationParams` the widget passed to the platform view,
  /// without `channelId`.
  Map<Object?, Object?>? creationParams;

  /// Events each view sends while it is being created.
  final List<(String, Object?)> eventsOnCreate = [];

  /// Platform view ids of the views created so far, oldest first.
  final List<int> createdIds = [];

  /// The `channelId` creation param of every view created so far.
  final List<int?> channelIds = [];

  /// The `creationParams` of every view created so far, oldest first.
  final List<Map<Object?, Object?>?> createdParams = [];

  /// The channel of every view created so far, oldest first.
  final List<String> viewChannels = [];

  /// Ids of the platform views the widget disposed.
  final List<int> disposedIds = [];

  /// Calls the widget sent to the created views' channels.
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

  /// Delivers a native → Dart event on [channel] (e.g. an older view's).
  static Future<void> emitOn(
    String channel,
    String method, [
    Object? arguments,
  ]) => _messenger.handlePlatformMessage(
    channel,
    const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
    (_) {},
  );

  void dispose() {
    for (final channel in _engineChannels) {
      _messenger.setMockMethodCallHandler(channel, null);
    }
    for (final channel in viewChannels) {
      _messenger.setMockMethodCallHandler(MethodChannel(channel), null);
    }
  }
}
