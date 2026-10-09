import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/src/internal/visibility.dart';

final _key = GlobalKey();

Widget _host(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

Widget _box({double width = 100, double height = 100}) =>
    SizedBox(key: _key, width: width, height: height);

double _fraction() =>
    visibleFraction(_key.currentContext!.findRenderObject()! as RenderBox);

void main() {
  testWidgets('a box fully on screen is fully visible', (tester) async {
    await tester.pumpWidget(_host(Center(child: _box())));
    expect(_fraction(), 1.0);
  });

  testWidgets('a ClipRect hiding half the box', (tester) async {
    await tester.pumpWidget(
      _host(
        Center(
          child: ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: 0.5,
              child: _box(),
            ),
          ),
        ),
      ),
    );
    expect(_fraction(), closeTo(0.5, 0.001));
  });

  testWidgets('a box partly scrolled out of a list viewport', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            height: 200,
            child: ListView(
              controller: controller,
              children: [
                const SizedBox(height: 150),
                _box(),
                const SizedBox(height: 600),
              ],
            ),
          ),
        ),
      ),
    );
    // The box spans 150–250 in a 200 tall viewport: half is clipped away.
    expect(_fraction(), closeTo(0.5, 0.001));

    controller.jumpTo(150);
    await tester.pump();
    expect(_fraction(), 1.0);

    controller.jumpTo(400);
    await tester.pump();
    expect(_fraction(), 0.0);
  });

  testWidgets('a box partly outside the view', (tester) async {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 2; // 200 x 200 logical
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        Stack(
          clipBehavior: Clip.none,
          children: [Positioned(left: 150, top: 0, child: _box())],
        ),
      ),
    );
    // 150–250 horizontally on a 200 wide view: half is off screen.
    expect(_fraction(), closeTo(0.5, 0.001));
  });

  testWidgets('a detached or empty box counts as invisible', (tester) async {
    await tester.pumpWidget(_host(Center(child: _box(width: 0))));
    expect(_fraction(), 0.0);
  });
}
