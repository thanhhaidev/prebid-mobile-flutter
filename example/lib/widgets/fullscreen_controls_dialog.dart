import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

/// Result of the fullscreen "Configure the Ad" dialog.
class FullscreenConfig {
  final String configId;
  final PrebidFullscreenControls? controls;

  const FullscreenConfig({required this.configId, this.controls});
}

/// "Configure the Ad" for interstitial / rewarded test cases: the config id
/// plus Prebid's fullscreen rendering controls (close / skip buttons, sound,
/// minimum size), like the reference app's interstitial configuration screen.
class FullscreenControlsDialog extends StatefulWidget {
  final FullscreenConfig initial;
  final bool isRewarded;

  const FullscreenControlsDialog({
    super.key,
    required this.initial,
    required this.isRewarded,
  });

  static Future<FullscreenConfig?> show(
    BuildContext context, {
    required FullscreenConfig initial,
    required bool isRewarded,
  }) {
    return showDialog<FullscreenConfig>(
      context: context,
      builder: (_) =>
          FullscreenControlsDialog(initial: initial, isRewarded: isRewarded),
    );
  }

  @override
  State<FullscreenControlsDialog> createState() =>
      _FullscreenControlsDialogState();
}

class _FullscreenControlsDialogState extends State<FullscreenControlsDialog> {
  late final _configId = TextEditingController(text: widget.initial.configId);
  late final PrebidFullscreenControls? _c = widget.initial.controls;
  late final _closeArea = TextEditingController(
    text: _c?.closeButtonArea?.toString() ?? '',
  );
  late final _skipArea = TextEditingController(
    text: _c?.skipButtonArea?.toString() ?? '',
  );
  late final _skipDelay = TextEditingController(
    text: _c?.skipDelay?.toString() ?? '',
  );
  late final _minWidth = TextEditingController(
    text: _c?.minSizePercentage?.width.round().toString() ?? '',
  );
  late final _minHeight = TextEditingController(
    text: _c?.minSizePercentage?.height.round().toString() ?? '',
  );
  late PrebidButtonPosition? _closePosition = _c?.closeButtonPosition;
  late PrebidButtonPosition? _skipPosition = _c?.skipButtonPosition;
  late bool? _muted = _c?.isMuted;
  late bool? _soundButton = _c?.isSoundButtonVisible;
  late bool? _autoClose = _c?.isAutoCloseOnCompletionEnabled;

  @override
  void dispose() {
    for (final c in [
      _configId,
      _closeArea,
      _skipArea,
      _skipDelay,
      _minWidth,
      _minHeight,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final minW = int.tryParse(_minWidth.text);
    final minH = int.tryParse(_minHeight.text);
    final controls = PrebidFullscreenControls(
      closeButtonArea: double.tryParse(_closeArea.text),
      closeButtonPosition: _closePosition,
      skipButtonArea: double.tryParse(_skipArea.text),
      skipButtonPosition: _skipPosition,
      skipDelay: int.tryParse(_skipDelay.text),
      isMuted: _muted,
      isSoundButtonVisible: _soundButton,
      isAutoCloseOnCompletionEnabled: _autoClose,
      minSizePercentage: minW != null && minH != null
          ? Size(minW.toDouble(), minH.toDouble())
          : null,
    );
    Navigator.of(context).pop(
      FullscreenConfig(
        configId: _configId.text.trim(),
        controls: controls.toMap().isEmpty ? null : controls,
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
            const Divider(height: 24),
            _position('Close button', _closePosition, (v) {
              setState(() => _closePosition = v);
            }),
            _field('Close area (0-1)', _closeArea, number: true),
            if (!widget.isRewarded) ...[
              _position('Skip button', _skipPosition, (v) {
                setState(() => _skipPosition = v);
              }),
              _field('Skip area (0-1)', _skipArea, number: true),
            ],
            _field('Skip delay (s)', _skipDelay, number: true),
            _tristate('Muted', _muted, (v) => setState(() => _muted = v)),
            _tristate(
              'Sound button',
              _soundButton,
              (v) => setState(() => _soundButton = v),
            ),
            if (!widget.isRewarded) ...[
              _tristate(
                'Auto close (iOS)',
                _autoClose,
                (v) => setState(() => _autoClose = v),
              ),
              _field('Min width %', _minWidth, number: true),
              _field('Min height %', _minHeight, number: true),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Load the ad')),
      ],
    );
  }

  Widget _field(String label, TextEditingController c, {bool number = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(label)),
          Expanded(
            child: TextField(
              controller: c,
              decoration: const InputDecoration(hintText: 'default'),
              keyboardType: number
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              textAlign: number ? TextAlign.end : TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }

  Widget _position(
    String label,
    PrebidButtonPosition? value,
    ValueChanged<PrebidButtonPosition?> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(width: 130, child: Text(label)),
        Expanded(
          child: DropdownButton<PrebidButtonPosition?>(
            isExpanded: true,
            value: value,
            items: [
              const DropdownMenuItem(value: null, child: Text('default')),
              for (final p in PrebidButtonPosition.values)
                DropdownMenuItem(value: p, child: Text(p.name)),
            ],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _tristate(String label, bool? value, ValueChanged<bool?> onChanged) {
    return Row(
      children: [
        SizedBox(width: 130, child: Text(label)),
        Expanded(
          child: DropdownButton<bool?>(
            isExpanded: true,
            value: value,
            items: const [
              DropdownMenuItem(value: null, child: Text('default')),
              DropdownMenuItem(value: true, child: Text('on')),
              DropdownMenuItem(value: false, child: Text('off')),
            ],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
