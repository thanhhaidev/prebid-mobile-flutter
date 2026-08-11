import 'package:flutter/material.dart';

/// Result of the "Configure the Ad" dialog.
class AdConfig {
  final String configId;
  final int width;
  final int height;
  final int refreshDelay;

  const AdConfig({
    required this.configId,
    required this.width,
    required this.height,
    required this.refreshDelay,
  });
}

/// A dialog that lets the user override the config ID, size, and auto-refresh
/// delay before (re)loading an ad — mirrors the reference app's
/// "Configure the Ad" dialog.
class ConfigureAdDialog extends StatefulWidget {
  final AdConfig initial;

  /// Whether to show the size fields (banners) — hidden for fullscreen ads.
  final bool showSize;

  /// Whether to show the auto-refresh field (banners only).
  final bool showRefresh;

  const ConfigureAdDialog({
    super.key,
    required this.initial,
    this.showSize = true,
    this.showRefresh = true,
  });

  /// Shows the dialog and returns the chosen [AdConfig], or null if cancelled.
  static Future<AdConfig?> show(
    BuildContext context, {
    required AdConfig initial,
    bool showSize = true,
    bool showRefresh = true,
  }) {
    return showDialog<AdConfig>(
      context: context,
      builder: (_) => ConfigureAdDialog(
        initial: initial,
        showSize: showSize,
        showRefresh: showRefresh,
      ),
    );
  }

  @override
  State<ConfigureAdDialog> createState() => _ConfigureAdDialogState();
}

class _ConfigureAdDialogState extends State<ConfigureAdDialog> {
  late final TextEditingController _configId;
  late final TextEditingController _width;
  late final TextEditingController _height;
  late final TextEditingController _refresh;

  @override
  void initState() {
    super.initState();
    _configId = TextEditingController(text: widget.initial.configId);
    _width = TextEditingController(text: widget.initial.width.toString());
    _height = TextEditingController(text: widget.initial.height.toString());
    _refresh = TextEditingController(
      text: widget.initial.refreshDelay.toString(),
    );
  }

  @override
  void dispose() {
    _configId.dispose();
    _width.dispose();
    _height.dispose();
    _refresh.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      AdConfig(
        configId: _configId.text.trim(),
        width: int.tryParse(_width.text) ?? widget.initial.width,
        height: int.tryParse(_height.text) ?? widget.initial.height,
        refreshDelay:
            int.tryParse(_refresh.text) ?? widget.initial.refreshDelay,
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
            if (widget.showSize) ...[
              _field('Width', _width, number: true),
              _field('Height', _height, number: true),
            ],
            if (widget.showRefresh)
              _field('Auto Refresh Delay', _refresh, number: true),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _submit, child: const Text('Load the ad')),
      ],
    );
  }

  Widget _field(String label, TextEditingController c, {bool number = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(label)),
          Expanded(
            child: TextField(
              controller: c,
              keyboardType: number ? TextInputType.number : TextInputType.text,
              textAlign: number ? TextAlign.end : TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }
}
