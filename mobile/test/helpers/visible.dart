import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lazy ListView children may not exist yet. Find the active vertical viewport,
/// build the target, then lay out the zero-duration ensureVisible jump before a
/// test taps it. Do not weaken assertions or silence missed-hit warnings.
Future<void> reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    final vertical = find.byWidgetPredicate((widget) => widget is Scrollable &&
        (widget.axisDirection == AxisDirection.down || widget.axisDirection == AxisDirection.up));
    if (vertical.evaluate().isNotEmpty) {
      final viewport = vertical.first;
      final state = tester.state<ScrollableState>(viewport);
      state.position.jumpTo(state.position.minScrollExtent);
      await tester.pump();
      await tester.scrollUntilVisible(target, 180, scrollable: viewport, maxScrolls: 80);
    }
  }
  await tester.ensureVisible(target);
  await tester.pump();
}
