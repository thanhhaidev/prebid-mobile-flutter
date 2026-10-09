import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A platform view created through [SystemChannels.platform_views].
class FakePlatformView {
  FakePlatformView(this.id, this.viewType, this.params);

  /// The platform view id (also the suffix of the view's method channel).
  final int id;

  /// The registered view type.
  final String viewType;

  /// The decoded creation params.
  final Map<Object?, Object?>? params;

  /// Methods Dart invoked on the view's method channel.
  final List<MethodCall> calls = [];

  /// The view's method channel name for a plugin view-type [prefix].
  String channelFor(String prefix) => '${prefix}_$id';
}

/// Fakes the engine side of platform views (iOS UiKitView and Android
/// texture views) and records the per-view method channels used by the
/// plugin's banner / native views.
class FakePlatformViews {
  FakePlatformViews({required this.channelPrefix});

  /// Per-view channel prefix, e.g. `prebid_mobile_flutter/banner_ad`.
  final String channelPrefix;

  /// Every view created so far, in creation order.
  final List<FakePlatformView> views = [];

  /// Ids of the disposed views.
  final List<int> disposed = [];

  /// When set, `create` waits for it before completing (to observe the gap
  /// between a widget update and the new view's creation).
  Completer<void>? createGate;

  TestDefaultBinaryMessenger get _messenger =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// The views not disposed yet.
  List<FakePlatformView> get live =>
      views.where((v) => !disposed.contains(v.id)).toList();

  void install() {
    _messenger.setMockMethodCallHandler(SystemChannels.platform_views, _handle);
  }

  void uninstall() {
    _messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final v in views) {
      _messenger.setMockMethodCallHandler(
        MethodChannel(v.channelFor(channelPrefix)),
        null,
      );
    }
  }

  Future<Object?> _handle(MethodCall call) async {
    switch (call.method) {
      case 'create':
        final args = (call.arguments as Map).cast<String, Object?>();
        final id = args['id']! as int;
        final raw = args['params'] as Uint8List?;
        final params = raw == null
            ? null
            : const StandardMessageCodec().decodeMessage(
                    ByteData.sublistView(raw),
                  )
                  as Map<Object?, Object?>;
        final view = FakePlatformView(id, args['viewType']! as String, params);
        views.add(view);
        _messenger.setMockMethodCallHandler(
          MethodChannel(view.channelFor(channelPrefix)),
          (c) async {
            view.calls.add(c);
            return null;
          },
        );
        final gate = createGate;
        if (gate != null) await gate.future;
        // Android texture views expect a texture id; iOS ignores the result.
        return args.containsKey('direction') ? 0 : null;
      case 'resize':
        final args = (call.arguments as Map).cast<String, Object?>();
        return <String, Object?>{
          'width': args['width'],
          'height': args['height'],
        };
      case 'dispose':
        final args = call.arguments;
        disposed.add(args is Map ? args['id']! as int : args as int);
        return null;
      default:
        return null;
    }
  }

  /// Delivers a native → Dart [method] call on [view]'s channel.
  Future<void> send(
    FakePlatformView view,
    String method, [
    Object? arguments,
  ]) async {
    await _messenger.handlePlatformMessage(
      view.channelFor(channelPrefix),
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, arguments),
      ),
      (_) {},
    );
  }
}
