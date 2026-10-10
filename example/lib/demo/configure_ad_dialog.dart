import 'package:flutter/material.dart';

import '../data/demo_item.dart';
import '../theme/app_theme.dart';

/// Values of the "Configure the Ad" dialog.
///
/// For [ConfiguratorMode.interstitial], [width] / [height] are the min-size
/// percentages and [refreshSeconds] is unused.
class AdConfiguration {
  const AdConfiguration({
    required this.configId,
    required this.width,
    required this.height,
    this.refreshSeconds = 30,
  });
  final String configId;
  final int width;
  final int height;
  final int refreshSeconds;

  AdConfiguration copyWith({
    String? configId,
    int? width,
    int? height,
    int? refreshSeconds,
  }) => AdConfiguration(
    configId: configId ?? this.configId,
    width: width ?? this.width,
    height: height ?? this.height,
    refreshSeconds: refreshSeconds ?? this.refreshSeconds,
  );

  @override
  String toString() =>
      'AdConfiguration($configId, ${width}x$height, refresh $refreshSeconds)';
}

/// The original `AdConfiguratorDialogFragment` (spec §1.4): an AlertDialog
/// titled "Configure the Ad", shown before the ad loads when configuration
/// mode is on.
///
/// - BANNER: `Config ID`, `Width`, `Height`, `Auto Refresh Delay`.
/// - INTERSTITIAL: `Config ID`, `Min. Width Percentage`,
///   `Min. Height Percentage`.
///
/// "Load the ad" returns the edited values; dismissing returns `null` (the
/// caller then loads with the original values).
class ConfigureAdDialog extends StatefulWidget {
  const ConfigureAdDialog({
    super.key,
    required this.mode,
    required this.initial,
  });
  final ConfiguratorMode mode;
  final AdConfiguration initial;

  static Future<AdConfiguration?> show(
    BuildContext context, {
    required ConfiguratorMode mode,
    required AdConfiguration initial,
  }) => showDialog<AdConfiguration>(
    context: context,
    builder: (_) => ConfigureAdDialog(mode: mode, initial: initial),
  );

  @override
  State<ConfigureAdDialog> createState() => _ConfigureAdDialogState();
}

class _ConfigureAdDialogState extends State<ConfigureAdDialog> {
  late final _configId = TextEditingController(text: widget.initial.configId);
  late final _width = TextEditingController(text: '${widget.initial.width}');
  late final _height = TextEditingController(text: '${widget.initial.height}');
  late final _refresh = TextEditingController(
    text: '${widget.initial.refreshSeconds}',
  );

  bool get _banner => widget.mode == ConfiguratorMode.banner;

  @override
  void dispose() {
    _configId.dispose();
    _width.dispose();
    _height.dispose();
    _refresh.dispose();
    super.dispose();
  }

  void _submit() {
    final i = widget.initial;
    Navigator.of(context).pop(
      AdConfiguration(
        configId: _configId.text.trim(),
        width: int.tryParse(_width.text.trim()) ?? i.width,
        height: int.tryParse(_height.text.trim()) ?? i.height,
        refreshSeconds: int.tryParse(_refresh.text.trim()) ?? i.refreshSeconds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configure the Ad'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field('Config ID', _configId),
            if (_banner) ...[
              _field('Width', _width, number: true),
              _field('Height', _height, number: true),
              _field('Auto Refresh Delay', _refresh, number: true),
            ] else ...[
              _field('Min. Width Percentage', _width, number: true),
              _field('Min. Height Percentage', _height, number: true),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(onPressed: _submit, child: const Text('Load the ad')),
      ],
    );
  }

  Widget _field(String label, TextEditingController c, {bool number = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: c,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        style: AppFonts.monoStyle(),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
