import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/models/app_language.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/language_service.dart';
import 'package:quickfix/views/auth/login_screen.dart';
import 'package:quickfix/views/auth/signup_screen.dart';

class _Auth extends Mock implements AuthService {}

class _Languages extends Mock implements LanguageService {}

/// Reads the real `obscureText` flag the field is currently rendering.
bool _isObscured(WidgetTester tester, int index) {
  final field = find.descendant(
    of: find.byType(TextFormField).at(index),
    matching: find.byType(TextField),
  );
  return tester.widget<TextField>(field).obscureText;
}

void main() {
  setUpAll(() => registerFallbackValue(UserRole.user));

  testWidgets('login password starts hidden and the eye toggles it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.pump();

    expect(_isObscured(tester, 1), isTrue);
    expect(find.byTooltip('Show password'), findsOneWidget);

    await tester.tap(find.byKey(const Key('login-password-visibility')));
    await tester.pump();

    expect(_isObscured(tester, 1), isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);
    // The typed text survives the reveal — nothing is cleared or re-validated.
    expect(find.text('secret123'), findsOneWidget);

    await tester.tap(find.byKey(const Key('login-password-visibility')));
    await tester.pump();

    expect(_isObscured(tester, 1), isTrue);
  });

  testWidgets('signup password and confirmation toggle independently', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final languages = _Languages();
    when(() => languages.getAvailableLanguages())
        .thenAnswer((_) async => const <AppLanguage>[
          AppLanguage(code: 'en', nativeName: 'English', englishName: 'English'),
        ]);

    await tester.pumpWidget(
      MaterialApp(
        home: SignUpScreen(
          languageService: languages,
          authService: _Auth(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Field order: name, email, phone, password, confirm password.
    expect(_isObscured(tester, 3), isTrue);
    expect(_isObscured(tester, 4), isTrue);

    await tester.tap(find.byKey(const Key('signup-password-visibility')));
    await tester.pump();

    expect(_isObscured(tester, 3), isFalse);
    expect(_isObscured(tester, 4), isTrue,
        reason: 'confirmation must keep its own state');

    await tester.tap(find.byKey(const Key('signup-confirm-password-visibility')));
    await tester.pump();

    expect(_isObscured(tester, 3), isFalse);
    expect(_isObscured(tester, 4), isFalse);
  });

  testWidgets('revealing the password does not bypass validation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(1), 'abc');
    await tester.tap(find.byKey(const Key('login-password-visibility')));
    await tester.pump();

    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('Password must be at least 6 characters'), findsOneWidget);
  });
}
