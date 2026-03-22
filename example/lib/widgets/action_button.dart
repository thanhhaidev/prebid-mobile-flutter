import 'package:flutter/material.dart';

/// Styled action button matching Prebid demo's Load/Show/Hide buttons.
class ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const ActionButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF0068B5),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}
