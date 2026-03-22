import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Expandable error display — shows a summary line, tap to expand full error.
class ExpandableErrorPanel extends StatefulWidget {
  final String error;
  const ExpandableErrorPanel({super.key, required this.error});

  @override
  State<ExpandableErrorPanel> createState() => _ExpandableErrorPanelState();
}

class _ExpandableErrorPanelState extends State<ExpandableErrorPanel>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isLong = widget.error.length > 60;
    final summary = isLong
        ? '${widget.error.substring(0, 57)}...'
        : widget.error;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — always visible
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: isLong ? () => setState(() => _expanded = !_expanded) : null,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline,
                      size: 16, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _expanded ? widget.error : summary,
                      style: TextStyle(
                          fontSize: 12, color: Colors.red.shade700),
                    ),
                  ),
                  if (isLong)
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.expand_more,
                          size: 18, color: Colors.red.shade400),
                    ),
                ],
              ),
            ),
          ),

          // Action buttons — visible when expanded
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(left: 10, right: 10, bottom: 8),
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: widget.error));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Error copied to clipboard',
                              style: TextStyle(fontSize: 11)),
                          duration: Duration(milliseconds: 800),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Icon(Icons.copy, size: 12, color: Colors.red.shade400),
                        const SizedBox(width: 4),
                        Text('Copy',
                            style: TextStyle(
                                fontSize: 11, color: Colors.red.shade600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
