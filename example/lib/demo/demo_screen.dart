import 'dart:async';

import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_admob/prebid_mobile_sdk_admob.dart';
import 'package:prebid_mobile_sdk_max/prebid_mobile_sdk_max.dart';

import '../data/demo_item.dart';
import '../services/app_settings.dart';
import '../services/custom_renderer.dart';
import '../theme/app_theme.dart';
import 'configure_ad_dialog.dart';

export 'package:prebid_mobile_sdk_example/data/demo_item.dart';
export 'package:prebid_mobile_sdk_example/demo/configure_ad_dialog.dart';
export 'package:prebid_mobile_sdk_example/demo/event_counter.dart';

/// The Examples screen's configuration toggle (`ConfigurationViewSettings`):
/// in memory, default off. When on, demo screens show "Configure the Ad"
/// before loading instead of auto-loading.
abstract final class ConfigurationMode {
  static final enabled = ValueNotifier<bool>(false);
}

/// Base widget of every demo screen — the original `AdFragment`.
///
/// Subclass together with [DemoScreenState]:
///
/// ```dart
/// class MyScreen extends DemoScreen {
///   const MyScreen({super.key, required super.item});
///   @override
///   State<MyScreen> createState() => _MyScreenState();
/// }
///
/// class _MyScreenState extends DemoScreenState<MyScreen> {
///   late final events = EventCounters(['onAdLoaded called', ...]);
///   @override
///   Future<void> startAd() async { /* create + load the ad */ }
///   @override
///   void destroyAd() { /* release it */ }
///   @override
///   Widget buildDemo(BuildContext context) => ListView(children: [...]);
/// }
/// ```
///
/// Register the screen in `lib/demo/demo_router.dart`.
abstract class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key, required this.item});
  final DemoItem item;
}

/// Lifecycle of a demo screen (spec §1.2), in order:
///
/// 1. `PrebidMobile.clearStoredAuctionResponse()` (the original sets
///    `storedAuctionResponse ?: ""` on every screen);
/// 2. per-item overrides: account ([DemoItem.accountId]), server
///    ([DemoItem.serverUrl]), app name ([DemoItem.appName]), random bid drop
///    and custom renderer flags;
/// 3. [onBeforeStart] hook;
/// 4. if configuration mode is on and the item has a
///    [DemoItem.configuratorMode], "Configure the Ad" → [config] (cancel
///    keeps the original values);
/// 5. [started] = true, [startAd] — i.e. the ad auto-loads on open;
///
/// and on exit: [destroyAd], then the overrides are restored (the account is
/// always reset to the default, as the original does).
///
/// [build] wraps [buildDemo] in a [DemoScaffold] (title = item label, Up
/// arrow, "Show Progress Dialog" overlay).
abstract class DemoScreenState<T extends DemoScreen> extends State<T> {
  DemoItem get item => widget.item;

  /// Effective ad configuration: the item's values, or the values edited in
  /// "Configure the Ad". For a dynamic config id the random pick is made once
  /// here.
  late AdConfiguration config = initialConfiguration();

  /// Whether setup finished and [startAd] ran. Build the ad only when true.
  bool started = false;

  /// The configuration before the dialog. Override to change defaults.
  AdConfiguration initialConfiguration() => AdConfiguration(
    configId: item.resolveConfigId() ?? '',
    width: item.size.width,
    height: item.size.height,
    refreshSeconds: item.refreshSeconds ?? 30,
  );

  /// Called after the overrides are applied, before the configurator /
  /// [startAd] (e.g. re-initialize the SDK like `configureOriginalPrebid()`).
  Future<void> onBeforeStart() async {}

  /// Creates and loads the ad (`initAd()` + `loadAd()` of the original).
  /// Called once. Widget-based ads usually just `setState` here since
  /// [started] is already true.
  Future<void> startAd();

  /// Releases the ad. Called from [dispose]; must not call `setState`.
  void destroyAd() {}

  /// The screen body (without the scaffold).
  Widget buildDemo(BuildContext context);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await PrebidMobile.clearStoredAuctionResponse();
    await _applyOverrides();
    await onBeforeStart();
    if (!mounted) return;

    final mode = item.configuratorMode;
    if (ConfigurationMode.enabled.value && mode != null) {
      final edited = await ConfigureAdDialog.show(
        context,
        mode: mode,
        initial: config,
      );
      if (!mounted) return;
      if (edited != null) config = edited;
    }

