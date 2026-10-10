import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk_example/data/demo_item.dart';
import 'package:prebid_mobile_sdk_example/demo/configure_ad_dialog.dart';
import 'package:prebid_mobile_sdk_example/demo/event_counter.dart';
import 'package:prebid_mobile_sdk_example/pages/examples_page.dart';
import 'package:prebid_mobile_sdk_example/theme/app_theme.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light(), home: child);

void main() {
  group('EventCounters', () {
    test('fire / acknowledge / reset semantics', () {
      final c = EventCounters(['onAdLoaded called', 'custom row']);
      final row = c['onAdLoaded called'];
      expect(
        EventCounterRow.format('onAdLoaded called', row),
        'onAdLoaded called  -  0 ( 0 )',
      );

      c.fire('onAdLoaded called');
      c.fire('onAdLoaded called');
      expect((row.total, row.delta, row.enabled), (2, 2, true));
      expect(
        EventCounterRow.format('onAdLoaded called', row),
        'onAdLoaded called  -  2 ( +2 )',
      );

      c.acknowledge('onAdLoaded called');
      expect((row.total, row.delta, row.enabled), (2, 0, false));

      c.fire('onAdLoaded called');
      c.fire('custom row');
      c.reset(); // standard rows only
      expect((row.total, row.delta, row.enabled), (3, 0, false));
      expect(c['custom row'].enabled, isTrue);
    });
  });

  testWidgets('Examples screen shows the original controls', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const ExamplesPage()));
    await tester.pump();

    expect(find.text(kAppTitle), findsOneWidget);
    for (final label in [
      'In-App',
      'GAM',
      'Original',
      'AdMob',
      'Max',
      'Banner',
      'Interstitial',
      'MRAID',
      'Video',
      'Native',
      'Enable GDPR',
      'Enable Caching',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.text('All'), findsNWidgets(2));
    expect(find.text('Banner 320x50 (GAM Original) [OK, PUC]'), findsOneWidget);

    // Integration filter + label search.
    await tester.tap(find.text('In-App'));
    await tester.pump();
    expect(find.text('Banner 320x50 (GAM Original) [OK, PUC]'), findsNothing);
    await tester.enterText(find.byType(TextField), 'mraid 3.0');
    await tester.pump();
    expect(find.text('MRAID 3.0: Load And Events (In-App)'), findsOneWidget);
    expect(find.text('Banner 320x50 (In-App)'), findsNothing);
  });

  testWidgets('Configure the Ad dialog: banner and interstitial fields', (
    tester,
  ) async {
    AdConfiguration? result;
    for (final mode in ConfiguratorMode.values) {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await ConfigureAdDialog.show(
                context,
                mode: mode,
                initial: const AdConfiguration(
                  configId: 'cfg',
                  width: 320,
                  height: 50,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Configure the Ad'), findsOneWidget);
      expect(find.text('Config ID'), findsOneWidget);
      if (mode == ConfiguratorMode.banner) {
        expect(find.text('Width'), findsOneWidget);
        expect(find.text('Auto Refresh Delay'), findsOneWidget);
        expect(find.text('30'), findsOneWidget);
      } else {
        expect(find.text('Min. Width Percentage'), findsOneWidget);
        expect(find.text('Min. Height Percentage'), findsOneWidget);
        expect(find.text('Auto Refresh Delay'), findsNothing);
      }
      await tester.tap(find.text('Load the ad'));
      await tester.pumpAndSettle();
      expect(result?.configId, 'cfg');
    }
  });
}
