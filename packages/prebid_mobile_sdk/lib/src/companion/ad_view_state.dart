import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../ad_listener.dart';
import '../banner_ad.dart';
import 'ad_view_channel.dart';

/// The state of a widget that shows one native ad view: the core
/// `PrebidBannerAd` and the companion packages' banner and native ads.
///
/// It owns the view's [AdViewChannel], creates the platform view
/// ([buildAdView]), replaces the view when the configuration changes (the
/// native view reads it once), records the creative size the view reports
/// (`onAdSize`) and keeps a [PrebidBannerAdController] bound to the current
/// view. A subclass supplies the [viewType], the configuration
/// ([configOf]) and handles the other events ([onViewEvent]).
mixin AdViewState<T extends StatefulWidget> on State<T> {
  /// The platform view type, also the prefix of each view's channel.
  String get viewType;

  /// The configuration the native view is created with. When it changes the
  /// widget gets a new native view.
  Map<String, Object?> configOf(T widget);

  /// Handles a native event other than `onAdSize`.
  void onViewEvent(MethodCall call);

  /// Called when a configuration change replaced the native view, before the
  /// new one is built.
  void onViewReplaced() {}

  /// The banner controller of [widget], bound to the current native view.
  PrebidBannerAdController? controllerOf(T widget) => null;

  /// Whether the native view of [widget] loads on its own once created.
  bool autoLoadOf(T widget) => false;

  /// The creative width the current view reported, if any.
  double? get reportedWidth => _reportedWidth;

  /// The creative height the current view reported, if any.
  double? get reportedHeight => _reportedHeight;

  double? _reportedWidth;
  double? _reportedHeight;
  double? _adaptiveWidth;

  late AdViewChannel _view = AdViewChannel(viewType, _onCall);

  /// Whether [_view]'s platform view exists, so the controller can use it.
  bool _created = false;

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (configOf(oldWidget).toString() != configOf(widget).toString()) {
      // The old channel is dropped now: a `controller.loadAd()` made before
      // the new view exists is queued and replayed on it.
      _release(controllerOf(oldWidget));
      _view = AdViewChannel(viewType, _onCall);
      _reportedWidth = null;
      _reportedHeight = null;
      _adaptiveWidth = null;
      onViewReplaced();
      return;
    }
    final controller = controllerOf(widget);
    if (_created && !identical(controllerOf(oldWidget), controller)) {
      final old = controllerOf(oldWidget);
      if (old != null) detachBannerController(old, _view.methodChannel);
      if (controller != null) {
        attachBannerController(
          controller,
          _view.methodChannel,
          autoLoaded: autoLoadOf(widget),
        );
      }
    }
  }

  /// The platform view, created with [configOf], [extraParams] and the
  /// view's `channelId`; keyed by the channel, so a new configuration gets a
  /// new view.
  Widget buildAdView({Map<String, Object?> extraParams = const {}}) {
    final view = _view;
    final creationParams = {
      ...configOf(widget),
      ...extraParams,
      'channelId': view.id,
    };
    final key = ValueKey(view.id);
    void onCreated(int _) => _onViewCreated(view);
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

  /// Builds an adaptive slot: [builder] gets the width available at the
  /// first layout (the screen width when unbounded), kept until the view is
  /// replaced.
  Widget buildAdaptive(Widget Function(double width) builder) {
    return LayoutBuilder(
      builder: (context, constraints) => builder(
        _adaptiveWidth ??= constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width,
      ),
    );
  }

  void _onViewCreated(AdViewChannel view) {
    // A replaced view finishing its creation late has nothing to attach.
    if (!identical(view, _view) || !mounted) return;
    _created = true;
    final controller = controllerOf(widget);
    if (controller != null) {
      attachBannerController(
        controller,
        view.methodChannel,
        autoLoaded: autoLoadOf(widget),
      );
    }
  }

  Future<dynamic> _onCall(MethodCall call) async {
    if (call.method != 'onAdSize') return onViewEvent(call);
    final args = call.arguments as Map?;
    final w = (args?['width'] as num?)?.toDouble();
    final h = (args?['height'] as num?)?.toDouble();
    // Natives report only a height. A report without a height or with a
    // non-positive dimension (an empty creative) is dropped whole.
    if (!mounted || h == null || h <= 0 || (w != null && w <= 0)) return;
    setState(() {
      _reportedWidth = w ?? _reportedWidth;
      _reportedHeight = h;
    });
  }

  void _release(PrebidBannerAdController? controller) {
    _view.dispose();
    if (_created && controller != null) {
      detachBannerController(controller, _view.methodChannel);
    }
    _created = false;
  }

  @override
  void dispose() {
    _release(controllerOf(widget));
    super.dispose();
  }
}

/// The error message of a failure event: the payload itself (a String) or
/// its `error` entry.
String adEventError(Object? args) => switch (args) {
  final String error => error,
  {'error': final String error} => error,
  _ => 'Unknown error',
};

/// Calls the [listener] or [videoListener] callback for a banner view
/// [event]. Returns whether the event is one of theirs.
bool dispatchBannerEvent(
  PrebidBannerAdListener? listener,
  PrebidBannerVideoListener? videoListener,
  MethodCall event,
) {
  switch (event.method) {
    case 'onAdLoaded':
      listener?.onAdLoaded?.call();
    case 'onAdDisplayed':
      listener?.onAdDisplayed?.call();
    case 'onAdFailed':
      listener?.onAdFailed?.call(adEventError(event.arguments));
    case 'onAdClicked':
      listener?.onAdClicked?.call();
    case 'onAdImpression':
      listener?.onAdImpression?.call();
    case 'onAdClosed':
      listener?.onAdClosed?.call();
    case 'onAdExpired':
      listener?.onAdExpired?.call();
    case 'onVideoCompleted':
      videoListener?.onVideoCompleted?.call();
    case 'onVideoPaused':
      videoListener?.onVideoPaused?.call();
    case 'onVideoResumed':
      videoListener?.onVideoResumed?.call();
    case 'onVideoMuted':
      videoListener?.onVideoMuted?.call();
    case 'onVideoUnmuted':
      videoListener?.onVideoUnmuted?.call();
    default:
      return false;
  }
  return true;
}
