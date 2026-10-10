import 'package:flutter/services.dart';

/// Prebid's sample plugin renderer (Android `SampleCustomRenderer`, iOS
/// `SampleRenderer`), ported into the example's native code and registered
/// while a "[Custom Renderer]" screen is open.
abstract final class CustomRenderer {
  static const _channel = MethodChannel('prebid_example/custom_renderer');

  static Future<void> register() => _channel.invokeMethod<void>('register');

  static Future<void> unregister() => _channel.invokeMethod<void>('unregister');
}
