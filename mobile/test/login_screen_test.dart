import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/views/auth/login_screen.dart';
import 'package:quickfix/views/auth/signup_screen.dart';

class MockAuthService extends Mock implements AuthService {}

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

  testWidgets('login layout scrolls when keyboard opens on small screens',
      (tester) async {
    // A short viewport simulates the keyboard covering most of the screen.
    tester.view.physicalSize = const Size(360, 400);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = FakeViewPadding(bottom: 250);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    // Focusing the email field raises the keyboard; the login button must
    // stay reachable by scrolling (no overflow / no exception).
    await tester.enterText(find.byType(TextFormField).at(0), 'a@b.co');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Login'), findsOneWidget);

    await tester.ensureVisible(find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.text('Sign Up'), findsOneWidget);
  });

  testWidgets('login fits on a small screen without keyboard', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The login button lives at the bottom of the column; it must be
    // reachable by scrolling without any overflow errors.
    await tester.ensureVisible(find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('forgot password sends a reset email', (tester) async {
    final auth = MockAuthService();
    when(() => auth.sendPasswordReset(email: 'a@b.co'))
        .thenAnswer((_) async {});

    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: auth)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'a@b.co');

    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    verify(() => auth.sendPasswordReset(email: 'a@b.co')).called(1);
    expect(find.text('Reset Link Sent'), findsOneWidget);
  });
}
