import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The platform view of an ad: an [AndroidView] or a [UiKitView] of
/// [viewType] created with [creationParams], or an empty box elsewhere.
Widget adPlatformView({
  required Key key,
  required String viewType,
  required Map<String, Object?> creationParams,
  PlatformViewCreatedCallback? onCreated,
}) {
  // defaultTargetPlatform (not dart:io) so widget tests can pick a platform.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return AndroidView(
      key: key,
      viewType: viewType,
      creationParams: creationParams,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: onCreated,
    );
  } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    return UiKitView(
      key: key,
      viewType: viewType,
      creationParams: creationParams,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: onCreated,
    );
  }
  return const SizedBox.shrink();
}
