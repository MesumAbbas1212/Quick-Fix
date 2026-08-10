import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quickfix/app.dart';
import 'package:quickfix/views/auth/login_screen.dart';

void main() {
  testWidgets('QuickFix app boots to the login screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const QuickFixApp());

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
