// This is a basic Flutter widget test for QuickFix app.

import 'package:flutter_test/flutter_test.dart';

import 'package:quickfix/app.dart';

void main() {
  testWidgets('QuickFix app shows placeholder', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const QuickFixApp());

    // Verify that the app shows the QuickFix branding.
    expect(find.text('QuickFix'), findsOneWidget);
    expect(find.text('On-Demand Local Services'), findsOneWidget);
  });
}