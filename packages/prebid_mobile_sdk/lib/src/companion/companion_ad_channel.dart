import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Handles one native event for an ad: the event name and its payload.
typedef CompanionAdEventHandler = void Function(String event, Map? args);

/// A companion package's method channel for fullscreen ads, shared by every
/// ad of one kind (e.g. `prebid_mobile_sdk_gam/interstitial`).
///
/// Native events carry the `adId` they belong to; the channel routes each to
/// the handler registered for that id. Before its first call it asks the
/// native side to `releaseAll`: after a Dart hot restart the native managers
/// still hold the previous isolate's ads, which no ad of this isolate can
/// own.
class CompanionAdChannel {
  /// Creates the channel named [name].
  CompanionAdChannel(String name) : methodChannel = MethodChannel(name);

  /// The underlying method channel.
  @visibleForTesting
  final MethodChannel methodChannel;

  final Map<int, CompanionAdEventHandler> _handlers = {};
  bool _listening = false;
  Future<void>? _released;

  /// Routes the events for [adId] to [handler] until [unregister].
  void register(int adId, CompanionAdEventHandler handler) {
    if (!_listening) {
      _listening = true;
      methodChannel.setMethodCallHandler(_onCall);
    }
    _handlers[adId] = handler;
  }

  /// Stops routing the events for [adId].
  void unregister(int adId) => _handlers.remove(adId);

  /// Calls [method] on the native side with [arguments].
  Future<void> invoke(String method, Map<String, Object?> arguments) async {
    await (_released ??= _releaseAll());
    await methodChannel.invokeMethod<void>(method, arguments);
  }

  Future<void> _releaseAll() async {
    try {
      await methodChannel.invokeMethod<void>('releaseAll');
    } on MissingPluginException {
      // Best effort: nothing to release without the native side.
    } on PlatformException {
      // Same: an older native side without `releaseAll`.
    }
  }

  Future<dynamic> _onCall(MethodCall call) async {
    final args = call.arguments as Map?;
    final adId = (args?['adId'] as num?)?.toInt();
    if (adId == null) return;
    _handlers[adId]?.call(call.method, args);
  }
}