    setState(() => started = true);
    await startAd();
  }

  Future<void> _applyOverrides() async {
    final account = item.accountId;
    if (account != null) await PrebidMobile.setPrebidServerAccountId(account);
    final server = item.serverUrl;
    if (server != null) await PrebidMobile.setPrebidServerUrl(server);
    if (item.appName != null) await PrebidTargeting.setAppName(item.appName);
    if (item.has(DemoFlag.randomBidDrop)) _setBidDropProbability(0.5);
    // The "PluginEventListener" variants run the renderer alone: the plugin
    // owns the ad view, so the app can't attach a native listener to it.
    if (item.has(DemoFlag.customRenderer)) await CustomRenderer.register();
    // Left before the overrides landed: undo them right away.
    if (!mounted) _restoreOverrides();
  }

  void _restoreOverrides() {
    // The original restores the production account on every exit.
    unawaited(PrebidMobile.setPrebidServerAccountId(AppSettings.accountId));
    if (item.serverUrl != null) {
      unawaited(PrebidMobile.setPrebidServerUrl(AppSettings.serverUrl));
    }
    if (item.appName != null) unawaited(PrebidTargeting.setAppName(null));
    if (item.has(DemoFlag.randomBidDrop)) _setBidDropProbability(0);
    if (item.has(DemoFlag.customRenderer)) {
      unawaited(CustomRenderer.unregister());
    }
  }

  /// The AdMob / MAX testing hook behind the "Random" cases: withholds the
  /// Prebid bid from the ad server with [probability].
  static void _setBidDropProbability(double probability) {
    PrebidAdMob.debugDropBidProbability = probability;
    PrebidMax.debugDropBidProbability = probability;
  }

  @override
  void dispose() {
    destroyAd();
    _restoreOverrides();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      DemoScaffold(title: item.label, child: buildDemo(context));
}

/// Scaffold of demo and utility sub-screens: centered title, Up arrow (from
/// the nested navigator), and — on demo screens — the full-screen
/// indeterminate progress overlay of App settings → "Show Progress Dialog"
/// (never dismissed, touches pass through, as the original's ProgressBar).
class DemoScaffold extends StatelessWidget {
  const DemoScaffold({
    super.key,
    required this.title,
    required this.child,
    this.progressOverlay = true,
  });
  final String title;
  final Widget child;

  /// Whether the "Show Progress Dialog" overlay may appear (demo screens).
  final bool progressOverlay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 2, textAlign: TextAlign.center),
      ),
      // `expand`: the Stack takes the whole body. With only positioned
      // children it would size itself to 0x0 and clip the screen away.
      body: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (progressOverlay)
            ValueListenableBuilder<bool>(
              valueListenable: AppSettings.showProgressDialogNotifier,
              builder: (context, show, _) => show
                  ? const IgnorePointer(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

/// `AdUnitId: <configId>` (the original `label_auid` — it shows the config
/// id). Show it only when [DemoItem.showsAdUnitLabel].
class AdUnitIdLabel extends StatelessWidget {
  const AdUnitIdLabel(this.configId, {super.key});
  final String configId;

  @override
  Widget build(BuildContext context) {
    final c = DemoColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.codeBg,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: c.border),
      ),
      child: SelectableText(
        'AdUnitId: $configId',
        style: AppFonts.monoStyle(fontSize: 12.5, color: c.codeFg),
      ),
    );
  }
}

/// A demo action button ("Load", "Stop refresh", "Show", ...). `null`
/// [onPressed] = disabled, as the original's `isEnabled = false`.
class DemoButton extends StatelessWidget {
  const DemoButton(this.label, {super.key, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
    child: Text(label),
  );
}

/// Buttons side by side with equal widths.
class DemoButtonRow extends StatelessWidget {
  const DemoButtonRow({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(width: 10),
        Expanded(child: children[i]),
      ],
    ],
  );
}

/// The ad slot at the top of banner screens: the ad at its size, centered,
/// horizontally scrollable when wider than the screen (728x90). No
/// placeholder, as the original.
class AdContainer extends StatelessWidget {
  const AdContainer({super.key, this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final ad = child;
    if (ad == null) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.sizeOf(context).width - 32,
        ),
        child: Center(child: ad),
      ),
    );
  }
}
