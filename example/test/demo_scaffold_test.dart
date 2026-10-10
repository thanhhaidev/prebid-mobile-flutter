import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk_example/demo/demo_screen.dart';

void main() {
  for (final overlay in [true, false]) {
    testWidgets('the body fills the scaffold (progressOverlay: $overlay)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DemoScaffold(
            title: 'Demo',
            progressOverlay: overlay,
            child: const ColoredBox(color: Colors.red, child: Text('body')),
          ),
        ),
      );
      final body = tester.getSize(find.byType(ColoredBox).last);
      expect(body.width, 800);
      expect(body.height, greaterThan(400));
      expect(find.text('body').hitTestable(), findsOneWidget);
    });
  }
}
