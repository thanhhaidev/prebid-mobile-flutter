import 'package:flutter/material.dart';

import '../pages/bid_inspector_page.dart';
import '../utils/bid_inspector.dart';
import 'event_counter.dart';

/// Shared layout for every ad detail page, mirroring Prebid's
/// `PrebidInternalTestApp` test-case screen:
///
/// 1. the ad stage (inline formats),
/// 2. the ad-unit header,
/// 3. action buttons (Load / Show / Stop refresh ...),
/// 4. one row per callback that lights up with its count,
/// 5. extra panels (results, last bid) and a timestamped event log.
///
/// The app bar carries "Configure the Ad" (when [onConfigure] is set) and a
/// shortcut to the Bid Inspector.
class AdDetailScaffold extends StatelessWidget {
  final String title;
  final EventTracker tracker;
  final List<String> events;
  final Widget header;
  final Widget? stage;
  final List<Widget> actions;
  final List<Widget> extra;
  final VoidCallback? onConfigure;

  const AdDetailScaffold({
    super.key,
    required this.title,
    required this.tracker,
    required this.events,
    required this.header,
    required this.actions,
    this.stage,
    this.extra = const [],
    this.onConfigure,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_search_rounded),
            tooltip: 'Bid Inspector',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BidInspectorPage()),
            ),
          ),
          if (onConfigure != null)
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              tooltip: 'Configure the Ad',
              onPressed: onConfigure,
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: tracker,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (stage != null) ...[stage!, const SizedBox(height: 16)],
              header,
              const SizedBox(height: 16),
              _actionRows(),
              const SizedBox(height: 16),
              EventCounterList(tracker: tracker, events: events),
              for (final w in extra) ...[const SizedBox(height: 16), w],
              const SizedBox(height: 16),
              const LastBidCard(),
              const SizedBox(height: 16),
              EventLogCard(tracker: tracker),
            ],
          ),
        ),
      ),
    );
  }

  /// Two buttons per row, sharing the width.
  Widget _actionRows() {
    final rows = <Widget>[];
    for (var i = 0; i < actions.length; i += 2) {
      rows.add(
        Row(
          children: [
            Expanded(child: actions[i]),
            if (i + 1 < actions.length) ...[
              const SizedBox(width: 12),
              Expanded(child: actions[i + 1]),
            ],
          ],
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          rows[i],
        ],
      ],
    );
  }
}

/// A rounded stage that hosts an inline ad, or a hint before loading.
class AdStage extends StatelessWidget {
  final Widget? child;
  final String hint;

  const AdStage({
    super.key,
    this.child,
    this.hint = 'Tap Load to request an ad',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 120),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child:
          child ??
          Text(hint, style: TextStyle(color: theme.colorScheme.outline)),
    );
  }
}

/// Summary of the latest Prebid Server response captured by the
/// [BidInspector] — bidders and prices — with a link to the full JSON.
class LastBidCard extends StatelessWidget {
  const LastBidCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: BidInspector.instance,
      builder: (context, _) {
        final inspector = BidInspector.instance;
        final record = inspector.latest;
        final String summary;
        if (!inspector.enabled) {
          summary = 'Bid capture is off (Utilities → Bid Inspector)';
        } else if (record == null) {
          summary = 'No bid request yet';
        } else if (record.failed) {
          summary = 'No response (timeout / network error)';
        } else if (record.bids.isEmpty) {
          summary = 'No bids';
        } else {
          summary = record.bids
              .map((b) => '${b.$1} ${b.$2 ?? ''}'.trim())
              .join(', ');
        }
        return Material(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: record == null
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BidRecordPage(record: record),
                    ),
                  ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LAST BID RESPONSE',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(summary, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  if (record != null)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.outline,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
