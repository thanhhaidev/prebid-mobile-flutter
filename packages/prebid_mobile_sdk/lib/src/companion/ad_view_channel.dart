import 'package:flutter/services.dart';

/// The method channel of one native ad view, named before the view exists.
///
/// Native views start loading as soon as they are created, which can be
/// before `onPlatformViewCreated` runs, so a channel named after the platform
/// view id could miss early events (an immediate failure, for example).
/// Instead the widget picks [id], listens on the channel, and passes the id
/// to the native view as the `channelId` creation parameter; the native view
/// names its channel `<prefix>_<channelId>`.
class AdViewChannel {
  /// Listens on `<prefix>_<id>` with [handler], under a fresh [id].
  AdViewChannel(
    String prefix,
    Future<dynamic> Function(MethodCall call) handler,
  ) : id = _nextId++ {
    methodChannel = MethodChannel('${prefix}_$id')
      ..setMethodCallHandler(handler);
  }

  static int _nextId = 1;

  /// The id the native view names its channel with (`channelId`).
  final int id;

  /// The channel; also used to call the native view.
  late final MethodChannel methodChannel;

  /// Stops listening. A new view needs a new [AdViewChannel].
  void dispose() => methodChannel.setMethodCallHandler(null);
}
