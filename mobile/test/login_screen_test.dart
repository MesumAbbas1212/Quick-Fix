import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/views/auth/login_screen.dart';
import 'package:quickfix/views/auth/signup_screen.dart';

Finder _selectedCard(Color expectedColor) {
  return find.byWidgetPredicate((widget) {
    if (widget is! AnimatedContainer) return false;
    final decoration = widget.decoration;
    if (decoration is! BoxDecoration) return false;
    final shadows = decoration.boxShadow ?? const [];
    return decoration.color == expectedColor && shadows.length == 2;
  });
}

void main() {
  testWidgets('login shows Find Services and Get Jobs role cards',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Login as User'), findsOneWidget);
    expect(find.text('Find Services'), findsOneWidget);
    expect(find.text('Login as Worker'), findsOneWidget);
    expect(find.text('Get Jobs'), findsOneWidget);
  });

  testWidgets('tapping Get Jobs selects the worker role card',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    expect(_selectedCard(const Color(0xFF009AE2)), findsOneWidget);

    await tester.tap(find.text('Get Jobs'));
    await tester.pumpAndSettle();

    expect(_selectedCard(AppTheme.accentYellow), findsOneWidget);
    expect(_selectedCard(const Color(0xFF009AE2)), findsNothing);
  });

  testWidgets('Sign Up opens the signup screen with the selected role',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get Jobs'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    expect(find.byType(SignUpScreen), findsOneWidget);
    expect(_selectedCard(AppTheme.accentYellow), findsOneWidget);
  });
}
