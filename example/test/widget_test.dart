import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_flutter_example/main.dart';

void main() {
  testWidgets('App renders PrebidDemoApp', (WidgetTester tester) async {
    await tester.pumpWidget(const PrebidDemoApp());
    expect(find.text('Prebid Flutter Demo'), findsOneWidget);
  });
}
