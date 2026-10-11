import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../internal/platform_view.dart';
import 'ad_view_channel.dart';
import 'companion_ad_channel.dart';

/// The Dart side of one preloaded banner (ADR-0008), shared by the core's
/// `PrebidPreloadedBannerAd` and the companion packages' preloaded banners.
///
/// It owns the native banner's [AdViewChannel] and creation, keeps the size
/// the banner reports (`onAdSize`), and is shown by a [PreloadedBannerView].
/// The public ad classes keep the configuration and the listeners, and
/// handle the other events ([onEvent]).
class PreloadedBanner {
  /// A banner created with [create] and destroyed with [destroy], both given
  /// the banner's channel ID; [viewType] is its platform view type and the
  /// prefix of its channel.
  PreloadedBanner({
    required this.viewType,
    required Size size,
    required this._create,
    required this._destroy,
    required this.onEvent,
  }) : _requestedSize = size,
       _size = ValueNotifier(size);

  /// A companion package's banner, created and destroyed on its [channel]
  /// (`<package>/preloaded_banner`) from the creation params its banner
  /// widget sends ([config]).
  PreloadedBanner.companion({
    required String viewType,
    required CompanionAdChannel channel,
    required Size size,
    required Map<String, Object?> Function() config,
    required void Function(MethodCall event) onEvent,
  }) : this(
         viewType: viewType,
         size: size,
         create: (id) => channel.invoke('create', {
           'channelId': id,
           'config': {...config(), 'channelId': id},
         }),
         destroy: (id) => channel.invoke('destroy', {'channelId': id}),
         onEvent: onEvent,
       );

  /// The platform view type, also the prefix of the banner's channel.
  final String viewType;

  /// Handles a native event other than `onAdSize`.
  final void Function(MethodCall event) onEvent;

  final Size _requestedSize;
  final ValueNotifier<Size> _size;
  final Future<void> Function(int channelId) _create;
  final Future<void> Function(int channelId) _destroy;

  /// Bumped when the native banner is created or destroyed, so views pick up
  /// the current one.
  final ValueNotifier<int> _revision = ValueNotifier(0);

  /// The channel and creation of the current native banner; null before
  /// [load] and after [destroy].
  AdViewChannel? _channel;
  Future<void>? _created;

  /// The requested size until the native SDK reports the rendered
  /// creative's size.
  Size get size => _size.value;

  /// Creates and loads the native banner, or reloads it once created.
  Future<void> load() {
    final created = _created;
    final channel = _channel;
    if (created != null && channel != null) {
      return created.then(
        (_) => channel.methodChannel.invokeMethod<void>('loadAd'),
      );
    }
    final fresh = AdViewChannel(viewType, _onCall);
    _channel = fresh;
    // The native banner loads once created.
    final creating = _created = _create(fresh.id);
    _revision.value++;
    return creating;
  }

  /// Stops auto-refresh. Does nothing without a loaded banner.
  Future<void> stopRefresh() async {
    final created = _created;
    final channel = _channel;
    if (created == null || channel == null) return;
    await created;
    await channel.methodChannel.invokeMethod<void>('stopRefresh');
  }

  /// Destroys the native banner; a view showing it goes empty until the
  /// next [load].
  Future<void> destroy() async {
    final created = _created;
    final channel = _channel;
    if (created == null || channel == null) return;
    _created = null;
    _channel = null;
    channel.dispose();
    _size.value = _requestedSize;
    _revision.value++;
    try {
      await created;
    } on Object {
      return; // Never created natively: nothing to destroy.
    }
    await _destroy(channel.id);
  }

  Future<void> _onCall(MethodCall call) async {
    if (call.method != 'onAdSize') return onEvent(call);
    final args = call.arguments as Map?;
    final w = (args?['width'] as num?)?.toDouble();
    final h = (args?['height'] as num?)?.toDouble();
    // As AdViewState: a report without a positive height is dropped.
    if (h == null || h <= 0 || (w != null && w <= 0)) return;
    _size.value = Size(w ?? _size.value.width, h);
  }
}

/// Shows a [PreloadedBanner] at the size it reports; the slot stays empty
/// while the banner isn't loaded. Removing the view keeps the banner.
class PreloadedBannerView extends StatefulWidget {
  /// Creates a view of [banner].
  const PreloadedBannerView({super.key, required this.banner});

  /// The banner to show.
  final PreloadedBanner banner;

  @override
  State<PreloadedBannerView> createState() => _PreloadedBannerViewState();
}

class _PreloadedBannerViewState extends State<PreloadedBannerView> {
  /// The native banner creation this view shows once it completes: the
  /// platform view looks the banner up, so it must exist first.
  Future<void>? _creation;
  bool _created = false;

  void _follow(Future<void>? creation) {
    if (identical(creation, _creation)) return;
    _creation = creation;
    _created = false;
    creation?.then((_) {
      if (mounted && identical(_creation, creation)) {
        setState(() => _created = true);
      }
    }, onError: (Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final banner = widget.banner;
    return ListenableBuilder(
      listenable: Listenable.merge([banner._size, banner._revision]),
      builder: (context, _) {
        _follow(banner._created);
        final channel = banner._channel;
        return SizedBox.fromSize(
          size: banner.size,
          child: _created && channel != null
              ? adPlatformView(
                  key: ValueKey(channel.id),
                  viewType: banner.viewType,
                  creationParams: {'channelId': channel.id, 'preloaded': true},
                )
              : null,
        );
      },
    );
  }
}
